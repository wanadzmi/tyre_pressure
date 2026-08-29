import 'package:flutter_test/flutter_test.dart';
import 'package:tyre_pressure/config/tire_config.dart';
import 'package:tyre_pressure/main.dart';
import 'package:tyre_pressure/services/tpms_parser.dart';

void main() {
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

  test('contains all four configured sensors', () {
    expect(myTires, hasLength(4));
    expect(myTires['05EFEFF1'], 'Front-Left');
    expect(myTires['02F05A72'], 'Front-Right');
    expect(myTires['02F00EA8'], 'Rear-Left');
    expect(myTires['01EFB068'], 'Rear-Right');
  });

  testWidgets('shows the TPMS dashboard', (tester) async {
    await tester.pumpWidget(const TpmsApp());
    expect(find.text('Front-Left'), findsOneWidget);
    expect(find.text('Front-Right'), findsOneWidget);
    expect(find.text('Connect dongle'), findsOneWidget);
  });
}
