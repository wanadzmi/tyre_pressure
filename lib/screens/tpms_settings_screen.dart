import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../config/tire_config.dart';
import '../models/pressure_unit.dart';
import '../models/temperature_unit.dart';
import '../models/tpms_alarm_settings.dart';

class TpmsConnectionStatus {
  const TpmsConnectionStatus({
    required this.message,
    this.isConnected = false,
    this.hasError = false,
  });

  final String message;
  final bool isConnected;
  final bool hasError;
}

class TpmsSettingsScreen extends StatefulWidget {
  const TpmsSettingsScreen({
    super.key,
    required this.pressureUnit,
    required this.onPressureUnitChanged,
    required this.temperatureUnit,
    required this.onTemperatureUnitChanged,
    required this.alarmSettings,
    required this.onAlarmSettingsChanged,
    required this.connectionStatus,
    required this.onRetryConnection,
    required this.tirePositions,
    required this.onTirePositionsChanged,
  });

  final PressureUnit pressureUnit;
  final ValueChanged<PressureUnit> onPressureUnitChanged;
  final TemperatureUnit temperatureUnit;
  final ValueChanged<TemperatureUnit> onTemperatureUnitChanged;
  final TpmsAlarmSettings alarmSettings;
  final ValueChanged<TpmsAlarmSettings> onAlarmSettingsChanged;
  final ValueListenable<TpmsConnectionStatus> connectionStatus;
  final Future<void> Function() onRetryConnection;
  final Map<String, String> tirePositions;
  final ValueChanged<Map<String, String>> onTirePositionsChanged;

  @override
  State<TpmsSettingsScreen> createState() => _TpmsSettingsScreenState();
}

class _TpmsSettingsScreenState extends State<TpmsSettingsScreen> {
  late PressureUnit _selectedUnit = widget.pressureUnit;
  late TemperatureUnit _selectedTemperatureUnit = widget.temperatureUnit;
  late TpmsAlarmSettings _alarmSettings = widget.alarmSettings;
  late Map<String, String> _tirePositions = Map.of(widget.tirePositions);
  String? _moveOrigin;
  String? _moveTarget;

  double get _pressureStep => _selectedUnit == PressureUnit.bar ? 0.1 : 1;

  void _adjustHighTemperature(double change) {
    final displayed = _selectedTemperatureUnit.fromCelsius(
      _alarmSettings.highTemperatureC,
    );
    final adjusted = displayed + change;
    if (adjusted < 0) return;
    _updateAlarms(
      _alarmSettings.copyWith(
        highTemperatureC: _selectedTemperatureUnit.toCelsius(adjusted),
      ),
    );
  }

  void _adjustHighPressure(double change) {
    final displayed = _selectedUnit.fromKpa(_alarmSettings.highPressureKpa);
    final adjusted = displayed + change;
    if (adjusted < 0) return;
    _updateAlarms(
      _alarmSettings.copyWith(highPressureKpa: _selectedUnit.toKpa(adjusted)),
    );
  }

  void _adjustLowPressure(double change) {
    final displayed = _selectedUnit.fromKpa(_alarmSettings.lowPressureKpa);
    final adjusted = displayed + change;
    if (adjusted < 0) return;
    _updateAlarms(
      _alarmSettings.copyWith(lowPressureKpa: _selectedUnit.toKpa(adjusted)),
    );
  }

  void _updateAlarms(TpmsAlarmSettings settings) {
    if (settings.lowPressureKpa >= settings.highPressureKpa) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Low pressure must be below high pressure.'),
        ),
      );
      return;
    }
    setState(() => _alarmSettings = settings);
    widget.onAlarmSettingsChanged(settings);
  }

  Map<String, String> get _previewPositions {
    if (_moveOrigin == null ||
        _moveTarget == null ||
        _moveOrigin == _moveTarget) {
      return _tirePositions;
    }
    final preview = Map<String, String>.of(_tirePositions);
    final originSensor = preview.entries
        .firstWhere((entry) => entry.value == _moveOrigin)
        .key;
    final targetSensor = preview.entries
        .firstWhere((entry) => entry.value == _moveTarget)
        .key;
    preview[originSensor] = _moveTarget!;
    preview[targetSensor] = _moveOrigin!;
    return preview;
  }

  void _selectPosition(String position) {
    setState(() {
      _moveOrigin = position;
      _moveTarget = position;
    });
  }

  void _moveSelection(String direction) {
    final current = _moveTarget;
    if (current == null) return;
    final next = switch ((current, direction)) {
      ('Front-Left', 'right') => 'Front-Right',
      ('Front-Left', 'down') => 'Rear-Left',
      ('Front-Right', 'left') => 'Front-Left',
      ('Front-Right', 'down') => 'Rear-Right',
      ('Rear-Left', 'right') => 'Rear-Right',
      ('Rear-Left', 'up') => 'Front-Left',
      ('Rear-Right', 'left') => 'Rear-Left',
      ('Rear-Right', 'up') => 'Front-Right',
      _ => null,
    };
    if (next != null) setState(() => _moveTarget = next);
  }

  void _confirmMove() {
    final preview = Map<String, String>.of(_previewPositions);
    setState(() {
      _tirePositions = preview;
      _moveOrigin = null;
      _moveTarget = null;
    });
    widget.onTirePositionsChanged(Map.of(_tirePositions));
  }

  void _cancelMove() {
    setState(() {
      _moveOrigin = null;
      _moveTarget = null;
    });
  }

  void _resetPositions() {
    setState(() {
      _tirePositions = Map.of(myTires);
      _moveOrigin = null;
      _moveTarget = null;
    });
    widget.onTirePositionsChanged(Map.of(_tirePositions));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'USB dongle',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<TpmsConnectionStatus>(
                  valueListenable: widget.connectionStatus,
                  builder: (context, connection, _) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      connection.hasError
                          ? Icons.usb_off
                          : (connection.isConnected
                                ? Icons.usb
                                : Icons.usb_outlined),
                      color: connection.hasError
                          ? Theme.of(context).colorScheme.error
                          : (connection.isConnected
                                ? const Color(0xFF64D98B)
                                : Colors.white54),
                    ),
                    title: Text(
                      connection.isConnected ? 'Connected' : 'Not connected',
                    ),
                    subtitle: Text(
                      connection.message,
                      style: connection.hasError
                          ? TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            )
                          : null,
                    ),
                    trailing: OutlinedButton.icon(
                      onPressed: widget.onRetryConnection,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tyre positions',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap a tyre circle, move it with the arrows, then tap OK to save.',
                  style: TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 12),
                _TirePositionDiagram(
                  positions: _previewPositions,
                  selectedPosition: _moveTarget,
                  originPosition: _moveOrigin,
                  onPositionSelected: _selectPosition,
                ),
                const SizedBox(height: 12),
                if (_moveOrigin != null)
                  _PositionControls(
                    target: _moveTarget!,
                    onMove: _moveSelection,
                    onCancel: _cancelMove,
                    onConfirm: _confirmMove,
                  )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _resetPositions,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset positions'),
                    ),
                  ),
                const SizedBox(height: 28),
                Text(
                  'Pressure unit',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                SegmentedButton<PressureUnit>(
                  segments: [
                    for (final unit in PressureUnit.values)
                      ButtonSegment(value: unit, label: Text(unit.label)),
                  ],
                  selected: {_selectedUnit},
                  onSelectionChanged: (selection) {
                    setState(() => _selectedUnit = selection.first);
                    widget.onPressureUnitChanged(selection.first);
                  },
                  showSelectedIcon: true,
                ),
                const SizedBox(height: 28),
                Text(
                  'Temperature unit',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                SegmentedButton<TemperatureUnit>(
                  segments: [
                    for (final unit in TemperatureUnit.values)
                      ButtonSegment(value: unit, label: Text(unit.label)),
                  ],
                  selected: {_selectedTemperatureUnit},
                  onSelectionChanged: (selection) {
                    setState(() => _selectedTemperatureUnit = selection.first);
                    widget.onTemperatureUnitChanged(selection.first);
                  },
                  showSelectedIcon: true,
                ),
                const SizedBox(height: 28),
                Text(
                  'Alarm thresholds',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                _AdjustmentTile(
                  title: 'High temperature',
                  value:
                      '${_selectedTemperatureUnit.fromCelsius(_alarmSettings.highTemperatureC).toStringAsFixed(1)} '
                      '${_selectedTemperatureUnit.label}',
                  onDecrease: () => _adjustHighTemperature(-1),
                  onIncrease: () => _adjustHighTemperature(1),
                  sliderValue: _selectedTemperatureUnit.fromCelsius(
                    _alarmSettings.highTemperatureC,
                  ),
                  sliderMin: _selectedTemperatureUnit.fromCelsius(40),
                  sliderMax: _temperatureSliderMax,
                  sliderDivisions:
                      _selectedTemperatureUnit == TemperatureUnit.fahrenheit
                      ? 144
                      : 80,
                  onSliderChanged: (value) => _updateAlarms(
                    _alarmSettings.copyWith(
                      highTemperatureC: _selectedTemperatureUnit.toCelsius(
                        value,
                      ),
                    ),
                  ),
                ),
                _AdjustmentTile(
                  title: 'High pressure',
                  value:
                      '${_selectedUnit.fromKpa(_alarmSettings.highPressureKpa).toStringAsFixed(_selectedUnit == PressureUnit.bar ? 1 : 0)} '
                      '${_selectedUnit.label}',
                  onDecrease: () => _adjustHighPressure(-_pressureStep),
                  onIncrease: () => _adjustHighPressure(_pressureStep),
                  sliderValue: _selectedUnit.fromKpa(
                    _alarmSettings.highPressureKpa,
                  ),
                  sliderMin:
                      _selectedUnit.fromKpa(_alarmSettings.lowPressureKpa) +
                      _pressureStep,
                  sliderMax: _highPressureSliderMax,
                  sliderDivisions: 100,
                  onSliderChanged: (value) => _updateAlarms(
                    _alarmSettings.copyWith(
                      highPressureKpa: _selectedUnit.toKpa(value),
                    ),
                  ),
                ),
                _AdjustmentTile(
                  title: 'Low pressure',
                  value:
                      '${_selectedUnit.fromKpa(_alarmSettings.lowPressureKpa).toStringAsFixed(_selectedUnit == PressureUnit.bar ? 1 : 0)} '
                      '${_selectedUnit.label}',
                  onDecrease: () => _adjustLowPressure(-_pressureStep),
                  onIncrease: () => _adjustLowPressure(_pressureStep),
                  sliderValue: _selectedUnit.fromKpa(
                    _alarmSettings.lowPressureKpa,
                  ),
                  sliderMin: 0,
                  sliderMax:
                      _selectedUnit.fromKpa(_alarmSettings.highPressureKpa) -
                      _pressureStep,
                  sliderDivisions: 100,
                  onSliderChanged: (value) => _updateAlarms(
                    _alarmSettings.copyWith(
                      lowPressureKpa: _selectedUnit.toKpa(value),
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Low battery sensor alarm'),
                  subtitle: const Text('Alert when a sensor reports low power'),
                  value: _alarmSettings.lowBatteryAlarmEnabled,
                  onChanged: (enabled) => _updateAlarms(
                    _alarmSettings.copyWith(lowBatteryAlarmEnabled: enabled),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  double get _temperatureSliderMax {
    final current = _selectedTemperatureUnit.fromCelsius(
      _alarmSettings.highTemperatureC,
    );
    final normalMaximum = _selectedTemperatureUnit.fromCelsius(120);
    return current > normalMaximum ? current : normalMaximum;
  }

  double get _highPressureSliderMax {
    final current = _selectedUnit.fromKpa(_alarmSettings.highPressureKpa);
    final normalMaximum = _selectedUnit.fromKpa(400);
    return current > normalMaximum ? current : normalMaximum;
  }
}

class _TirePositionDiagram extends StatelessWidget {
  const _TirePositionDiagram({
    required this.positions,
    required this.selectedPosition,
    required this.originPosition,
    required this.onPositionSelected,
  });

  final Map<String, String> positions;
  final String? selectedPosition;
  final String? originPosition;
  final ValueChanged<String> onPositionSelected;

  String _sensorAt(String position) =>
      positions.entries.firstWhere((entry) => entry.value == position).key;

  @override
  Widget build(BuildContext context) => Container(
    height: 250,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF12161B),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SensorPosition(
                key: ValueKey('FL-${_sensorAt('Front-Left')}'),
                shortPosition: 'FL',
                position: 'Front-Left',
                sensorId: _sensorAt('Front-Left'),
                alignRight: true,
                selected: selectedPosition == 'Front-Left',
                origin: originPosition == 'Front-Left',
                onTap: onPositionSelected,
              ),
              const Icon(Icons.swap_vert, color: Colors.white38),
              _SensorPosition(
                key: ValueKey('RL-${_sensorAt('Rear-Left')}'),
                shortPosition: 'RL',
                position: 'Rear-Left',
                sensorId: _sensorAt('Rear-Left'),
                alignRight: true,
                selected: selectedPosition == 'Rear-Left',
                origin: originPosition == 'Rear-Left',
                onTap: onPositionSelected,
              ),
            ],
          ),
        ),
        SizedBox(
          width: 150,
          child: Transform.flip(
            flipX: true,
            child: Image.asset(carImageAsset, fit: BoxFit.contain),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SensorPosition(
                key: ValueKey('FR-${_sensorAt('Front-Right')}'),
                shortPosition: 'FR',
                position: 'Front-Right',
                sensorId: _sensorAt('Front-Right'),
                alignRight: false,
                selected: selectedPosition == 'Front-Right',
                origin: originPosition == 'Front-Right',
                onTap: onPositionSelected,
              ),
              const Icon(Icons.swap_vert, color: Colors.white38),
              _SensorPosition(
                key: ValueKey('RR-${_sensorAt('Rear-Right')}'),
                shortPosition: 'RR',
                position: 'Rear-Right',
                sensorId: _sensorAt('Rear-Right'),
                alignRight: false,
                selected: selectedPosition == 'Rear-Right',
                origin: originPosition == 'Rear-Right',
                onTap: onPositionSelected,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SensorPosition extends StatelessWidget {
  const _SensorPosition({
    super.key,
    required this.shortPosition,
    required this.position,
    required this.sensorId,
    required this.alignRight,
    required this.selected,
    required this.origin,
    required this.onTap,
  });

  final String shortPosition;
  final String position;
  final String sensorId;
  final bool alignRight;
  final bool selected;
  final bool origin;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '${position.replaceAll('-', ' ')} sensor $sensorId',
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF64B5F6).withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisAlignment: alignRight
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!alignRight) ...[
              _PositionCircle(
                label: shortPosition,
                selected: selected,
                origin: origin,
                onTap: () => onTap(position),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: alignRight
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    position.replaceAll('-', ' '),
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    sensorId,
                    key: ValueKey('mapping-$shortPosition-$sensorId'),
                    style: const TextStyle(
                      color: Color(0xFF64B5F6),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            if (alignRight) ...[
              const SizedBox(width: 8),
              _PositionCircle(
                label: shortPosition,
                selected: selected,
                origin: origin,
                onTap: () => onTap(position),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _PositionCircle extends StatelessWidget {
  const _PositionCircle({
    required this.label,
    required this.selected,
    required this.origin,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool origin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('position-$label'),
    onTap: onTap,
    customBorder: const CircleBorder(),
    child: Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? const Color(0xFF64B5F6).withValues(alpha: 0.4)
            : const Color(0xFF64B5F6).withValues(alpha: 0.14),
        border: Border.all(
          color: origin ? const Color(0xFFFFC857) : const Color(0xFF64B5F6),
          width: selected || origin ? 2 : 1,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF8BC9FF),
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

class _PositionControls extends StatelessWidget {
  const _PositionControls({
    required this.target,
    required this.onMove,
    required this.onCancel,
    required this.onConfirm,
  });

  final String target;
  final ValueChanged<String> onMove;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF12161B),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _arrow('up', Icons.keyboard_arrow_up),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _arrow('left', Icons.keyboard_arrow_left),
                const SizedBox(width: 48),
                _arrow('right', Icons.keyboard_arrow_right),
              ],
            ),
            _arrow('down', Icons.keyboard_arrow_down),
          ],
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            'Preview position\n${target.replaceAll('-', ' ')}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        TextButton(onPressed: onCancel, child: const Text('Cancel')),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: onConfirm,
          icon: const Icon(Icons.check),
          label: const Text('OK'),
        ),
      ],
    ),
  );

  Widget _arrow(String direction, IconData icon) => IconButton.filledTonal(
    key: ValueKey('move-$direction'),
    tooltip: 'Move $direction',
    onPressed: () => onMove(direction),
    icon: Icon(icon, size: 30),
  );
}

class _AdjustmentTile extends StatelessWidget {
  const _AdjustmentTile({
    required this.title,
    required this.value,
    required this.onDecrease,
    required this.onIncrease,
    required this.sliderValue,
    required this.sliderMin,
    required this.sliderMax,
    required this.sliderDivisions,
    required this.onSliderChanged,
  });

  final String title;
  final String value;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final double sliderValue;
  final double sliderMin;
  final double sliderMax;
  final int sliderDivisions;
  final ValueChanged<double> onSliderChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(title)),
            IconButton.filledTonal(
              onPressed: onDecrease,
              tooltip: 'Decrease $title',
              icon: const Icon(Icons.chevron_left, size: 30),
            ),
            SizedBox(
              width: 112,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton.filledTonal(
              onPressed: onIncrease,
              tooltip: 'Increase $title',
              icon: const Icon(Icons.chevron_right, size: 30),
            ),
          ],
        ),
        Slider(
          value: sliderValue.clamp(sliderMin, sliderMax),
          min: sliderMin,
          max: sliderMax,
          divisions: sliderDivisions,
          label: value,
          onChanged: onSliderChanged,
        ),
      ],
    ),
  );
}
