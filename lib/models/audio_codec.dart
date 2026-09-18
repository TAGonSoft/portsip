/// Audio codecs supported by PortSIP SDK.
///
/// Each codec has a corresponding integer value that matches the
/// AUDIOCODEC_TYPE enum from the native PortSIP SDK (`PortSIPTypes.hxx` on
/// iOS, `PortSipEnumDefine.ENUM_AUDIOCODEC_*` on Android). The values are RTP
/// payload types, so they must match the SDK exactly — a wrong value is either
/// rejected by `addAudioCodec` or, worse, silently enables a different codec.
///
/// Codecs are categorized by bandwidth:
/// - **Narrowband** (8 kHz): PCMU, PCMA, GSM, G.729, iLBC, Speex, AMR
/// - **Wideband** (16 kHz): G.722, G.722.1, Speex WB, iSAC WB, AMR-WB
/// - **Super-wideband** (32 kHz): iSAC SWB
/// - **Fullband** (48 kHz): OPUS
///
/// Example usage:
/// ```dart
/// await portsip.setAudioCodecs(audioCodecs: [
///   AudioCodec.opus,
///   AudioCodec.pcmu,
///   AudioCodec.pcma,
/// ]);
/// ```
enum AudioCodec {
  // Static payload types.
  /// PCMU (G.711 mu-law) 8 kHz 64 kbit/s narrowband audio codec
  pcmu(0),

  /// GSM 8 kHz 13 kbit/s narrowband audio codec
  gsm(3),

  /// PCMA (G.711 A-law) 8 kHz 64 kbit/s narrowband audio codec
  pcma(8),

  /// G.722 16 kHz 64 kbit/s wideband audio codec
  g722(9),

  /// G.729 8 kHz 8 kbit/s narrowband audio codec
  g729(18),

  // Dynamic payload types.
  /// iLBC 8 kHz narrowband audio codec (30 ms - 13 kbit/s, 20 ms - 15 kbit/s)
  ilbc(97),

  /// AMR (Adaptive Multi-Rate) 8 kHz narrowband audio codec, 4.75-12.2 kbit/s
  amr(98),

  /// AMR-WB (Adaptive Multi-Rate Wideband) 16 kHz wideband audio codec,
  /// 6.60-23.85 kbit/s
  amrWb(99),

  /// Speex 8 kHz 2-24 kbit/s narrowband audio codec
  speex(100),

  /// DTMF (RFC 2833) telephone-event codec for transmitting DTMF tones in-band.
  /// Used for interactive voice response (IVR) systems and call control
  /// signaling. Not a speech codec — enable it alongside the speech codecs
  /// whenever the app needs to send digits mid-call.
  dtmf(101),

  /// Speex 16 kHz 4-42 kbit/s wideband audio codec
  speexWb(102),

  /// iSAC (Internet Speech Audio Codec) 16 kHz 32-54 kbit/s wideband codec
  isacWb(103),

  /// iSAC (Internet Speech Audio Codec) 32 kHz 32-160 kbit/s super-wideband
  /// codec
  isacSwb(104),

  /// OPUS 48 kHz 5-510 kbit/s fullband audio codec
  opus(105),

  /// G.722.1 16 kHz (16, 24, 32) kbit/s wideband audio codec.
  ///
  /// Declared by the iOS SDK headers only; the Android SDK's
  /// `PortSipEnumDefine` does not expose a constant for it, so treat Android
  /// support as unverified.
  g7221(121);

  /// The integer value passed to the native SDK
  final int value;
  const AudioCodec(this.value);
}
