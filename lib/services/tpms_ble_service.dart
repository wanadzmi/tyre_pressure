import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/tire_telemetry.dart';
import 'tpms_parser.dart';

class TpmsBleService {
  TpmsBleService({TpmsParser parser = const TpmsParser()}) : _parser = parser;

  final TpmsParser _parser;
  final _updates = StreamController<TireTelemetry>.broadcast();
  final Map<String, DateTime> _lastUnknownLog = {};
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  Stream<TireTelemetry> get updates => _updates.stream;

  Future<void> start() async {
    if (_scanSubscription != null) {
      debugPrint('[TPMS] Scan is already running');
      return;
    }
    debugPrint('[TPMS] Starting BLE scan...');
    _scanSubscription = FlutterBluePlus.onScanResults.listen(
      _handleResults,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[TPMS] Scan error: $error');
        _updates.addError(error, stackTrace);
      },
    );
    try {
      await FlutterBluePlus.startScan(continuousUpdates: true);
      debugPrint('[TPMS] BLE scan started successfully');
    } catch (error) {
      debugPrint('[TPMS] Could not start scan: $error');
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      rethrow;
    }
  }

  void _handleResults(List<ScanResult> results) {
    for (final result in results) {
      final data = result.advertisementData;
      final deviceId = result.device.remoteId.toString();
      final payloads = <({String source, List<int> bytes})>[
        for (final entry in data.manufacturerData.entries)
          (source: 'manufacturer:${entry.key}', bytes: entry.value),
        for (final entry in data.serviceData.entries)
          (source: 'service:${entry.key}', bytes: entry.value),
      ];

      for (final payload in payloads) {
        final telemetry = _parser.parse(payload.bytes);
        if (telemetry != null) {
          debugPrint(
            '[TPMS] MATCH ${telemetry.position} (${telemetry.sensorId}) '
            '${telemetry.pressureKpa.toStringAsFixed(0)} kPa / '
            '${telemetry.pressurePsi.toStringAsFixed(1)} PSI, '
            '${telemetry.temperatureC} C, ${telemetry.batteryPercent}% battery; '
            '${payload.source}=${_toHex(payload.bytes)}',
          );
          _updates.add(telemetry);
        } else if (_shouldLogUnknown(deviceId)) {
          debugPrint(
            '[TPMS] Unmatched device=$deviceId rssi=${result.rssi} '
            '${payload.source}=${_toHex(payload.bytes)}',
          );
        }
      }
    }
  }

  bool _shouldLogUnknown(String deviceId) {
    final now = DateTime.now();
    final lastLog = _lastUnknownLog[deviceId];
    if (lastLog != null && now.difference(lastLog) < const Duration(seconds: 5)) {
      return false;
    }
    _lastUnknownLog[deviceId] = now;
    return true;
  }

  String _toHex(List<int> bytes) => bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join(' ')
      .toUpperCase();

  Future<void> stop() async {
    debugPrint('[TPMS] Stopping BLE scan...');
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _lastUnknownLog.clear();
    debugPrint('[TPMS] BLE scan stopped');
  }

  Future<void> dispose() async {
    await stop();
    await _updates.close();
  }
}
