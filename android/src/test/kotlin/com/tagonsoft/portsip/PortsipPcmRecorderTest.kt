package com.tagonsoft.portsip

import com.portsip.PortSipEnumDefine
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Covers what the recorder puts on disk: the WAVE header it stamps, how the two
 * directions interleave, and that no part file or handle outlives a recording.
 *
 * Runs on the JVM — nothing here touches the SDK, and [PortsipLogger] is off by
 * default so `android.util.Log` is never reached.
 */
internal class PortsipPcmRecorderTest {

    private lateinit var directory: File
    private lateinit var recorder: PortsipPcmRecorder

    private val send = PortSipEnumDefine.ENUM_DIRECTION_SEND
    private val recv = PortSipEnumDefine.ENUM_DIRECTION_RECV

    /** Header fields read back from a finished file. */
    private data class Wave(
        val channels: Int,
        val sampleRate: Int,
        val bitsPerSample: Int,
        val dataBytes: Int,
        val riffSize: Int,
        val samples: ByteArray
    )

    @BeforeTest
    fun setUp() {
        directory = File.createTempFile("pcm-recorder", "").let {
            it.delete()
            it.mkdirs()
            it
        }
        recorder = PortsipPcmRecorder()
    }

    @AfterTest
    fun tearDown() {
        recorder.clear()
        directory.deleteRecursively()
    }

    // MARK: - Helpers

    /** Blocks until the merge running on the recorder's thread answers. */
    private fun stopAndAwait(sessionId: Long): String? {
        var path: String? = null
        val done = CountDownLatch(1)
        recorder.stop(sessionId) {
            path = it
            done.countDown()
        }
        assertTrue(done.await(10, TimeUnit.SECONDS), "stop($sessionId) never completed")
        return path
    }

    /** 16-bit little-endian PCM whose samples count up from [first]. */
    private fun pcm(sampleCount: Int, first: Int): ByteArray =
        ByteBuffer.allocate(sampleCount * 2).order(ByteOrder.LITTLE_ENDIAN).apply {
            repeat(sampleCount) { putShort((first + it).toShort()) }
        }.array()

    private fun readWave(path: String): Wave {
        val bytes = File(path).readBytes()
        val header = ByteBuffer.wrap(bytes, 0, 44).order(ByteOrder.LITTLE_ENDIAN)
        assertEquals("RIFF", String(bytes, 0, 4))
        assertEquals("WAVE", String(bytes, 8, 4))
        assertEquals("fmt ", String(bytes, 12, 4))
        assertEquals("data", String(bytes, 36, 4))
        return Wave(
            channels = header.getShort(22).toInt(),
            sampleRate = header.getInt(24),
            bitsPerSample = header.getShort(34).toInt(),
            dataBytes = header.getInt(40),
            riffSize = header.getInt(4),
            samples = bytes.copyOfRange(44, bytes.size)
        )
    }

    private fun sampleAt(wave: Wave, index: Int): Short =
        ByteBuffer.wrap(wave.samples).order(ByteOrder.LITTLE_ENDIAN).getShort(index * 2)

    private fun parts() = directory.listFiles()?.filter { it.name.contains(".part") } ?: emptyList()

    // MARK: - Output

    @Test
    fun `both directions interleave into a stereo file`() {
        assertTrue(recorder.start(1L, directory.path, "call"))
        recorder.write(1L, send, pcm(4, 100), 8, 8000)
        recorder.write(1L, recv, pcm(4, 200), 8, 8000)

        val wave = readWave(assertNotNull(stopAndAwait(1L)))

        assertEquals(2, wave.channels)
        assertEquals(8000, wave.sampleRate)
        assertEquals(16, wave.bitsPerSample)
        // 4 frames, two channels, two bytes each.
        assertEquals(16, wave.dataBytes)
        assertEquals(36 + wave.dataBytes, wave.riffSize)
        assertEquals(wave.dataBytes, wave.samples.size)

        // Sent audio lands on the left of each frame, received on the right.
        assertEquals(100, sampleAt(wave, 0).toInt())
        assertEquals(200, sampleAt(wave, 1).toInt())
        assertEquals(101, sampleAt(wave, 2).toInt())
        assertEquals(201, sampleAt(wave, 3).toInt())
    }

    @Test
    fun `the shorter direction is padded with silence rather than truncating the longer`() {
        assertTrue(recorder.start(1L, directory.path, "call"))
        recorder.write(1L, send, pcm(6, 100), 12, 8000)
        recorder.write(1L, recv, pcm(2, 200), 4, 8000)

        val wave = readWave(assertNotNull(stopAndAwait(1L)))

        // Six frames — the length of the longer side, not the shorter.
        assertEquals(24, wave.dataBytes)
        // The received side runs out after two frames.
        assertEquals(101, sampleAt(wave, 2).toInt())
        assertEquals(201, sampleAt(wave, 3).toInt())
        // Past that the right channel goes quiet while the sent side plays on.
        assertEquals(102, sampleAt(wave, 4).toInt())
        assertEquals(0, sampleAt(wave, 5).toInt())
        assertEquals(105, sampleAt(wave, 10).toInt())
        assertEquals(0, sampleAt(wave, 11).toInt())
    }

    @Test
    fun `a single direction stays mono`() {
        assertTrue(recorder.start(1L, directory.path, "call"))
        recorder.write(1L, recv, pcm(4, 700), 8, 16000)

        val wave = readWave(assertNotNull(stopAndAwait(1L)))

        assertEquals(1, wave.channels)
        assertEquals(16000, wave.sampleRate)
        assertEquals(8, wave.dataBytes)
        assertEquals(700, sampleAt(wave, 0).toInt())
        assertEquals(703, sampleAt(wave, 3).toInt())
    }

    @Test
    fun `a session that captured nothing produces no file`() {
        assertTrue(recorder.start(1L, directory.path, "call"))

        assertNull(stopAndAwait(1L))
        assertTrue(File(directory, "call.wav").exists().not())
    }

    // MARK: - Lifecycle

    @Test
    fun `a call ending closes the parts and stop still returns the recording`() {
        assertTrue(recorder.start(1L, directory.path, "call"))
        recorder.write(1L, send, pcm(4, 100), 8, 8000)
        recorder.write(1L, recv, pcm(4, 200), 8, 8000)

        // What onInviteClosed does when the remote hangs up. An app that calls
        // stopPcmRecord from its own call-ended handler arrives after this.
        recorder.finish(1L)

        val path = assertNotNull(stopAndAwait(1L), "the recording survives until it is collected")
        assertEquals(File(directory, "call.wav").absolutePath, path)
        assertEquals(2, readWave(path).channels)
        assertTrue(parts().isEmpty())
    }

    @Test
    fun `frames arriving after the call ended are ignored`() {
        assertTrue(recorder.start(1L, directory.path, "call"))
        recorder.write(1L, send, pcm(4, 100), 8, 8000)
        recorder.finish(1L)
        // The parts are closed — a late frame must not reopen or extend them.
        recorder.write(1L, send, pcm(4, 500), 8, 8000)

        val wave = readWave(assertNotNull(stopAndAwait(1L)))
        assertEquals(8, wave.dataBytes)
    }

    @Test
    fun `starting again on a finished session replaces it rather than reusing it`() {
        assertTrue(recorder.start(1L, directory.path, "one"))
        recorder.write(1L, send, pcm(4, 100), 8, 8000)
        recorder.finish(1L)

        // The session id came round again before anyone collected the last one.
        assertTrue(recorder.start(1L, directory.path, "two"))
        recorder.write(1L, send, pcm(4, 900), 8, 16000)

        val path = assertNotNull(stopAndAwait(1L))
        assertEquals(File(directory, "two.wav").absolutePath, path)
        val wave = readWave(path)
        assertEquals(16000, wave.sampleRate)
        assertEquals(900, sampleAt(wave, 0).toInt())
        // Nothing of the abandoned recording is left behind.
        assertTrue(parts().isEmpty(), "left behind: ${parts().map { it.name }}")
        assertTrue(File(directory, "one.wav").exists().not())
    }

    @Test
    fun `a repeat start while still capturing keeps what is already recorded`() {
        assertTrue(recorder.start(1L, directory.path, "call"))
        recorder.write(1L, send, pcm(4, 100), 8, 8000)
        assertTrue(recorder.start(1L, directory.path, "call"))
        recorder.write(1L, send, pcm(4, 104), 8, 8000)

        val wave = readWave(assertNotNull(stopAndAwait(1L)))
        assertEquals(16, wave.dataBytes)
        assertEquals(100, sampleAt(wave, 0).toInt())
        assertEquals(104, sampleAt(wave, 4).toInt())
    }

    @Test
    fun `frames outside a recording are ignored`() {
        // Before any start, and after the recording has been stopped.
        recorder.write(1L, send, pcm(4, 100), 8, 8000)
        assertTrue(recorder.start(1L, directory.path, "call"))
        recorder.write(1L, send, pcm(4, 100), 8, 8000)
        assertNotNull(stopAndAwait(1L))
        recorder.write(1L, send, pcm(4, 100), 8, 8000)

        assertTrue(parts().isEmpty(), "stray part files: ${parts().map { it.name }}")
    }

    @Test
    fun `part files do not outlive the merge`() {
        assertTrue(recorder.start(1L, directory.path, "call"))
        recorder.write(1L, send, pcm(4, 100), 8, 8000)
        recorder.write(1L, recv, pcm(4, 200), 8, 8000)
        stopAndAwait(1L)

        assertTrue(parts().isEmpty(), "left behind: ${parts().map { it.name }}")
        assertEquals(listOf("call.wav"), directory.list()?.sorted())
    }

    @Test
    fun `parts stranded by an earlier process are swept when recording starts`() {
        // What a kill mid-call leaves behind: nothing will ever come back for it.
        File(directory, "call.part$recv").writeBytes(ByteArray(1024))

        assertTrue(recorder.start(1L, directory.path, "call"))
        recorder.write(1L, send, pcm(4, 100), 8, 8000)
        assertNotNull(stopAndAwait(1L))

        assertEquals(listOf("call.wav"), directory.list()?.sorted())
    }

    @Test
    fun `parts stranded under another name are swept too`() {
        // Recordings are normally named per call, so nothing will ever start
        // under this name again and reclaim these itself.
        File(directory, "old_call_9.part$send").writeBytes(ByteArray(2048))
        File(directory, "old_call_9.part$recv").writeBytes(ByteArray(2048))

        assertTrue(recorder.start(1L, directory.path, "new_call_1"))
        recorder.write(1L, send, pcm(4, 100), 8, 8000)
        assertNotNull(stopAndAwait(1L))

        assertEquals(listOf("new_call_1.wav"), directory.list()?.sorted())
    }

    @Test
    fun `a merge in flight is not swept by a recording starting alongside it`() {
        assertTrue(recorder.start(1L, directory.path, "call"))
        // Big enough that the merge is still running when the next start sweeps.
        val frame = pcm(4000, 1)
        repeat(250) {
            recorder.write(1L, send, frame, frame.size, 8000)
            recorder.write(1L, recv, frame, frame.size, 8000)
        }

        var path: String? = null
        val done = CountDownLatch(1)
        recorder.stop(1L) {
            path = it
            done.countDown()
        }
        // Same directory, different call. Its sweep runs while the merge above
        // is still reading parts that are no longer in the session map.
        assertTrue(recorder.start(2L, directory.path, "next"))

        assertTrue(done.await(10, TimeUnit.SECONDS), "stop(1) never completed")
        val wave = readWave(assertNotNull(path, "the merge lost its parts"))
        assertEquals(2, wave.channels)
        assertEquals(250 * 8000 * 2, wave.dataBytes)
    }

    @Test
    fun `a sweep cannot delete a part another session is still writing`() {
        assertTrue(recorder.start(1L, directory.path, "call"))
        recorder.write(1L, send, pcm(4, 100), 8, 8000)

        // Same directory and name — sloppy, but it must not destroy the live one.
        assertTrue(recorder.start(2L, directory.path, "call"))

        val wave = readWave(assertNotNull(stopAndAwait(1L)))
        assertEquals(8, wave.dataBytes)
        assertEquals(100, sampleAt(wave, 0).toInt())
    }

    @Test
    fun `clear drops in-progress recordings without leaving parts`() {
        assertTrue(recorder.start(1L, directory.path, "one"))
        assertTrue(recorder.start(2L, directory.path, "two"))
        recorder.write(1L, send, pcm(4, 100), 8, 8000)
        recorder.write(2L, recv, pcm(4, 200), 8, 8000)

        recorder.clear()

        assertTrue(directory.list()?.isEmpty() ?: false, "left behind: ${directory.list()?.toList()}")
        // Frames arriving after teardown can't resurrect a session.
        recorder.write(1L, send, pcm(4, 100), 8, 8000)
        assertTrue(parts().isEmpty())
    }

    @Test
    fun `recording two sessions at once keeps their files apart`() {
        assertTrue(recorder.start(1L, directory.path, "one"))
        assertTrue(recorder.start(2L, directory.path, "two"))
        recorder.write(1L, send, pcm(4, 100), 8, 8000)
        recorder.write(2L, send, pcm(4, 500), 8, 16000)

        val first = readWave(assertNotNull(stopAndAwait(1L)))
        val second = readWave(assertNotNull(stopAndAwait(2L)))

        assertEquals(8000, first.sampleRate)
        assertEquals(100, sampleAt(first, 0).toInt())
        assertEquals(16000, second.sampleRate)
        assertEquals(500, sampleAt(second, 0).toInt())
    }

    @Test
    fun `stopping a session that was never recorded reports nothing`() {
        assertNull(stopAndAwait(99L))
    }

    // MARK: - Sample rate

    @Test
    fun `a rate change while the codec settles restamps the file`() {
        assertTrue(recorder.start(1L, directory.path, "call"))
        // The receive path opens at the jitter buffer's default, then adopts
        // the negotiated rate once the first packet decodes.
        recorder.write(1L, recv, pcm(4, 100), 8, 8000)
        recorder.write(1L, recv, pcm(4, 300), 8, 16000)

        val wave = readWave(assertNotNull(stopAndAwait(1L)))

        assertEquals(16000, wave.sampleRate)
        // The frames captured at the wrong rate are dropped, not kept.
        assertEquals(8, wave.dataBytes)
        assertEquals(300, sampleAt(wave, 0).toInt())
    }

    @Test
    fun `a rate change past the settling window keeps the established rate`() {
        assertTrue(recorder.start(1L, directory.path, "call"))
        // Three seconds at 8 kHz mono puts the stream well past settling.
        val threeSeconds = 8000 * 2 * 3
        val frame = pcm(4000, 1)
        var written = 0
        while (written < threeSeconds) {
            recorder.write(1L, recv, frame, frame.size, 8000)
            written += frame.size
        }
        recorder.write(1L, recv, pcm(4, 900), 8, 16000)

        val wave = readWave(assertNotNull(stopAndAwait(1L)))

        // Restarting here would throw the whole call away, so the rate stands.
        assertEquals(8000, wave.sampleRate)
        assertEquals(threeSeconds + 8, wave.dataBytes)
    }

    @Test
    fun `directions that disagree on rate fall back to the longer one`() {
        assertTrue(recorder.start(1L, directory.path, "call"))
        recorder.write(1L, send, pcm(8, 100), 16, 16000)
        recorder.write(1L, recv, pcm(4, 200), 8, 8000)

        val wave = readWave(assertNotNull(stopAndAwait(1L)))

        // Interleaving would need resampling; mono at the rate that was captured
        // is the honest result, and the merge says so at error level.
        assertEquals(1, wave.channels)
        assertEquals(16000, wave.sampleRate)
        assertEquals(16, wave.dataBytes)
        assertEquals(100, sampleAt(wave, 0).toInt())
    }

    // MARK: - Malformed input

    @Test
    fun `start reports a missing directory rather than failing on the audio thread`() {
        assertTrue(recorder.start(1L, File(directory, "absent").path, "call").not())
    }

    @Test
    fun `a frame longer than its buffer is clamped to what the buffer holds`() {
        assertTrue(recorder.start(1L, directory.path, "call"))
        // A length larger than the array must not read past the end of it.
        recorder.write(1L, recv, pcm(4, 100), 4096, 8000)

        val wave = readWave(assertNotNull(stopAndAwait(1L)))
        assertEquals(8, wave.dataBytes)
    }

    @Test
    fun `empty and malformed frames are ignored`() {
        assertTrue(recorder.start(1L, directory.path, "call"))
        recorder.write(1L, recv, pcm(4, 100), 0, 8000)
        recorder.write(1L, recv, pcm(4, 100), 8, 0)

        assertNull(stopAndAwait(1L))
    }
}
