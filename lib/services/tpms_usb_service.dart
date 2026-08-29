import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';

import '../models/tire_telemetry.dart';
import 'tpms_parser.dart';

class TpmsUsbService {
  TpmsUsbService({TpmsParser parser = const TpmsParser()}) : _parser = parser;

  static const int vendorId = 0x1A86;
  static const int productId = 0x7523;
  static const int baudRate = 19200;

  final TpmsParser _parser;
  final _updates = StreamController<TireTelemetry>.broadcast();
  final _status = StreamController<String>.broadcast();
  final List<int> _receiveBuffer = [];

  UsbPort? _port;
  StreamSubscription<Uint8List>? _inputSubscription;
  StreamSubscription<UsbEvent>? _usbEventSubscription;

  Stream<TireTelemetry> get updates => _updates.stream;
  Stream<String> get status => _status.stream;

  Future<void> start() async {
    if (_port != null) {
      _setStatus('Dongle already connected');
      return;
    }

    _setStatus('Looking for TPMS USB dongle...');
    final devices = await UsbSerial.listDevices();
    for (final device in devices) {
      debugPrint(
        '[TPMS-USB] Found ${device.productName ?? 'USB device'} '
        'VID=0x${_hex16(device.vid)} PID=0x${_hex16(device.pid)} '
        'deviceId=${device.deviceId}',
      );
    }

    final dongle = devices.cast<UsbDevice?>().firstWhere(
      (device) => device?.vid == vendorId && device?.pid == productId,
      orElse: () => null,
    );
    if (dongle == null) {
      throw StateError('TPMS dongle 1A86:7523 is not connected');
    }

    _setStatus('Requesting USB permission...');
    final port = await dongle.create(UsbSerial.CH34x);
    if (port == null) throw StateError('Could not create CH34x serial port');

    final opened = await port.open();
    if (!opened) throw StateError('USB permission denied or port is busy');

    try {
      await port.setPortParameters(
        baudRate,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );
      _port = port;
      _inputSubscription = port.inputStream?.listen(
        _handleBytes,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('[TPMS-USB] Read error: $error');
          _updates.addError(error, stackTrace);
          _setStatus('USB read error: $error');
        },
        onDone: () => _setStatus('TPMS dongle disconnected'),
      );
      _usbEventSubscription ??= UsbSerial.usbEventStream?.listen((event) {
        debugPrint('[TPMS-USB] USB event: $event');
      });
      _setStatus('Dongle connected at $baudRate baud; waiting for sensors');
    } catch (_) {
      await port.close();
      rethrow;
    }
  }

  void _handleBytes(Uint8List bytes) {
    debugPrint('[TPMS-USB] RX ${bytes.length} bytes: ${_toHex(bytes)}');
    _receiveBuffer.addAll(bytes);
    _processBufferedFrames();
  }

  void _processBufferedFrames() {
    while (_receiveBuffer.length >= 3) {
      final header = _findHeader();
      if (header < 0) {
        _receiveBuffer.clear();
        return;
      }
      if (header > 0) _receiveBuffer.removeRange(0, header);

      final frameLength = _receiveBuffer[2];
      if (frameLength < 4 || frameLength > 64) {
        _receiveBuffer.removeAt(0);
        continue;
      }
      if (_receiveBuffer.length < frameLength) return;

      final frame = _receiveBuffer.sublist(0, frameLength);
      _receiveBuffer.removeRange(0, frameLength);
      final telemetry = _parser.parse(frame);
      if (telemetry == null) {
        debugPrint('[TPMS-USB] Ignored invalid/unsupported frame: ${_toHex(frame)}');
        continue;
      }

      debugPrint(
        '[TPMS-USB] MATCH ${telemetry.position} (${telemetry.sensorId}) '
        '${telemetry.pressureKpa.toStringAsFixed(1)} kPa / '
        '${telemetry.pressurePsi.toStringAsFixed(1)} PSI, '
        '${telemetry.temperatureC} C, status=${_statusText(telemetry)}',
      );
      _updates.add(telemetry);
    }
  }

  int _findHeader() {
    for (var i = 0; i < _receiveBuffer.length - 1; i++) {
      if (_receiveBuffer[i] == 0x55 && _receiveBuffer[i + 1] == 0xAA) {
        return i;
      }
    }
    return -1;
  }

  String _statusText(TireTelemetry reading) {
    final warnings = <String>[
      if (reading.lowBattery) 'low battery',
      if (reading.leakage) 'leakage',
      if (reading.noSignal) 'no signal',
    ];
    return warnings.isEmpty ? 'OK' : warnings.join(', ');
  }

  Future<void> stop() async {
    await _inputSubscription?.cancel();
    _inputSubscription = null;
    await _port?.close();
    _port = null;
    _receiveBuffer.clear();
    _setStatus('Dongle disconnected');
  }

  Future<void> dispose() async {
    await stop();
    await _usbEventSubscription?.cancel();
    await _updates.close();
    await _status.close();
  }

  void _setStatus(String value) {
    debugPrint('[TPMS-USB] $value');
    _status.add(value);
  }

  String _hex16(int? value) =>
      value?.toRadixString(16).padLeft(4, '0').toUpperCase() ?? '????';

  String _toHex(Iterable<int> bytes) => bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join(' ')
      .toUpperCase();
}
