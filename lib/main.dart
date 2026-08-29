import 'package:flutter/material.dart';
import 'screens/tpms_dashboard.dart';

void main() => runApp(const TpmsApp());

class TpmsApp extends StatelessWidget {
  const TpmsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Tyre Pressure',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
    ),
    home: const TpmsDashboard(),
  );
}
