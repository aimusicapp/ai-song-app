import 'dart:typed_data';

/// Converts a list of 16-bit PCM samples (mono) into a playable WAV byte buffer.
class WavWriter {
  static Uint8List build(List<int> samples, {int sampleRate = 22050}) {
    final int byteRate = sampleRate * 2; // mono, 16-bit
    final int dataLength = samples.length * 2;
    final int fileLength = 44 + dataLength;

    final ByteData header = ByteData(44);
    // RIFF chunk
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, fileLength - 8, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // fmt sub-chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6d); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // sub-chunk size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, 1, Endian.little); // mono channel
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, 2, Endian.little); // block align
    header.setUint16(34, 16, Endian.little); // bits per sample

    // data sub-chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataLength, Endian.little);

    final Uint8List out = Uint8List(fileLength);
    out.setRange(0, 44, header.buffer.asUint8List());

    final ByteData dataView = ByteData(dataLength);
    for (int i = 0; i < samples.length; i++) {
      dataView.setInt16(i * 2, samples[i], Endian.little);
    }
    out.setRange(44, fileLength, dataView.buffer.asUint8List());

    return out;
  }
}
