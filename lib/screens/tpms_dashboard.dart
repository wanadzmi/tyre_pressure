import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/tire_config.dart';
import '../models/pressure_unit.dart';
import '../models/temperature_unit.dart';
import '../models/tire_telemetry.dart';
import '../models/tpms_alarm_settings.dart';
import '../services/tpms_data_source.dart';
import '../services/tpms_fake_service.dart';
import '../services/tpms_usb_service.dart';
import 'tpms_settings_screen.dart';

class TpmsDashboard extends StatefulWidget {
  const TpmsDashboard({super.key, this.autoStart = true});

  final bool autoStart;

  @override
  State<TpmsDashboard> createState() => _TpmsDashboardState();
}

class _TpmsDashboardState extends State<TpmsDashboard> {
  static const _pressureUnitKey = 'pressure_unit';
  static const _temperatureUnitKey = 'temperature_unit';
  static const _highTemperatureKey = 'alarm_high_temperature_c';
  static const _highPressureKey = 'alarm_high_pressure_kpa';
  static const _lowPressureKey = 'alarm_low_pressure_kpa';
  static const _lowBatteryAlarmKey = 'alarm_low_battery_enabled';

  late final bool _isDesignPreview =
      kIsWeb || defaultTargetPlatform != TargetPlatform.android;
  late final TpmsDataSource _tpmsService = _isDesignPreview
      ? TpmsFakeService()
      : TpmsUsbService();
  final Map<String, TireTelemetry> _readings = {};
  StreamSubscription<TireTelemetry>? _subscription;
  StreamSubscription<String>? _statusSubscription;
  Timer? _relativeTimeTimer;
  bool _isConnected = false;
  String _status = 'Connect the TPMS dongle to begin';
  String? _error;
  PressureUnit _pressureUnit = PressureUnit.psi;
  TemperatureUnit _temperatureUnit = TemperatureUnit.celsius;
  TpmsAlarmSettings _alarmSettings = const TpmsAlarmSettings();
  final Set<String> _activeAlarmKeys = {};
  final List<_AlarmMessage> _pendingAlarms = [];
  bool _alarmDialogVisible = false;

  @override
  void initState() {
    super.initState();
    _loadPressureUnit();
    _loadTemperatureUnit();
    _loadAlarmSettings();
    _subscription = _tpmsService.updates.listen(
      _handleReading,
      onError: (Object error) {
        if (mounted) {
          setState(() => _error = error.toString());
        }
      },
    );
    _statusSubscription = _tpmsService.status.listen((status) {
      if (mounted) setState(() => _status = status);
    });
    _relativeTimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _readings.isNotEmpty) setState(() {});
    });
    if (widget.autoStart) {
      Future.microtask(_toggleConnection);
    }
  }

  Future<void> _loadPressureUnit() async {
    try {
      final savedValue = await SharedPreferencesAsync().getString(
        _pressureUnitKey,
      );
      final unit = PressureUnit.values.where((item) => item.name == savedValue);
      if (mounted && unit.isNotEmpty) {
        setState(() => _pressureUnit = unit.first);
      }
    } catch (error) {
      debugPrint('[TPMS] Could not load pressure unit: $error');
    }
  }

  Future<void> _setPressureUnit(PressureUnit unit) async {
    setState(() => _pressureUnit = unit);
    try {
      await SharedPreferencesAsync().setString(_pressureUnitKey, unit.name);
    } catch (error) {
      debugPrint('[TPMS] Could not save pressure unit: $error');
    }
  }

  Future<void> _loadTemperatureUnit() async {
    try {
      final savedValue = await SharedPreferencesAsync().getString(
        _temperatureUnitKey,
      );
      final unit = TemperatureUnit.values.where(
        (item) => item.name == savedValue,
      );
      if (mounted && unit.isNotEmpty) {
        setState(() => _temperatureUnit = unit.first);
      }
    } catch (error) {
      debugPrint('[TPMS] Could not load temperature unit: $error');
    }
  }

  Future<void> _setTemperatureUnit(TemperatureUnit unit) async {
    setState(() => _temperatureUnit = unit);
    try {
      await SharedPreferencesAsync().setString(_temperatureUnitKey, unit.name);
    } catch (error) {
      debugPrint('[TPMS] Could not save temperature unit: $error');
    }
  }

  Future<void> _loadAlarmSettings() async {
    try {
      final preferences = SharedPreferencesAsync();
      final defaults = const TpmsAlarmSettings();
      final settings = TpmsAlarmSettings(
        highTemperatureC:
            await preferences.getDouble(_highTemperatureKey) ??
            defaults.highTemperatureC,
        highPressureKpa:
            await preferences.getDouble(_highPressureKey) ??
            defaults.highPressureKpa,
        lowPressureKpa:
            await preferences.getDouble(_lowPressureKey) ??
            defaults.lowPressureKpa,
        lowBatteryAlarmEnabled:
            await preferences.getBool(_lowBatteryAlarmKey) ??
            defaults.lowBatteryAlarmEnabled,
      );
      if (mounted) {
        setState(() => _alarmSettings = settings);
        for (final reading in _readings.values) {
          _evaluateAlarms(reading);
        }
      }
    } catch (error) {
      debugPrint('[TPMS] Could not load alarm settings: $error');
    }
  }

  Future<void> _setAlarmSettings(TpmsAlarmSettings settings) async {
    setState(() => _alarmSettings = settings);
    for (final reading in _readings.values) {
      _evaluateAlarms(reading);
    }
    try {
      final preferences = SharedPreferencesAsync();
      await Future.wait([
        preferences.setDouble(_highTemperatureKey, settings.highTemperatureC),
        preferences.setDouble(_highPressureKey, settings.highPressureKpa),
        preferences.setDouble(_lowPressureKey, settings.lowPressureKpa),
        preferences.setBool(
          _lowBatteryAlarmKey,
          settings.lowBatteryAlarmEnabled,
        ),
      ]);
    } catch (error) {
      debugPrint('[TPMS] Could not save alarm settings: $error');
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TpmsSettingsScreen(
          pressureUnit: _pressureUnit,
          onPressureUnitChanged: _setPressureUnit,
          temperatureUnit: _temperatureUnit,
          onTemperatureUnitChanged: _setTemperatureUnit,
          alarmSettings: _alarmSettings,
          onAlarmSettingsChanged: _setAlarmSettings,
        ),
      ),
    );
    _showNextAlarm();
  }

  void _injectTestAlarms() {
    if (_alarmDialogVisible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acknowledge the current alarm first.')),
      );
      return;
    }

    _activeAlarmKeys.clear();
    _pendingAlarms.clear();
    final now = DateTime.now();
    final normalPressure =
        (_alarmSettings.lowPressureKpa + _alarmSettings.highPressureKpa) / 2;
    final normalTemperature = (_alarmSettings.highTemperatureC - 10).round();
    final testReadings = [
      TireTelemetry(
        sensorId: '05EFEFF1',
        position: 'Front-Left',
        pressureKpa: normalPressure,
        temperatureC: (_alarmSettings.highTemperatureC + 10).round(),
        lastUpdated: now,
      ),
      TireTelemetry(
        sensorId: '02F05A72',
        position: 'Front-Right',
        pressureKpa: _alarmSettings.highPressureKpa + 20,
        temperatureC: normalTemperature,
        lastUpdated: now,
      ),
      TireTelemetry(
        sensorId: '02F00EA8',
        position: 'Rear-Left',
        pressureKpa: (_alarmSettings.lowPressureKpa - 20).clamp(0, 1000),
        temperatureC: normalTemperature,
        lastUpdated: now,
      ),
      TireTelemetry(
        sensorId: '01EFB068',
        position: 'Rear-Right',
        pressureKpa: normalPressure,
        temperatureC: normalTemperature,
        lowBattery: true,
        lastUpdated: now,
      ),
    ];

    for (final reading in testReadings) {
      _handleReading(reading);
    }
  }

  void _handleReading(TireTelemetry reading) {
    if (!mounted) return;
    setState(() => _readings[reading.sensorId] = reading);
    _evaluateAlarms(reading);
  }

  void _evaluateAlarms(TireTelemetry reading) {
    final pressure = _pressureUnit.format(reading.pressureKpa);
    final temperature = _temperatureUnit.format(reading.temperatureC);
    _updateAlarm(
      '${reading.sensorId}:high-temperature',
      _alarmSettings.isHighTemperature(reading.temperatureC.toDouble()),
      '${reading.position} temperature is $temperature.',
    );
    _updateAlarm(
      '${reading.sensorId}:high-pressure',
      _alarmSettings.isHighPressure(reading.pressureKpa),
      '${reading.position} pressure is high at $pressure.',
    );
    _updateAlarm(
      '${reading.sensorId}:low-pressure',
      _alarmSettings.isLowPressure(reading.pressureKpa),
      '${reading.position} pressure is low at $pressure.',
    );
    _updateAlarm(
      '${reading.sensorId}:low-battery',
      _alarmSettings.shouldAlertLowBattery(reading.lowBattery),
      '${reading.position} sensor battery is low.',
    );
  }

  void _updateAlarm(String key, bool active, String message) {
    if (!active) {
      _activeAlarmKeys.remove(key);
      return;
    }
    if (_activeAlarmKeys.add(key)) {
      _pendingAlarms.add(_AlarmMessage(message));
      _showNextAlarm();
    }
  }

  void _showNextAlarm() {
    if (_alarmDialogVisible ||
        _pendingAlarms.isEmpty ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _alarmDialogVisible = true;
    final alarm = _pendingAlarms.removeAt(0);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text('TPMS warning'),
          content: Text(alarm.message, textAlign: TextAlign.center),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Acknowledge'),
            ),
          ],
        ),
      );
      _alarmDialogVisible = false;
      _showNextAlarm();
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
        await _tpmsService.start();
      } else {
        await _tpmsService.stop();
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
    _relativeTimeTimer?.cancel();
    _tpmsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,

        actions: [
          IconButton(
            onPressed: _injectTestAlarms,
            tooltip: 'Test all alarms',
            icon: const Icon(Icons.science_outlined),
          ),
          IconButton(
            onPressed: _openSettings,
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF15191F), Color(0xFF090B0F), Color(0xFF030405)],
            stops: [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final padding = constraints.maxWidth < 700 ? 8.0 : 16.0;
              return Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  children: [
                    if (!_isDesignPreview) ...[
                      _ConnectionBar(
                        isConnected: _isConnected,
                        status: _status,
                        error: _error,
                        onPressed: _toggleConnection,
                      ),
                      SizedBox(height: padding),
                    ],
                    Expanded(
                      child: _VehicleTpmsLayout(
                        readings: _readings,
                        pressureUnit: _pressureUnit,
                        temperatureUnit: _temperatureUnit,
                        alarmSettings: _alarmSettings,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VehicleTpmsLayout extends StatelessWidget {
  const _VehicleTpmsLayout({
    required this.readings,
    required this.pressureUnit,
    required this.temperatureUnit,
    required this.alarmSettings,
  });

  final Map<String, TireTelemetry> readings;
  final PressureUnit pressureUnit;
  final TemperatureUnit temperatureUnit;
  final TpmsAlarmSettings alarmSettings;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 10.0;
      final imageWidth = (constraints.maxHeight * 2 / 3).clamp(
        120.0,
        constraints.maxWidth * 0.42,
      );
      final readingWidth = ((constraints.maxWidth - imageWidth - gap * 2) / 2)
          .clamp(120.0, 300.0);
      final readingHeight = (constraints.maxHeight * 0.38).clamp(72.0, 180.0);
      // The visible car occupies roughly 78% of the PNG width. Position the
      // readings against that visual edge instead of the image file's bounds.
      final visibleCarWidth = imageWidth * 0.78;
      final calculatedInset =
          (constraints.maxWidth - visibleCarWidth) / 2 - readingWidth + 8;
      final sideInset = calculatedInset < 0 ? 0.0 : calculatedInset;
      final verticalInset = constraints.maxHeight * 0.06;

      Widget reading(String sensorId, {required bool isLeft}) => SizedBox(
        width: readingWidth,
        height: readingHeight,
        child: _TireReading(
          position: myTires[sensorId]!,
          reading: readings[sensorId],
          pressureUnit: pressureUnit,
          temperatureUnit: temperatureUnit,
          alarmSettings: alarmSettings,
          isLeft: isLeft,
        ),
      );

      return Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Center(
              child: SizedBox(
                width: imageWidth,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Transform.flip(
                    flipX: true,
                    child: Image.asset(
                      'assets/axia-bird-viewX.png',
                      fit: BoxFit.contain,
                      semanticLabel: 'Top view of the car',
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: sideInset,
            top: verticalInset,
            child: reading('05EFEFF1', isLeft: true),
          ),
          Positioned(
            right: sideInset,
            top: verticalInset,
            child: reading('02F05A72', isLeft: false),
          ),
          Positioned(
            left: sideInset,
            bottom: verticalInset,
            child: reading('02F00EA8', isLeft: true),
          ),
          Positioned(
            right: sideInset,
            bottom: verticalInset,
            child: reading('01EFB068', isLeft: false),
          ),
        ],
      );
    },
  );
}

class _ConnectionBar extends StatelessWidget {
  const _ConnectionBar({
    required this.isConnected,
    required this.status,
    required this.error,
    required this.onPressed,
  });

  final bool isConnected;
  final String status;
  final String? error;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(isConnected ? Icons.usb_off : Icons.usb),
        label: Text(isConnected ? 'Disconnect' : 'Connect dongle'),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          error ?? status,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: error == null
              ? null
              : TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    ],
  );
}

class _TireReading extends StatelessWidget {
  const _TireReading({
    required this.position,
    required this.reading,
    required this.pressureUnit,
    required this.temperatureUnit,
    required this.alarmSettings,
    required this.isLeft,
  });
  final String position;
  final TireTelemetry? reading;
  final PressureUnit pressureUnit;
  final TemperatureUnit temperatureUnit;
  final TpmsAlarmSettings alarmSettings;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    final arrow = Icon(
      isLeft ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
      color: _statusColor(context),
      size: 36,
      semanticLabel: reading == null
          ? '$position waiting for tyre data'
          : (_isHealthy
                ? '$position tyre status okay'
                : '$position tyre warning'),
    );
    final details = Expanded(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: isLeft ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isLeft
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              reading == null
                  ? '-- ${pressureUnit.label}'
                  : pressureUnit.format(reading!.pressureKpa),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              reading == null
                  ? '-- ${temperatureUnit.label}'
                  : temperatureUnit.format(reading!.temperatureC),
            ),
            Text(
              reading == null
                  ? 'No update'
                  : _formatLastUpdated(reading!.lastUpdated),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      mainAxisAlignment: isLeft
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: isLeft
          ? [details, const SizedBox(width: 6), arrow]
          : [arrow, const SizedBox(width: 6), details],
    );
  }

  bool get _isHealthy =>
      reading != null &&
      !reading!.noSignal &&
      !reading!.leakage &&
      !reading!.lowBattery &&
      reading!.temperatureC <= alarmSettings.highTemperatureC &&
      reading!.pressureKpa <= alarmSettings.highPressureKpa &&
      reading!.pressureKpa >= alarmSettings.lowPressureKpa;

  Color _statusColor(BuildContext context) {
    if (reading == null) return Theme.of(context).colorScheme.outline;
    return _isHealthy ? Colors.green : Theme.of(context).colorScheme.error;
  }

  String _formatLastUpdated(DateTime lastUpdated) {
    final elapsed = DateTime.now().difference(lastUpdated);
    if (elapsed.inSeconds < 2) return 'Updated now';
    if (elapsed.inSeconds < 60) return 'Updated ${elapsed.inSeconds}s ago';
    if (elapsed.inMinutes < 60) return 'Updated ${elapsed.inMinutes}m ago';
    return 'Updated ${elapsed.inHours}h ago';
  }
}

class _AlarmMessage {
  const _AlarmMessage(this.message);

  final String message;
}
