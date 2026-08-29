import '../models/tire_telemetry.dart';

abstract interface class TpmsDataSource {
  Stream<TireTelemetry> get updates;
  Stream<String> get status;

  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}
