/// Audio codecs supported by PortSIP SDK.
///
/// Each codec has a corresponding integer value that matches the
/// AUDIOCODEC_TYPE enum from the native PortSIP SDK.
///
/// Codecs are categorized by bandwidth:
/// - **Narrowband** (8 kHz): PCMU, PCMA, GSM, G.723, G.729, iLBC, Speex, AMR
/// - **Wideband** (16 kHz): G.722, Speex WB, ISAC WB, AMR-WB, OPUS
/// - **Super-wideband** (32 kHz): ISAC SWB
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
  /// PCMU (G.711 mu-law) narrowband audio codec
  pcmu(0),

  /// GSM narrowband audio codec
  gsm(3),

  /// G.723 narrowband audio codec
  g723(4),

  /// DVI4 8kHz audio codec
  dvi4_8k(5),

  /// DVI4 16kHz audio codec
  dvi4_16k(6),

  /// PCMA (G.711 A-law) narrowband audio codec
  pcma(8),

  /// G.722 wideband audio codec
  g722(9),

  /// iLBC narrowband audio codec
  ilbc(97),

  /// Speex narrowband audio codec
  speex(98),

  /// Speex wideband audio codec
  speexWb(99),

  /// ISAC wideband audio codec
  isacWb(100),

  /// ISAC super-wideband audio codec
  isacSwb(102),

  /// G.729 narrowband audio codec
  g729(18),

  /// OPUS audio codec
  opus(111),

  /// AMR narrowband audio codec
  amr(112),

  /// AMR-WB wideband audio codec
  amrWb(113),

  /// DTMF (RFC 2833) telephone-event codec for transmitting DTMF tones in-band.
  /// Used for interactive voice response (IVR) systems and call control signaling.
  dtmf(101);

  /// The integer value passed to the native SDK
  final int value;
  const AudioCodec(this.value);
}
