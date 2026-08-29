import '../config/tire_config.dart';
import '../models/tire_telemetry.dart';

class TpmsParser {
  const TpmsParser();

  TireTelemetry? parse(List<int> bytes) {
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
