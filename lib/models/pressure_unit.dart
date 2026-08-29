enum PressureUnit {
  psi('PSI'),
  kpa('kPa'),
  bar('bar');

  const PressureUnit(this.label);

  final String label;

  double fromKpa(double pressureKpa) => switch (this) {
    PressureUnit.psi => pressureKpa * 0.145038,
    PressureUnit.kpa => pressureKpa,
    PressureUnit.bar => pressureKpa / 100,
  };

  double toKpa(double value) => switch (this) {
    PressureUnit.psi => value / 0.145038,
    PressureUnit.kpa => value,
    PressureUnit.bar => value * 100,
  };

  String format(double pressureKpa) {
    final value = fromKpa(pressureKpa);
    final decimals = this == PressureUnit.bar ? 2 : 1;
    return '${value.toStringAsFixed(decimals)} $label';
  }
}
