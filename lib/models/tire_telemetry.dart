class TireTelemetry {
  const TireTelemetry({
    required this.sensorId,
    required this.position,
    required this.pressureKpa,
    required this.temperatureC,
    required this.lastUpdated,
    this.batteryPercent,
    this.lowBattery = false,
    this.leakage = false,
    this.noSignal = false,
  });

  final String sensorId;
  final String position;
  final double pressureKpa;
  final int temperatureC;
  final int? batteryPercent;
  final bool lowBattery;
  final bool leakage;
  final bool noSignal;
  final DateTime lastUpdated;

  double get pressurePsi => pressureKpa * 0.145038;
}
