import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/tpms_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const TpmsApp());
}

class TpmsApp extends StatelessWidget {
  const TpmsApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Tyre Pressure',
    theme: ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4D9DFF),
        brightness: Brightness.dark,
        surface: const Color(0xFF111419),
      ),
      scaffoldBackgroundColor: const Color(0xFF07090C),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF15191F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      useMaterial3: true,
    ),
    home: home ?? const TpmsDashboard(),
  );
}
