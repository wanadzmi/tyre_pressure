class TpmsAlarmSettings {
  const TpmsAlarmSettings({
    this.highTemperatureC = 75,
    this.highPressureKpa = 250,
    this.lowPressureKpa = 26.1 / 0.145038,
    this.lowBatteryAlarmEnabled = true,
  });

  final double highTemperatureC;
  final double highPressureKpa;
  final double lowPressureKpa;
  final bool lowBatteryAlarmEnabled;

  bool isHighTemperature(double temperatureC) =>
      temperatureC > highTemperatureC;

  bool isHighPressure(double pressureKpa) => pressureKpa > highPressureKpa;

  bool isLowPressure(double pressureKpa) => pressureKpa < lowPressureKpa;

  bool shouldAlertLowBattery(bool lowBattery) =>
      lowBatteryAlarmEnabled && lowBattery;

  TpmsAlarmSettings copyWith({
    double? highTemperatureC,
    double? highPressureKpa,
    double? lowPressureKpa,
    bool? lowBatteryAlarmEnabled,
  }) => TpmsAlarmSettings(
    highTemperatureC: highTemperatureC ?? this.highTemperatureC,
    highPressureKpa: highPressureKpa ?? this.highPressureKpa,
    lowPressureKpa: lowPressureKpa ?? this.lowPressureKpa,
    lowBatteryAlarmEnabled:
        lowBatteryAlarmEnabled ?? this.lowBatteryAlarmEnabled,
  );
}
