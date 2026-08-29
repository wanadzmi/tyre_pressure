import 'package:flutter/material.dart';

import '../models/pressure_unit.dart';
import '../models/temperature_unit.dart';
import '../models/tpms_alarm_settings.dart';

class TpmsSettingsScreen extends StatefulWidget {
  const TpmsSettingsScreen({
    super.key,
    required this.pressureUnit,
    required this.onPressureUnitChanged,
    required this.temperatureUnit,
    required this.onTemperatureUnitChanged,
    required this.alarmSettings,
    required this.onAlarmSettingsChanged,
  });

  final PressureUnit pressureUnit;
  final ValueChanged<PressureUnit> onPressureUnitChanged;
  final TemperatureUnit temperatureUnit;
  final ValueChanged<TemperatureUnit> onTemperatureUnitChanged;
  final TpmsAlarmSettings alarmSettings;
  final ValueChanged<TpmsAlarmSettings> onAlarmSettingsChanged;

  @override
  State<TpmsSettingsScreen> createState() => _TpmsSettingsScreenState();
}

class _TpmsSettingsScreenState extends State<TpmsSettingsScreen> {
  late PressureUnit _selectedUnit = widget.pressureUnit;
  late TemperatureUnit _selectedTemperatureUnit = widget.temperatureUnit;
  late TpmsAlarmSettings _alarmSettings = widget.alarmSettings;

  Future<void> _editThreshold({
    required String title,
    required double value,
    required String unit,
    required ValueChanged<double> onSaved,
  }) async {
    final controller = TextEditingController(text: value.toStringAsFixed(1));
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: unit),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed != null && parsed >= 0) Navigator.pop(context, parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) onSaved(result);
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('TPMS Settings')),
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
                _SettingTile(
                  title: 'High temperature',
                  value:
                      '${_selectedTemperatureUnit.fromCelsius(_alarmSettings.highTemperatureC).toStringAsFixed(1)} '
                      '${_selectedTemperatureUnit.label}',
                  onTap: () => _editThreshold(
                    title: 'High temperature alarm',
                    value: _selectedTemperatureUnit.fromCelsius(
                      _alarmSettings.highTemperatureC,
                    ),
                    unit: _selectedTemperatureUnit.label,
                    onSaved: (value) => _updateAlarms(
                      _alarmSettings.copyWith(
                        highTemperatureC: _selectedTemperatureUnit.toCelsius(
                          value,
                        ),
                      ),
                    ),
                  ),
                ),
                _SettingTile(
                  title: 'High pressure',
                  value:
                      '${_selectedUnit.fromKpa(_alarmSettings.highPressureKpa).toStringAsFixed(1)} '
                      '${_selectedUnit.label}',
                  onTap: () => _editThreshold(
                    title: 'High pressure alarm',
                    value: _selectedUnit.fromKpa(
                      _alarmSettings.highPressureKpa,
                    ),
                    unit: _selectedUnit.label,
                    onSaved: (value) => _updateAlarms(
                      _alarmSettings.copyWith(
                        highPressureKpa: _selectedUnit.toKpa(value),
                      ),
                    ),
                  ),
                ),
                _SettingTile(
                  title: 'Low pressure',
                  value:
                      '${_selectedUnit.fromKpa(_alarmSettings.lowPressureKpa).toStringAsFixed(1)} '
                      '${_selectedUnit.label}',
                  onTap: () => _editThreshold(
                    title: 'Low pressure alarm',
                    value: _selectedUnit.fromKpa(
                      _alarmSettings.lowPressureKpa,
                    ),
                    unit: _selectedUnit.label,
                    onSaved: (value) => _updateAlarms(
                      _alarmSettings.copyWith(
                        lowPressureKpa: _selectedUnit.toKpa(value),
                      ),
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
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(value),
    trailing: const Icon(Icons.edit),
    onTap: onTap,
  );
}
