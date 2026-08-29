import 'package:flutter/material.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:tyre_pressure/config/tire_config.dart';
import 'package:tyre_pressure/main.dart';
import 'package:tyre_pressure/models/pressure_unit.dart';
import 'package:tyre_pressure/models/temperature_unit.dart';
import 'package:tyre_pressure/models/tpms_alarm_settings.dart';
import 'package:tyre_pressure/screens/tpms_dashboard.dart';
import 'package:tyre_pressure/services/tpms_parser.dart';

void main() {
  test('formats supported temperature units', () {
    expect(TemperatureUnit.celsius.format(40), '40 °C');
    expect(TemperatureUnit.fahrenheit.format(40), '104.0 °F');
    expect(TemperatureUnit.kelvin.format(40), '313.1 K');
  });

  test('uses requested default alarm thresholds', () {
    const settings = TpmsAlarmSettings();
    expect(settings.highTemperatureC, 75);
    expect(settings.highPressureKpa, 250);
    expect(
      PressureUnit.psi.fromKpa(settings.lowPressureKpa),
      closeTo(26.1, 0.001),
    );
    expect(settings.lowBatteryAlarmEnabled, isTrue);
    expect(settings.isHighTemperature(76), isTrue);
    expect(settings.isHighPressure(251), isTrue);
    expect(settings.isLowPressure(170), isTrue);
    expect(settings.shouldAlertLowBattery(true), isTrue);
  });

  test('parses values relative to an ID inside a payload', () {
    final result = const TpmsParser().parse([
      0x12,
      0x34,
      0x01,
      0xEF,
      0xB0,
      0x68,
      0x00,
      0xE9,
      0x21,
      0x64,
    ]);
    expect(result?.position, 'Rear-Right');
    expect(result?.pressureKpa, 233);
    expect(result?.pressurePsi, closeTo(33.794, 0.001));
    expect(result?.temperatureC, 33);
    expect(result?.batteryPercent, 100);
  });

  test('parses an actual USB TPMS frame', () {
    final result = const TpmsParser().parse([
      0x55,
      0xAA,
      0x08,
      0x00,
      0x44,
      0x5A,
      0x00,
      0xE9,
    ]);
    expect(result?.position, 'Front-Left');
    expect(result?.sensorId, '05EFEFF1');
    expect(result?.pressureKpa, closeTo(233.92, 0.001));
    expect(result?.pressurePsi, closeTo(33.9273, 0.001));
    expect(result?.temperatureC, 40);
    expect(result?.lowBattery, isFalse);
  });

  test('rejects a USB frame with an invalid checksum', () {
    final result = const TpmsParser().parse([
      0x55,
      0xAA,
      0x08,
      0x00,
      0x44,
      0x5A,
      0x00,
      0x00,
    ]);
    expect(result, isNull);
  });

  test('contains all four configured sensors', () {
    expect(myTires, hasLength(4));
    expect(myTires['05EFEFF1'], 'Front-Left');
    expect(myTires['02F05A72'], 'Front-Right');
    expect(myTires['02F00EA8'], 'Rear-Left');
    expect(myTires['01EFB068'], 'Rear-Right');
  });

  testWidgets('shows the TPMS dashboard', (tester) async {
    await tester.pumpWidget(
      const TpmsApp(home: TpmsDashboard(autoStart: false)),
    );
    expect(find.text('Front-Left'), findsNothing);
    expect(find.text('Front-Right'), findsNothing);
    expect(find.text('Connect dongle'), findsOneWidget);
    expect(find.text('-- PSI'), findsWidgets);
    expect(find.byTooltip('Settings'), findsOneWidget);
  });

  testWidgets('temporary alarm button shows a warning dialog', (tester) async {
    await tester.pumpWidget(
      const TpmsApp(home: TpmsDashboard(autoStart: false)),
    );
    await tester.tap(find.byTooltip('Test all alarms'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('TPMS warning'), findsOneWidget);
    expect(find.text('Acknowledge'), findsOneWidget);
  });

  for (final size in [const Size(1024, 600), const Size(640, 360)]) {
    testWidgets('has no overflow at ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const TpmsApp(home: TpmsDashboard(autoStart: false)),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Front-Left'), findsNothing);
      expect(find.text('Rear-Right'), findsNothing);
    });
  }
}
