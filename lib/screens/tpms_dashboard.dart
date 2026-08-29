import 'dart:async';
import 'package:flutter/material.dart';
import '../config/tire_config.dart';
import '../models/tire_telemetry.dart';
import '../services/tpms_usb_service.dart';

class TpmsDashboard extends StatefulWidget {
  const TpmsDashboard({super.key});

  @override
  State<TpmsDashboard> createState() => _TpmsDashboardState();
}

class _TpmsDashboardState extends State<TpmsDashboard> {
  final _usbService = TpmsUsbService();
  final Map<String, TireTelemetry> _readings = {};
  StreamSubscription<TireTelemetry>? _subscription;
  StreamSubscription<String>? _statusSubscription;
  bool _isConnected = false;
  String _status = 'Connect the TPMS dongle to begin';
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = _usbService.updates.listen(
      (reading) {
        if (mounted) {
          setState(() => _readings[reading.sensorId] = reading);
        }
      },
      onError: (Object error) {
        if (mounted) {
          setState(() => _error = error.toString());
        }
      },
    );
    _statusSubscription = _usbService.status.listen((status) {
      if (mounted) setState(() => _status = status);
    });
  }

  Future<void> _toggleConnection() async {
    final shouldConnect = !_isConnected;
    setState(() {
      _isConnected = shouldConnect;
      _error = null;
    });
    try {
      if (shouldConnect) {
        await _usbService.start();
      } else {
        await _usbService.stop();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _statusSubscription?.cancel();
    _usbService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tyre Pressure Monitor')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          FilledButton.icon(
            onPressed: _toggleConnection,
            icon: Icon(_isConnected ? Icons.usb_off : Icons.usb),
            label: Text(_isConnected ? 'Disconnect dongle' : 'Connect dongle'),
          ),
          const SizedBox(height: 8),
          Text(_status, textAlign: TextAlign.center),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                for (final tire in myTires.entries)
                  _TireCard(
                    sensorId: tire.key,
                    position: tire.value,
                    reading: _readings[tire.key],
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _TireCard extends StatelessWidget {
  const _TireCard({
    required this.sensorId,
    required this.position,
    required this.reading,
  });
  final String sensorId;
  final String position;
  final TireTelemetry? reading;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(position, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(sensorId, style: Theme.of(context).textTheme.labelSmall),
          const Spacer(),
          Text(
            reading == null
                ? '-- PSI'
                : '${reading!.pressurePsi.toStringAsFixed(1)} PSI',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            reading == null
                ? '-- kPa'
                : '${reading!.pressureKpa.toStringAsFixed(1)} kPa',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(reading == null ? '-- °C' : '${reading!.temperatureC} °C'),
          Text(reading == null ? 'Battery --' : _statusText(reading!)),
          const Spacer(),
          Text(reading == null ? 'Waiting for sensor' : 'Receiving data'),
        ],
      ),
    ),
  );

  String _statusText(TireTelemetry reading) {
    if (reading.noSignal) return 'No signal';
    if (reading.leakage) return 'Leakage warning';
    if (reading.lowBattery) return 'Low battery';
    return 'Status OK';
  }
}
