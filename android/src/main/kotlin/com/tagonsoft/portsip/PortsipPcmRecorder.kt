package com.tagonsoft.portsip

import com.portsip.PortSipEnumDefine
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors

/**
 * Writes the SDK's raw audio callback to a WAVE file.
 *
 * An alternative to `startRecord` for callers who need the audio exactly as the
 * stream delivers it. The recorder built into the SDK re-encodes through its own
 * pipeline; this writes the PCM straight through, so what lands on disk is what
 * the callback produced.
 *
 * A session reports one stream per direction. Each is written to its own file
 * while the call runs, then interleaved into one stereo recording when it stops:
 * what this side sent on the left, what it received on the right. Keeping the
 * directions on their own channels avoids summing two loud sides into clipping,
 * and leaves the speakers separable for anything reading the file later.
 *
 * Threading: frames arrive on an SDK thread while start/stop come from the
 * platform channel, so every entry point is synchronized — but only long enough
 * to hand a session over. Merging rewrites every byte a recording holds, far too
 * much work for the platform thread, so [stop] detaches the session under the
 * lock and merges it on [finalizer]. Nothing here calls back into the SDK, which
 * the raw callback forbids.
 */
class PortsipPcmRecorder {

    /** One part file: the stream for a single callback type. */
    private class Writer(val file: File, val callbackType: Int, var sampleRate: Int) {
        private var stream = open()
        var dataBytes = 0L
            private set

        /** Latched so a change reported on every frame can't flood the log. */
        var rateChangedMidCall = false

        /** Truncates the file back to a placeholder header. */
        private fun open(): BufferedOutputStream =
            BufferedOutputStream(FileOutputStream(file, false), BUFFER_BYTES).apply {
                // The sizes aren't known until the stream ends.
                write(ByteArray(HEADER_BYTES))
            }

        fun append(data: ByteArray, count: Int) {
            stream.write(data, 0, count)
            dataBytes += count
        }

        /** Empties the file back to a placeholder header. */
        fun reset() {
            stream.close()
            stream = open()
            dataBytes = 0
        }

        /** Flushes, closes, and patches the real sizes in, leaving a playable part. */
        fun close() {
            stream.close()
            RandomAccessFile(file, "rw").use {
                it.seek(0)
                it.write(header(sampleRate, dataBytes, 1))
            }
        }

        fun closeQuietly() {
            runCatching { stream.close() }
        }
    }

    /** A recording: where it goes, and the part file per callback type. */
    private class Session(val directoryPath: String, val fileName: String) {
        val writers = HashMap<Int, Writer>()

        /**
         * False once the call has ended and the parts are closed. The session
         * itself stays until [stop] collects it: an app that stops from its own
         * call-ended handler arrives after the teardown hook, and must still get
         * its recording.
         */
        var capturing = true
    }

    private val sessions = HashMap<Long, Session>()

    /**
     * Recordings being merged right now. [stop] takes a session out of
     * [sessions] before handing it to [finalizer], but its part files are still
     * on disk and still being read, so [sweep] has to know they are spoken for.
     */
    private val merging = HashSet<Session>()

    /**
     * Runs the merge. Single-threaded so two recordings finishing together queue
     * rather than contend for the disk, and daemon so a merge in progress can't
     * hold the process up.
     */
    private val finalizer = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "portsip-pcm-recorder").apply { isDaemon = true }
    }

    companion object {
        private const val COMPONENT = "PcmRecorder"
        private const val HEADER_BYTES = 44
        private const val BITS_PER_SAMPLE = 16
        private const val BYTES_PER_SAMPLE = BITS_PER_SAMPLE / 8
        private const val CHUNK_SAMPLES = 8 * 1024
        private const val BUFFER_BYTES = 32 * 1024

        /** What [sweep] recognises as this recorder's scratch file. */
        private val PART_SUFFIX = Regex("""\.part\d+$""")

        /**
         * How long a stream may run before a rate change counts as mid-call
         * rather than the codec settling. The receive path opens at the jitter
         * buffer's default and adopts the negotiated rate on the first decoded
         * packet, well inside this.
         */
        private const val SETTLE_SECONDS = 2.0

        private fun seconds(rate: Int, dataBytes: Long, channels: Int): Double =
            if (rate <= 0) 0.0 else dataBytes.toDouble() / (rate * channels * BYTES_PER_SAMPLE)

        /** Canonical 44-byte PCM RIFF header, now that the sizes are known. */
        private fun header(sampleRate: Int, dataBytes: Long, channels: Int): ByteArray {
            val blockAlign = channels * BYTES_PER_SAMPLE
            val size = dataBytes.coerceIn(0L, (Int.MAX_VALUE - HEADER_BYTES).toLong()).toInt()
            return ByteBuffer.allocate(HEADER_BYTES).order(ByteOrder.LITTLE_ENDIAN).apply {
                put("RIFF".toByteArray())
                putInt(36 + size)
                put("WAVE".toByteArray())
                put("fmt ".toByteArray())
                putInt(16)
                putShort(1) // PCM
                putShort(channels.toShort())
                putInt(sampleRate)
                putInt(sampleRate * blockAlign)
                putShort(blockAlign.toShort())
                putShort(BITS_PER_SAMPLE.toShort())
                put("data".toByteArray())
                putInt(size)
            }.array()
        }
    }

    /**
     * Starts recording [sessionId] into [directoryPath], which must already
     * exist. The finished recording is `<fileName>.wav`.
     */
    @Synchronized
    fun start(sessionId: Long, directoryPath: String, fileName: String): Boolean {
        val existing = sessions[sessionId]
        if (existing != null) {
            // Still capturing: a repeat start is a no-op rather than a restart
            // that would throw away what is already recorded.
            if (existing.capturing) return true
            // Finished but never collected, and now never will be.
            drop(existing)
            sessions.remove(sessionId)
        }
        if (!File(directoryPath).isDirectory) {
            PortsipLogger.e(COMPONENT, "start($sessionId): no directory $directoryPath")
            return false
        }
        sweep(directoryPath)
        sessions[sessionId] = Session(directoryPath, fileName)
        PortsipLogger.d(COMPONENT, "start($sessionId) -> $directoryPath/$fileName.wav")
        return true
    }

    /**
     * Appends one frame. Ignored unless [start] ran for this session, so frames
     * arriving before or after a recording can't create stray files.
     *
     * A stream can change rate after it opens — the receive path starts at the
     * jitter buffer's default and drops to the negotiated codec's rate once the
     * answer arrives. Keeping the first rate would stamp the wrong one into the
     * header and play the whole recording an octave out, so a change inside the
     * settling window restarts the file, costing the fraction of a second before
     * the codec settles. A change after that is treated as mid-call and the
     * established rate is kept — see the branch below for why.
     *
     * Runs on the SDK's audio thread: everything the disk can throw is caught
     * here, because an exception let loose in a native callback takes the
     * process with it.
     */
    @Synchronized
    fun write(sessionId: Long, callbackType: Int, data: ByteArray, length: Int, sampleRate: Int) {
        if (length <= 0 || sampleRate <= 0) return
        val session = sessions[sessionId] ?: return
        if (!session.capturing) return

        val writer = session.writers[callbackType] ?: try {
            val file = File(session.directoryPath, "${session.fileName}.part$callbackType")
            PortsipLogger.d(
                COMPONENT,
                "opening ${file.name} at $sampleRate Hz (callbackType=$callbackType, " +
                    "send=${PortSipEnumDefine.ENUM_DIRECTION_SEND} " +
                    "recv=${PortSipEnumDefine.ENUM_DIRECTION_RECV})"
            )
            Writer(file, callbackType, sampleRate).also { session.writers[callbackType] = it }
        } catch (e: Exception) {
            abandon(sessionId, "cannot open a part file", e)
            return
        }

        if (writer.sampleRate != sampleRate) {
            if (seconds(writer.sampleRate, writer.dataBytes, 1) <= SETTLE_SECONDS) {
                PortsipLogger.d(
                    COMPONENT,
                    "type=$callbackType rate ${writer.sampleRate} -> $sampleRate Hz while " +
                        "settling, restarting (dropped ${writer.dataBytes} bytes)"
                )
                try {
                    writer.reset()
                    writer.sampleRate = sampleRate
                } catch (e: Exception) {
                    abandon(sessionId, "restart failed", e)
                    return
                }
            } else if (!writer.rateChangedMidCall) {
                // Past the settling window this is a real mid-call change — a
                // re-INVITE, or the stream rebuilt after a hold. Restarting here
                // would throw away everything recorded so far, which is a far
                // worse outcome than a stretch that plays at the wrong speed.
                writer.rateChangedMidCall = true
                PortsipLogger.d(
                    COMPONENT,
                    "type=$callbackType rate changed ${writer.sampleRate} -> $sampleRate Hz " +
                        "mid-call, keeping ${writer.sampleRate} Hz for the whole file"
                )
            }
        }

        try {
            writer.append(data, minOf(length, data.size))
        } catch (e: Exception) {
            abandon(sessionId, "write failed", e)
        }
    }

    /**
     * Closes the parts of a recording whose call has ended, so a caller that
     * never calls [stop] can't leave file handles open for the life of the
     * process. The session is kept for [stop] to collect.
     */
    @Synchronized
    fun finish(sessionId: Long) {
        val session = sessions[sessionId] ?: return
        if (!session.capturing) return
        closeParts(sessionId, session)
        PortsipLogger.d(COMPONENT, "closed $sessionId's parts on call teardown")
    }

    /**
     * Finishes [sessionId]'s recording, calling [completion] with its path — or
     * null if nothing was captured. The per-direction parts are combined into
     * one file and removed.
     *
     * Returns immediately: the merge runs on [finalizer], and [completion] is
     * invoked there rather than on the caller's thread.
     */
    @Synchronized
    fun stop(sessionId: Long, completion: (String?) -> Unit) {
        val session = sessions.remove(sessionId)
        if (session == null) {
            completion(null)
            return
        }
        // Stopped before the call ended, so the parts are still open. Flushing
        // them is at most one buffer each — the expensive half is the merge.
        if (session.capturing) closeParts(sessionId, session)
        merging.add(session)
        finalizer.execute {
            val path = try {
                merge(sessionId, session)
            } catch (e: Exception) {
                PortsipLogger.e(COMPONENT, "finalise failed for $sessionId", e)
                null
            }
            synchronized(this) { merging.remove(session) }
            completion(path)
        }
    }

    /**
     * Drops every recording without finalising — for teardown, where the
     * sessions the files belong to are going away anyway. A merge already
     * running is left to complete.
     */
    @Synchronized
    fun clear() {
        for ((sessionId, session) in sessions) {
            PortsipLogger.d(COMPONENT, "dropping recording for $sessionId")
            drop(session)
        }
        sessions.clear()
    }

    /** Flushes each part and stamps its real sizes in. */
    private fun closeParts(sessionId: Long, session: Session) {
        session.capturing = false
        for ((type, writer) in session.writers) {
            try {
                writer.close()
                PortsipLogger.d(
                    COMPONENT,
                    "type=$type ${writer.dataBytes} bytes = " +
                        "${"%.2f".format(seconds(writer.sampleRate, writer.dataBytes, 1))}s " +
                        "at ${writer.sampleRate} Hz"
                )
            } catch (e: Exception) {
                // The handle stays open if close() threw part way through it.
                writer.closeQuietly()
                PortsipLogger.e(COMPONENT, "close failed for $sessionId/$type", e)
            }
        }
    }

    /** Merges a detached session's parts into the finished recording. */
    private fun merge(sessionId: Long, session: Session): String? {
        val parts = session.writers.values.filter { it.dataBytes > 0 }
        val output = File(session.directoryPath, "${session.fileName}.wav")
        return try {
            if (parts.isEmpty()) {
                PortsipLogger.d(COMPONENT, "$sessionId captured nothing")
                null
            } else {
                combine(parts, output)
                PortsipLogger.d(COMPONENT, "wrote ${output.name} (${output.length()} bytes)")
                output.absolutePath
            }
        } catch (e: Exception) {
            PortsipLogger.e(COMPONENT, "combine failed for $sessionId", e)
            runCatching { output.delete() }
            null
        } finally {
            // Parts go whether or not the merge worked: a stranded .partN is no
            // use to anyone and nothing else will ever come back for it.
            session.writers.values.forEach { runCatching { it.file.delete() } }
        }
    }

    /**
     * Builds the finished recording from the per-direction parts: sent audio on
     * the left, received on the right. A call that only ever produced one
     * direction stays mono rather than wasting a silent channel.
     *
     * The parts rarely hold the same number of samples — one direction opens
     * before the other and they stop a frame apart — so the shorter is padded
     * with silence rather than truncating the longer.
     */
    private fun combine(parts: List<Writer>, output: File) {
        val rate = parts[0].sampleRate
        val left = parts.firstOrNull { it.callbackType == PortSipEnumDefine.ENUM_DIRECTION_SEND }
        val right = parts.firstOrNull { it.callbackType == PortSipEnumDefine.ENUM_DIRECTION_RECV }

        if (parts.size == 1 || left == null || right == null || parts.any { it.sampleRate != rate }) {
            // One direction, an unrecognised stream, or parts that disagree on
            // rate — interleaving any of those would need resampling or invent
            // a channel. The longest part alone is the honest result.
            val longest = parts.maxBy { it.dataBytes }
            if (parts.size > 1) {
                // A direction is being dropped, not mixed: worth more than a
                // debug line, because the file silently holds half the call.
                PortsipLogger.e(
                    COMPONENT,
                    "cannot interleave ${parts.map { "type=${it.callbackType}@${it.sampleRate}Hz" }} " +
                        "— falling back to mono and dropping ${parts.size - 1} stream(s)"
                )
            }
            PortsipLogger.d(
                COMPONENT,
                "writing mono from type=${longest.callbackType} at ${longest.sampleRate} Hz"
            )
            longest.file.copyTo(output, overwrite = true)
            return
        }

        val monoBytes = maxOf(left.dataBytes, right.dataBytes)
        RandomAccessFile(output, "rw").use { out ->
            out.setLength(0)
            out.write(header(rate, monoBytes * 2, 2))
            RandomAccessFile(left.file, "r").use { leftIn ->
                RandomAccessFile(right.file, "r").use { rightIn ->
                    leftIn.seek(HEADER_BYTES.toLong())
                    rightIn.seek(HEADER_BYTES.toLong())
                    val chunk = CHUNK_SAMPLES * BYTES_PER_SAMPLE
                    val lBuf = ByteArray(chunk)
                    val rBuf = ByteArray(chunk)
                    val interleaved = ByteArray(chunk * 2)
                    var written = 0L
                    while (written < monoBytes) {
                        val want = minOf(chunk.toLong(), monoBytes - written).toInt()
                        val lRead = fill(leftIn, lBuf, want)
                        val rRead = fill(rightIn, rBuf, want)
                        // Past the end of a part the buffer keeps stale bytes;
                        // zero the tail so the short side pads with silence.
                        java.util.Arrays.fill(lBuf, lRead, want, 0)
                        java.util.Arrays.fill(rBuf, rRead, want, 0)
                        var i = 0
                        var o = 0
                        while (i + 1 < want) {
                            interleaved[o] = lBuf[i]
                            interleaved[o + 1] = lBuf[i + 1]
                            interleaved[o + 2] = rBuf[i]
                            interleaved[o + 3] = rBuf[i + 1]
                            i += 2
                            o += 4
                        }
                        out.write(interleaved, 0, want * 2)
                        written += want
                    }
                }
            }
        }
        PortsipLogger.d(
            COMPONENT,
            "stereo: sent left (${left.dataBytes} bytes), received right " +
                "(${right.dataBytes} bytes) -> " +
                "${"%.2f".format(seconds(rate, monoBytes, 1))}s at $rate Hz"
        )
    }

    /** Reads [count] bytes into [buffer], returning how many the part held. */
    private fun fill(input: RandomAccessFile, buffer: ByteArray, count: Int): Int {
        var read = 0
        while (read < count) {
            val n = input.read(buffer, read, count - read)
            if (n < 0) break
            read += n
        }
        return read
    }

    /**
     * Gives up on a recording the disk refused. Dropping it keeps one failure
     * from logging on every frame that follows, and lets [stop] report nothing
     * captured rather than hand back a path to a file that stops part way
     * through the call.
     */
    private fun abandon(sessionId: Long, what: String, cause: Exception) {
        PortsipLogger.e(COMPONENT, "$what for $sessionId, dropping the recording", cause)
        sessions.remove(sessionId)?.let { drop(it) }
    }

    /** Closes and deletes a session's parts. */
    private fun drop(session: Session) {
        session.writers.values.forEach {
            it.closeQuietly()
            runCatching { it.file.delete() }
        }
    }

    /**
     * Removes part files stranded in [directoryPath] — a process killed
     * mid-call leaves them behind, and since recordings are normally named per
     * call, nothing ever comes back for them under that name again.
     *
     * Sweeps the whole directory rather than only the name being started, which
     * is why it has to skip the parts a live recording owns: several legs of a
     * conference record into one directory at the same time, and a recording
     * already handed to [finalizer] is still reading its parts even though it
     * has left [sessions].
     */
    private fun sweep(directoryPath: String) {
        val owned = (sessions.values + merging)
            .filter { it.directoryPath == directoryPath }
            .map { "${it.fileName}.part" }
        File(directoryPath)
            .listFiles { file ->
                PART_SUFFIX.containsMatchIn(file.name) &&
                    owned.none { file.name.startsWith(it) }
            }
            ?.forEach { runCatching { it.delete() } }
    }
}
