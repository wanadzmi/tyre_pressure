import '../config/tire_config.dart';
import '../models/tire_telemetry.dart';

class TpmsParser {
  const TpmsParser();

  TireTelemetry? parse(List<int> bytes) {
    final usbReading = _parseUsbFrame(bytes);
    if (usbReading != null) return usbReading;

    // Legacy direct-BLE format retained as a fallback.
    for (final entry in myTires.entries) {
      final idBytes = _hexToBytes(entry.key);
      final idOffset = _indexOf(bytes, idBytes);
      if (idOffset < 0 || bytes.length < idOffset + 8) continue;

      final valueOffset = idOffset + 4;
      final pressureRaw = (bytes[valueOffset] << 8) | bytes[valueOffset + 1];
      return TireTelemetry(
        sensorId: entry.key,
        position: entry.value,
        pressureKpa: pressureRaw.toDouble(),
        temperatureC: bytes[valueOffset + 2],
        batteryPercent: bytes[valueOffset + 3],
        lastUpdated: DateTime.now(),
      );
    }
    return null;
  }

  TireTelemetry? _parseUsbFrame(List<int> bytes) {
    if (bytes.length != 8 ||
        bytes[0] != 0x55 ||
        bytes[1] != 0xAA ||
        bytes[2] != 0x08 ||
        !_hasValidChecksum(bytes)) {
      return null;
    }

    const positions = <int, String>{
      0x00: 'Front-Left',
      0x01: 'Front-Right',
      0x10: 'Rear-Left',
      0x11: 'Rear-Right',
    };
    final position = positions[bytes[3]];
    if (position == null) return null; // 0x05 is the optional spare tyre.

    final sensor = myTires.entries.firstWhere(
      (entry) => entry.value == position,
    );
    final status = bytes[6];
    return TireTelemetry(
      sensorId: sensor.key,
      position: position,
      pressureKpa: bytes[4] * 3.44,
      temperatureC: bytes[5] - 50,
      lowBattery: status & 0x10 != 0,
      leakage: status & 0x08 != 0,
      noSignal: status & 0x20 != 0,
      lastUpdated: DateTime.now(),
    );
  }

  bool _hasValidChecksum(List<int> bytes) {
    var checksum = 0;
    for (var i = 0; i < bytes.length - 1; i++) {
      checksum ^= bytes[i];
    }
    return checksum == bytes.last;
  }

  List<int> _hexToBytes(String hex) => [
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ];

  int _indexOf(List<int> bytes, List<int> pattern) {
    for (var start = 0; start <= bytes.length - pattern.length; start++) {
      var matches = true;
      for (var offset = 0; offset < pattern.length; offset++) {
        if (bytes[start + offset] != pattern[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) return start;
    }
    return -1;
  }
}
