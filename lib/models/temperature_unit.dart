enum TemperatureUnit {
  celsius('°C'),
  fahrenheit('°F'),
  kelvin('K');

  const TemperatureUnit(this.label);

  final String label;

  double fromCelsius(double temperatureC) => switch (this) {
    TemperatureUnit.celsius => temperatureC,
    TemperatureUnit.fahrenheit => temperatureC * 9 / 5 + 32,
    TemperatureUnit.kelvin => temperatureC + 273.15,
  };

  double toCelsius(double value) => switch (this) {
    TemperatureUnit.celsius => value,
    TemperatureUnit.fahrenheit => (value - 32) * 5 / 9,
    TemperatureUnit.kelvin => value - 273.15,
  };

  String format(int temperatureC) {
    final value = fromCelsius(temperatureC.toDouble());
    final decimals = this == TemperatureUnit.celsius ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} $label';
  }
}
