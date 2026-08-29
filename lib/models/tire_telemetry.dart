class TireTelemetry {
  const TireTelemetry({
    required this.sensorId,
    required this.position,
    required this.pressureKpa,
    required this.temperatureC,
    required this.batteryPercent,
    required this.lastUpdated,
  });

  final String sensorId;
  final String position;
  final double pressureKpa;
  final int temperatureC;
  final int batteryPercent;
  final DateTime lastUpdated;

  double get pressurePsi => pressureKpa * 0.145038;
}
