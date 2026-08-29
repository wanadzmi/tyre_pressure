import 'dart:async';

import '../config/tire_config.dart';
import '../models/tire_telemetry.dart';
import 'tpms_data_source.dart';

class TpmsFakeService implements TpmsDataSource {
  final _updates = StreamController<TireTelemetry>.broadcast();
  final _status = StreamController<String>.broadcast();
  Timer? _timer;
  int _tick = 0;

  @override
  Stream<TireTelemetry> get updates => _updates.stream;

  @override
  Stream<String> get status => _status.stream;

  @override
  Future<void> start() async {
    if (_timer != null) return;
    _status.add('Design preview · simulated TPMS data');
    _emitReadings();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      _tick++;
      _emitReadings();
    });
  }

  void _emitReadings() {
    const basePressure = [234.0, 235.0, 232.0, 241.0];
    const baseTemperature = [40, 40, 33, 33];
    final variation = (_tick % 3 - 1) * 0.7;
    final tires = myTires.entries.toList();

    for (var index = 0; index < tires.length; index++) {
      _updates.add(
        TireTelemetry(
          sensorId: tires[index].key,
          position: tires[index].value,
          pressureKpa: basePressure[index] + variation,
          temperatureC: baseTemperature[index] + (_tick % 2),
          lastUpdated: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _status.add('Design preview paused');
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _updates.close();
    await _status.close();
  }
}
