import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../app/app_language.dart';
import '../data/local_store.dart';
import '../models/domain.dart';
import '../services/contracts.dart';
import '../services/farm_media_service.dart';

class HomeScreen extends StatefulWidget {
  final WeatherService? weatherService;
  final FarmingCalendarService? calendarService;
  final CropRecommendationService? recommendationService;
  final FarmingReminderService? reminderService;
  const HomeScreen(
      {super.key,
      this.weatherService,
      this.calendarService,
      this.recommendationService,
      this.reminderService});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, Object?>> farms = [], tests = [];
  int fieldCount = 0;
  WeatherSummary? weather;
  List<CalendarEvent> events = [];
  List<CropEstimate> recommendations = [];
  bool weatherError = false, calendarError = false, recommendationError = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = LocalStore.instance;
    final f = await store.farms();
    var count = 0;
    for (final farm in f) {
      count += (await store.fields(farm['id'] as int)).length;
    }
    final t = await store.latestTests();
    if (mounted)
      setState(() {
        farms = f;
        fieldCount = count;
        tests = t;
      });
    if (widget.weatherService != null) {
      try {
        final first = f.isEmpty ? null : f.first;
        weather = await widget.weatherService!
            .summary(first?['lat'] as double?, first?['lon'] as double?);
      } catch (_) {
        weatherError = true;
      }
    }
    if (widget.calendarService != null) {
      try {
        final all = <CalendarEvent>[];
        for (final farm in f) {
          all.addAll(await widget.calendarService!.events(farm['id'] as int));
        }
        all.sort((a, b) => a.date.compareTo(b.date));
        if (widget.reminderService != null) {
          for (final event in all) {
            await widget.reminderService!.schedule(event);
          }
        }
        events = all.take(3).toList();
      } catch (_) {
        calendarError = true;
      }
    }
    if (widget.recommendationService != null) {
      try {
        NpkResult? latest;
        if (t.isNotEmpty) {
          final row = t.first;
          latest = NpkResult((row['n'] as num).toDouble(),
              (row['p'] as num).toDouble(), (row['k'] as num).toDouble(),
              unit: row['unit'] as String);
        }
        final profile = await store.profile();
        recommendations = await widget.recommendationService!
            .recommend((profile?['language'] as String?) ?? 'en', latest);
      } catch (_) {
        recommendationError = true;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => _Page(
          title: 'Good morning, Farmer',
          subtitle: 'Your farm at a glance',
          children: [
            _Card(
                icon: Icons.terrain,
                title: 'Farms & fields',
                body: farms.isEmpty
                    ? 'No farms yet. Add a farm and field to get started.'
                    : '${farms.length} farms | $fieldCount fields',
                onTap: () => _open(const FarmManagementScreen())),
            if (farms.isEmpty)
              Wrap(spacing: 10, children: [
                FilledButton.icon(
                    onPressed: () => _open(const FarmManagementScreen()),
                    icon: const Icon(Icons.add),
                    label: const AppText('Add farm')),
                OutlinedButton.icon(
                    onPressed: () => _open(const FarmManagementScreen()),
                    icon: const Icon(Icons.crop_square),
                    label: const AppText('Add field')),
              ]),
            if (tests.isEmpty)
              _Card(
                  icon: Icons.science,
                  title: 'Latest soil results',
                  body: 'Saved soil results will appear here.',
                  onTap: () => _open(const SoilScreen()))
            else
              ...tests.map((t) => _Card(
                  icon: Icons.science,
                  title:
                      '${t['field_name']} | ${DateTime.parse(t['tested_at'] as String).toLocal()}',
                  body: 'N ${t['n']} | P ${t['p']} | K ${t['k']} ${t['unit']}',
                  onTap: () => _open(FieldHistoryScreen(
                      fieldId: t['field_id'] as int,
                      fieldName: t['field_name'] as String)))),
            if (weather == null)
              _Card(
                  icon: Icons.cloud_outlined,
                  title: 'Weather',
                  body: widget.weatherService == null
                      ? 'Weather service will be connected here.'
                      : weatherError
                          ? 'Weather is unavailable right now.'
                          : 'Loading weather...',
                  onTap: () =>
                      _open(WeatherScreen(service: widget.weatherService)))
            else
              _Card(
                  icon: Icons.cloud_outlined,
                  title: 'Weather',
                  body:
                      '${weather!.description}${weather!.temperatureC == null ? '' : ' | ${weather!.temperatureC} C'}',
                  onTap: () =>
                      _open(WeatherScreen(service: widget.weatherService))),
            if (widget.recommendationService == null)
              _Card(
                  icon: Icons.eco,
                  title: 'Crop recommendations',
                  body: 'Crop recommendation service will be connected here.',
                  onTap: () => _open(CropsScreen(
                      recommendationService: widget.recommendationService,
                      calendarService: widget.calendarService,
                      reminderService: widget.reminderService)))
            else if (recommendationError)
              _Card(
                  icon: Icons.eco,
                  title: 'Crop recommendations',
                  body: 'Recommendations could not be loaded.',
                  onTap: () => _open(CropsScreen(
                      recommendationService: widget.recommendationService,
                      calendarService: widget.calendarService,
                      reminderService: widget.reminderService)))
            else
              ...recommendations.map((r) => _Card(
                  icon: Icons.eco,
                  title: 'Recommended crop: ${r.crop}',
                  body:
                      'Cost, yield, market price and potential profit are estimates.',
                  onTap: () => _open(CropsScreen(
                      recommendationService: widget.recommendationService,
                      calendarService: widget.calendarService,
                      reminderService: widget.reminderService)))),
            if (widget.calendarService == null)
              _Card(
                  icon: Icons.event,
                  title: 'Upcoming activities',
                  body: 'Calendar service will be connected here.',
                  onTap: () => _open(CalendarScreen(
                      calendarService: widget.calendarService,
                      reminderService: widget.reminderService)))
            else if (calendarError)
              _Card(
                  icon: Icons.event,
                  title: 'Upcoming activities',
                  body: 'Calendar events could not be loaded.',
                  onTap: () => _open(CalendarScreen(
                      calendarService: widget.calendarService,
                      reminderService: widget.reminderService)))
            else if (events.isEmpty)
              _Card(
                  icon: Icons.event,
                  title: 'Upcoming activities',
                  body: 'No upcoming events.',
                  onTap: () => _open(CalendarScreen(
                      calendarService: widget.calendarService,
                      reminderService: widget.reminderService)))
            else
              ...events.map((e) => _Card(
                  icon: Icons.event,
                  title: e.title,
                  body: '${e.type} | ${e.date.toLocal()}',
                  onTap: () => _open(CalendarScreen(
                      calendarService: widget.calendarService,
                      reminderService: widget.reminderService))))
          ]);
}

class WeatherScreen extends StatefulWidget {
  final WeatherService? service;
  const WeatherScreen({super.key, this.service});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  WeatherSummary? summary;
  bool loading = true;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
        failed = false;
      });
    }
    try {
      if (widget.service != null) {
        final farms = await LocalStore.instance.farms();
        final farm = farms.isEmpty ? null : farms.first;
        summary = await widget.service!
            .summary(farm?['lat'] as double?, farm?['lon'] as double?);
      }
    } catch (_) {
      failed = true;
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const AppText('Weather')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (widget.service == null)
            const _Card(
                icon: Icons.cloud_off,
                title: 'Weather service not connected',
                body:
                    'Weather data is unavailable until a weather provider is configured.')
          else if (failed || summary == null)
            const _Card(
                icon: Icons.error_outline,
                title: 'Weather unavailable',
                body:
                    'Could not load current weather. Check the provider configuration and try again.')
          else
            _Card(
                icon: Icons.cloud_outlined,
                title: summary!.description,
                body: summary!.temperatureC == null
                    ? 'Current conditions'
                    : '${summary!.temperatureC} °C'),
          OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const AppText('Refresh weather')),
        ]),
      );
}

class CalendarScreen extends StatefulWidget {
  final FarmingCalendarService? calendarService;
  final FarmingReminderService? reminderService;
  const CalendarScreen({super.key, this.calendarService, this.reminderService});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<Map<String, Object?>> farms = [];
  List<CalendarEvent> events = [];
  int? farmId;
  bool loading = true;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? selectedFarmId}) async {
    if (mounted) {
      setState(() {
        loading = true;
        failed = false;
      });
    }
    try {
      farms = await LocalStore.instance.farms();
      farmId = selectedFarmId ??
          farmId ??
          (farms.isEmpty ? null : farms.first['id'] as int);
      if (widget.calendarService != null && farmId != null) {
        events = await widget.calendarService!.events(farmId!);
        events.sort((a, b) => a.date.compareTo(b.date));
      } else {
        events = [];
      }
    } catch (_) {
      failed = true;
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const AppText('Farming calendar')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          if (farms.isNotEmpty)
            DropdownButtonFormField<int>(
              initialValue: farmId,
              decoration: InputDecoration(
                  labelText: translateAppText(context, 'Farm'),
                  border: const OutlineInputBorder()),
              items: farms
                  .map((farm) => DropdownMenuItem<int>(
                      value: farm['id'] as int,
                      child: AppText(farm['name'] as String, translate: false)))
                  .toList(),
              onChanged: (id) => id == null ? null : _load(selectedFarmId: id),
            ),
          const SizedBox(height: 16),
          if (widget.calendarService == null)
            const _Card(
                icon: Icons.calendar_month,
                title: 'Calendar service not connected',
                body:
                    'Calendar entries are unavailable until a farming calendar provider is configured.')
          else if (farms.isEmpty)
            const _Card(
                icon: Icons.agriculture,
                title: 'Add a farm first',
                body: 'Create a farm before viewing its farming activities.')
          else if (loading)
            const Center(child: CircularProgressIndicator())
          else if (failed)
            const _Card(
                icon: Icons.error_outline,
                title: 'Calendar unavailable',
                body:
                    'Could not load activities. Check the calendar provider and try again.')
          else if (events.isEmpty)
            const _Card(
                icon: Icons.event_available,
                title: 'No activities yet',
                body:
                    'No activities were returned for this farm. Sowing, irrigation, fertilizer and harvest entries will appear when supplied by the calendar integration.')
          else
            ...events.map((event) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.event),
                    title: AppText(event.title),
                    subtitle:
                        AppText('${event.type} · ${event.date.toLocal()}'),
                    trailing: widget.reminderService == null
                        ? null
                        : IconButton(
                            tooltip: translateAppText(context, 'Set reminder'),
                            icon:
                                const Icon(Icons.notifications_active_outlined),
                            onPressed: () async {
                              try {
                                await widget.reminderService!.schedule(event);
                                if (context.mounted) {
                                  _notice(context, 'Reminder scheduled.');
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  _notice(
                                      context, 'Could not schedule reminder.');
                                }
                              }
                            }),
                    onTap: () => _showCalendarEvent(
                        context, event, widget.reminderService),
                  ),
                )),
          if (widget.calendarService != null && widget.reminderService == null)
            const AppText(
                'Calendar is connected, but reminders are not configured.'),
        ]),
      );
}

Future<void> _showCalendarEvent(BuildContext context, CalendarEvent event,
    FarmingReminderService? reminders) async {
  await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
            title: AppText(event.title),
            content: AppText('${event.type}\n${event.date.toLocal()}'),
            actions: [
              if (reminders != null)
                TextButton.icon(
                    onPressed: () async {
                      try {
                        await reminders.schedule(event);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          _notice(context, 'Reminder scheduled.');
                        }
                      } catch (_) {
                        if (context.mounted) {
                          _notice(context, 'Could not schedule reminder.');
                        }
                      }
                    },
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const AppText('Set reminder')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const AppText('Close')),
            ],
          ));
}

class SoilScreen extends StatefulWidget {
  final NpkDeviceService? service;
  const SoilScreen({super.key, this.service});
  @override
  State<SoilScreen> createState() => _SoilScreenState();
}

class _SoilScreenState extends State<SoilScreen> {
  StreamSubscription<List<DeviceInfo>>? discoverySub;
  StreamSubscription<DeviceConnection>? connectionSub;
  StreamSubscription<DeviceTestEvent>? testSub;
  List<DeviceInfo> found = [];
  List<Map<String, Object?>> fields = [];
  DeviceConnection? connection;
  bool scanning = false, testing = false;
  String? statusError;
  int? fieldId;
  @override
  void initState() {
    super.initState();
    _loadFields();
    final service = widget.service;
    if (service != null) {
      discoverySub = service.discoveries.listen((v) {
        if (mounted) setState(() => found = v);
      });
      connectionSub = service.connectionEvents.listen((v) {
        if (mounted) setState(() => connection = v);
      });
      testSub = service.testEvents.listen(_testEvent);
    }
  }

  Future<void> _loadFields() async {
    final farms = await LocalStore.instance.farms();
    final result = <Map<String, Object?>>[];
    for (final farm in farms) {
      result.addAll(await LocalStore.instance.fields(farm['id'] as int));
    }
    if (mounted) setState(() => fields = result);
  }

  @override
  void dispose() {
    discoverySub?.cancel();
    connectionSub?.cancel();
    testSub?.cancel();
    super.dispose();
  }

  Future<void> _scan() async {
    final s = widget.service;
    if (s == null) {
      _notice(context,
          'The BLE adapter will be supplied by the device integration.');
      return;
    }
    setState(() {
      scanning = true;
      found = [];
      statusError = null;
    });
    try {
      await s.startDiscovery();
    } catch (e) {
      setState(() => statusError =
          'Could not scan for devices. Check Bluetooth permissions and try again.');
    }
  }

  Future<void> _connect(DeviceInfo d) async {
    final s = widget.service;
    if (s == null) return;
    try {
      if (connection?.connected ?? false) await s.disconnect();
      await s.connect(d.id);
    } catch (e) {
      if (mounted)
        setState(() => statusError =
            'Could not connect. Turn on the analyzer and keep it nearby, then retry.');
    }
  }

  Future<void> _saveDevice(DeviceInfo device) async {
    final name = TextEditingController(text: device.name);
    final save = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const AppText('Save device'),
                content: TextField(
                    controller: name,
                    decoration: InputDecoration(
                        labelText: translateAppText(context, 'Device name'))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const AppText('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const AppText('Save'))
                ]));
    if (save == true && name.text.trim().isNotEmpty) {
      await LocalStore.instance.saveDevice(device.id, name.text.trim());
      if (mounted)
        _notice(context,
            'Device saved. It will still need manual connection next time.');
    }
  }

  Future<void> _testEvent(DeviceTestEvent event) async {
    if (event is TestStarted) {
      if (mounted) setState(() => testing = true);
    }
    if (event is TestFailed) {
      if (mounted)
        setState(() {
          testing = false;
          statusError = '${event.message} ${event.correctiveStep}';
        });
    }
    if (event is TestSucceeded) {
      if (mounted) setState(() => testing = false);
      final target = fieldId;
      if (target == null) {
        if (mounted)
          _notice(context,
              'Choose a field before starting a test. This result was not saved.');
        return;
      }
      final save = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const AppText('Save soil test?'),
                  content: AppText(
                      'N ${event.result.nitrogen} · P ${event.result.phosphorus} · K ${event.result.potassium} ${event.result.unit}\n\nSave this successful result to the selected field?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const AppText('Discard')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const AppText('Save result'))
                  ]));
      if (save == true)
        await LocalStore.instance.saveTest(
            fieldId: target,
            n: event.result.nitrogen,
            p: event.result.phosphorus,
            k: event.result.potassium,
            unit: event.result.unit);
      if (mounted) setState(() => statusError = null);
    }
  }

  @override
  Widget build(BuildContext context) => _Page(
        title: 'Soil testing',
        subtitle: 'Connect your analyzer and test a field',
        children: [
          DropdownButtonFormField<int>(
            initialValue: fieldId,
            decoration: InputDecoration(
              labelText: translateAppText(context, 'Test field'),
              border: OutlineInputBorder(),
            ),
            items: fields
                .map((f) => DropdownMenuItem(
                      value: f['id'] as int,
                      child: AppText(f['name'] as String, translate: false),
                    ))
                .toList(),
            onChanged: (id) => setState(() => fieldId = id),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: scanning ? null : _scan,
            icon: const Icon(Icons.bluetooth_searching),
            label: AppText(scanning ? 'Searching…' : 'Find NPK device'),
          ),
          if (scanning)
            TextButton(
              onPressed: () async {
                await widget.service?.stopDiscovery();
                if (mounted) setState(() => scanning = false);
              },
              child: const AppText('Stop search'),
            ),
          if (found.isNotEmpty)
            Card(
              child: Column(
                children: found
                    .map(
                      (d) => ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: d.name.isEmpty
                            ? const AppText('NPK device')
                            : AppText(d.name, translate: false),
                        subtitle: AppText(d.id, translate: false),
                        trailing: Wrap(
                          children: [
                            TextButton(
                              onPressed: () => _connect(d),
                              child: const AppText('Connect'),
                            ),
                            IconButton(
                              tooltip:
                                  translateAppText(context, 'Save device name'),
                              onPressed: () => _saveDevice(d),
                              icon: const Icon(Icons.bookmark_add_outlined),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (connection?.connected ?? false)
            Card(
              child: ListTile(
                leading: const Icon(Icons.sensors),
                title: const AppText('Device connected'),
                subtitle: AppText(
                  connection?.batteryPercent == null
                      ? 'Ready to test'
                      : 'Battery ${connection!.batteryPercent}%',
                ),
                trailing: TextButton(
                  onPressed: () => widget.service?.disconnect(),
                  child: const AppText('Disconnect'),
                ),
              ),
            ),
          if (connection?.error != null || statusError != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: const AppText('Connection or test issue'),
                subtitle: AppText(statusError ?? connection!.error!),
              ),
            ),
          FilledButton.icon(
            onPressed: widget.service == null ||
                    !(connection?.connected ?? false) ||
                    fieldId == null ||
                    testing
                ? null
                : () async {
                    setState(() => statusError = null);
                    try {
                      await widget.service!.startTest();
                    } catch (e) {
                      setState(
                        () => statusError =
                            'Test could not start. Check the sample, device connection and battery, then try again.',
                      );
                    }
                  },
            icon: testing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label:
                AppText(testing ? 'Testing in progress.' : 'Start soil test'),
          ),
          if (fields.isEmpty)
            _Card(
              icon: Icons.crop_square,
              title: 'Add a field first',
              body:
                  'Create a farm and field in Profile before saving soil test results.',
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const FarmManagementScreen()));
                if (mounted) _loadFields();
              },
            ),
          _Card(
            icon: Icons.history,
            title: 'Field history',
            body: fieldId == null
                ? 'Select a field to view its saved soil history.'
                : 'Successful tests are saved only after you choose Save result.',
            onTap: fieldId == null
                ? () => _notice(context, 'Select a field to view soil history.')
                : () {
                    final field = fields.firstWhere(
                        (entry) => entry['id'] == fieldId,
                        orElse: () => <String, Object?>{});
                    if (field.isEmpty) return;
                    Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => FieldHistoryScreen(
                            fieldId: fieldId!,
                            fieldName: field['name'] as String)));
                  },
          ),
          if (fieldId == null)
            Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => const FarmManagementScreen()));
                      if (mounted) _loadFields();
                    },
                    icon: const Icon(Icons.add),
                    label: const AppText('Add a field to view history'))),
        ],
      );
}

class CropsScreen extends StatefulWidget {
  final CropRecommendationService? recommendationService;
  final FarmingCalendarService? calendarService;
  final FarmingReminderService? reminderService;
  const CropsScreen(
      {super.key,
      this.recommendationService,
      this.calendarService,
      this.reminderService});
  @override
  State<CropsScreen> createState() => _CropsScreenState();
}

class _CropsScreenState extends State<CropsScreen> {
  static const cropOptions = [
    'Rice',
    'Maize',
    'Groundnut',
    'Cotton',
    'Sugarcane',
    'Millet',
    'Tomato',
    'Banana',
    'Pulses'
  ];
  List<Map<String, Object?>> farms = [], selected = [];
  List<CropEstimate> estimates = [];
  List<CalendarEvent> events = [];
  int? farmId;
  bool recommendationError = false, calendarError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = LocalStore.instance;
    final farmRows = await store.farms();
    final selectedId =
        farmId ?? (farmRows.isEmpty ? null : farmRows.first['id'] as int);
    final cropRows = selectedId == null
        ? <Map<String, Object?>>[]
        : await store.crops(selectedId);
    List<CropEstimate> recs = [];
    List<CalendarEvent> calendarEvents = [];
    var recFailed = false, calendarFailed = false;
    if (selectedId != null && widget.recommendationService != null) {
      try {
        NpkResult? soil;
        for (final field in await store.fields(selectedId)) {
          final history = await store.testHistory(field['id'] as int);
          if (history.isNotEmpty) {
            final row = history.first;
            soil = NpkResult((row['n'] as num).toDouble(),
                (row['p'] as num).toDouble(), (row['k'] as num).toDouble(),
                unit: row['unit'] as String);
            break;
          }
        }
        final profile = await store.profile();
        recs = await widget.recommendationService!
            .recommend((profile?['language'] as String?) ?? 'en', soil);
      } catch (_) {
        recFailed = true;
      }
    }
    if (selectedId != null && widget.calendarService != null) {
      try {
        calendarEvents = await widget.calendarService!.events(selectedId);
        calendarEvents.sort((a, b) => a.date.compareTo(b.date));
        if (widget.reminderService != null) {
          for (final event in calendarEvents) {
            await widget.reminderService!.schedule(event);
          }
        }
      } catch (_) {
        calendarFailed = true;
      }
    }
    if (mounted)
      setState(() {
        farms = farmRows;
        farmId = selectedId;
        selected = cropRows;
        estimates = recs;
        events = calendarEvents;
        recommendationError = recFailed;
        calendarError = calendarFailed;
      });
  }

  Widget _estimateTile(CropEstimate estimate) => Card(
          child: ListTile(
        leading: const Icon(Icons.eco),
        title: AppText(estimate.crop),
        isThreeLine: true,
        subtitle: AppText(
            'Estimates only, not guarantees. Cost: ${estimate.currency} ${estimate.cost ?? 'unavailable'} · Yield: ${estimate.yieldAmount ?? 'unavailable'} ${estimate.yieldUnit} · Market price: ${estimate.marketPrice ?? 'unavailable'} ${estimate.priceUnit} · Potential profit: ${estimate.currency} ${estimate.potentialProfit ?? 'unavailable'}'),
        onTap: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: AppText(estimate.crop),
                  content: AppText(
                      'Estimates only, not guarantees. Cost: ${estimate.currency} ${estimate.cost ?? 'unavailable'} · Yield: ${estimate.yieldAmount ?? 'unavailable'} ${estimate.yieldUnit} · Market price: ${estimate.marketPrice ?? 'unavailable'} ${estimate.priceUnit} · Potential profit: ${estimate.currency} ${estimate.potentialProfit ?? 'unavailable'}'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const AppText('Close'))
                  ],
                )),
      ));

  @override
  Widget build(BuildContext context) => _Page(
          title: 'Crops & calendar',
          subtitle: 'Plan your next season',
          children: [
            if (farms.isEmpty)
              _Card(
                  icon: Icons.agriculture,
                  title: 'Add a farm first',
                  body: 'Create a farm in Profile to save crop selections.',
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => const FarmManagementScreen()));
                    if (mounted) _load();
                  })
            else
              DropdownButtonFormField<int>(
                  initialValue: farmId,
                  decoration: InputDecoration(
                      labelText: translateAppText(context, 'Farm'),
                      border: const OutlineInputBorder()),
                  items: farms
                      .map((f) => DropdownMenuItem(
                          value: f['id'] as int,
                          child:
                              AppText(f['name'] as String, translate: false)))
                      .toList(),
                  onChanged: (id) async {
                    farmId = id;
                    await _load();
                  }),
            if (farmId != null)
              Card(
                  child: Column(children: [
                ListTile(
                    title: const AppText('Selected crops'),
                    trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.add),
                        onSelected: (crop) async {
                          await LocalStore.instance.addCrop(farmId!, crop);
                          await _load();
                        },
                        itemBuilder: (_) => cropOptions
                            .map((c) =>
                                PopupMenuItem(value: c, child: AppText(c)))
                            .toList())),
                if (selected.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: AppText('Choose crops for this farm.')),
                ...selected.map((c) => ListTile(
                    leading: const Icon(Icons.eco),
                    title: AppText(c['crop'] as String),
                    trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          await LocalStore.instance.removeCrop(c['id'] as int);
                          await _load();
                        }))),
              ])),
            if (widget.recommendationService == null)
              const _Card(
                  icon: Icons.lightbulb_outline,
                  title: 'Crop recommendations',
                  body: 'Recommendation service is not connected yet.')
            else if (recommendationError)
              _Card(
                  icon: Icons.lightbulb_outline,
                  title: 'Crop recommendations',
                  body: 'Recommendations could not be loaded. Try again later.',
                  onTap: _load)
            else if (estimates.isEmpty)
              _Card(
                  icon: Icons.lightbulb_outline,
                  title: 'Crop recommendations',
                  body: 'No recommendations are available yet.',
                  onTap: _load)
            else
              ...estimates.map(_estimateTile),
            if (widget.calendarService == null)
              _Card(
                  icon: Icons.calendar_month,
                  title: 'Farming calendar',
                  body: 'Calendar service is not connected yet.',
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => CalendarScreen(
                              calendarService: widget.calendarService,
                              reminderService: widget.reminderService))))
            else if (calendarError)
              _Card(
                  icon: Icons.calendar_month,
                  title: 'Farming calendar',
                  body: 'Calendar events could not be loaded.',
                  onTap: _load)
            else if (events.isEmpty)
              _Card(
                  icon: Icons.calendar_month,
                  title: 'Farming calendar',
                  body: 'No upcoming events for this farm.',
                  onTap: () => Navigator.of(context)
                      .push(
                          MaterialPageRoute<void>(
                              builder: (_) => CalendarScreen(
                                  calendarService: widget.calendarService,
                                  reminderService: widget.reminderService))))
            else
              ...events.map((event) => _Card(
                  icon: Icons.event,
                  title: event.title,
                  body: '${event.type} · ${event.date.toLocal()}',
                  onTap: () => _showCalendarEvent(
                      context, event, widget.reminderService))),
          ]);
}

class _ChatItem {
  final bool farmer;
  final AssistantReply? reply;
  final String question;
  const _ChatItem.question(this.question)
      : farmer = true,
        reply = null;
  const _ChatItem.answer(AssistantReply value)
      : farmer = false,
        reply = value,
        question = '';
}

class AssistantScreen extends StatefulWidget {
  final AiAssistantService? service;
  const AssistantScreen({super.key, this.service});
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final controller = TextEditingController();
  final speech = stt.SpeechToText();
  final tts = FlutterTts();
  final messages = <_ChatItem>[];
  bool sending = false, listening = false;
  String? lastQuestion;

  Future<String> _language() async {
    final profile = await LocalStore.instance.profile();
    return (profile?['language'] as String?) ?? 'en';
  }

  Future<void> _ask() async {
    final question = controller.text.trim();
    final service = widget.service;
    if (question.isEmpty || service == null || sending) return;
    controller.clear();
    setState(() {
      messages.add(_ChatItem.question(question));
      sending = true;
      lastQuestion = question;
    });
    try {
      final language = await _language();
      AssistantReply? latest;
      await for (final reply in service.ask(question, language)) {
        latest = reply;
      }
      final answer = latest;
      if (answer == null) throw StateError('Assistant returned no response');
      if (mounted) setState(() => messages.add(_ChatItem.answer(answer)));
      await tts.setLanguage(language == 'ta' ? 'ta-IN' : 'en-US');
      await tts.speak(answer.text);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: AppText(
                'The assistant could not answer right now. You can contact an agricultural expert.')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _listen() async {
    try {
      final available = await speech.initialize();
      if (!available) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: AppText('Speech input is unavailable on this device.')));
        return;
      }
      final language = await _language();
      setState(() => listening = true);
      await speech.listen(
          listenOptions: stt.SpeechListenOptions(
              localeId: language == 'ta' ? 'ta_IN' : 'en_IN'),
          onResult: (result) {
            controller.text = result.recognizedWords;
          });
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: AppText('Could not start speech input.')));
    }
  }

  Future<void> _stopListening() async {
    await speech.stop();
    if (mounted) setState(() => listening = false);
  }

  Future<void> _contactExpert() async {
    final question = lastQuestion;
    final service = widget.service;
    if (question == null || service == null) return;
    try {
      await service.contactExpert(question);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: AppText('Your request was sent to the expert service.')));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: AppText('Expert contact is unavailable right now.')));
    }
  }

  Widget _message(_ChatItem item) {
    if (item.farmer) {
      return Align(
          alignment: Alignment.centerRight,
          child: Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: AppText(item.question, translate: false)),
          ));
    }
    final reply = item.reply!;
    return Align(
        alignment: Alignment.centerLeft,
        child: Card(
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(reply.text, translate: false),
                  if (reply.sources.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: AppText('Sources: ${reply.sources.join(' | ')}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                ],
              )),
        ));
  }

  @override
  void dispose() {
    controller.dispose();
    speech.stop();
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText('AI Assistant',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const AppText('Ask a question in English or Tamil'),
                    ]),
              )),
          if (widget.service == null)
            const Card(
                margin: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: ListTile(
                  leading: Icon(Icons.cloud_off),
                  title: AppText('AI service not connected'),
                  subtitle: AppText(
                      'Configure an AiAssistantService backend to send questions. No sample answers are generated.'),
                )),
          Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: AppText(widget.service == null
                          ? 'Ask a farming question to get started.'
                          : 'Ask a farming question to get started.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (_, index) => _message(messages[index]))),
          if (lastQuestion != null)
            TextButton.icon(
              onPressed: widget.service == null ? null : _contactExpert,
              icon: const Icon(Icons.support_agent),
              label: const AppText('Contact an agricultural expert'),
            ),
          if (sending) const LinearProgressIndicator(),
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                    child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: translateAppText(
                                context, 'Type your question')))),
                IconButton(
                    onPressed: widget.service == null
                        ? null
                        : (listening ? _stopListening : _listen),
                    icon: Icon(listening ? Icons.mic : Icons.mic_none),
                    tooltip: translateAppText(context, 'Speak your question')),
                IconButton.filled(
                    onPressed: widget.service == null || sending ? null : _ask,
                    icon: const Icon(Icons.send),
                    tooltip: translateAppText(context, 'Ask')),
              ])),
        ])),
      );
}

class ProfileScreen extends StatefulWidget {
  final bool calendarConnected;
  final bool remindersConnected;
  final FarmingCalendarService? calendarService;
  final FarmingReminderService? reminderService;
  const ProfileScreen({
    super.key,
    this.calendarConnected = false,
    this.remindersConnected = false,
    this.calendarService,
    this.reminderService,
  });
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String language = 'en';
  String? farmerName;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await LocalStore.instance.profile();
    if (mounted)
      setState(() {
        language = (p?['language'] as String?) ?? 'en';
        farmerName = p?['name'] as String?;
      });
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: farmerName ?? '');
    final save = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const AppText('Farmer name'),
                content: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                        labelText: translateAppText(ctx, 'Optional name'))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const AppText('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const AppText('Save'))
                ]));
    if (save == true) {
      final trimmed = controller.text.trim();
      await LocalStore.instance
          .setProfileName(trimmed.isEmpty ? null : trimmed);
      if (mounted)
        setState(() => farmerName = trimmed.isEmpty ? null : trimmed);
    }
  }

  Future<void> _selectLanguage(String value) async {
    final previous = language;
    setState(() => language = value);
    AppLanguage.select(value);
    try {
      await LocalStore.instance.setLanguage(value);
    } catch (_) {
      AppLanguage.select(previous);
      if (mounted) {
        setState(() => language = previous);
        _notice(context, 'Could not save language preference.');
      }
    }
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) => _Page(
          title: 'Profile & settings',
          subtitle: 'Your information stays on this device',
          children: [
            Card(
                child: ListTile(
                    leading:
                        const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: AppText(farmerName ?? 'Guest farmer',
                        translate: farmerName == null),
                    subtitle: const AppText('Optional name'),
                    trailing: const Icon(Icons.edit),
                    onTap: _editName)),
            Card(
                child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.language)),
                    title: const AppText('Language'),
                    subtitle: DropdownButton<String>(
                        value: language,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                              value: 'en',
                              child: AppText('English', translate: false)),
                          DropdownMenuItem(
                              value: 'ta',
                              child: AppText('தமிழ்', translate: false))
                        ],
                        onChanged: (value) {
                          if (value != null) _selectLanguage(value);
                        }))),
            Card(
                child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.agriculture)),
                    title: const AppText('Farm management'),
                    subtitle:
                        const AppText('Manage farms, fields and locations'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(const FarmManagementScreen()))),
            Card(
                child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.bluetooth)),
                    title: const AppText('Saved devices'),
                    subtitle:
                        const AppText('Saved names for your analyzer devices'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(const SavedDevicesScreen()))),
            Card(
                child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.storage)),
                    title: const AppText('Local data'),
                    subtitle:
                        const AppText('Delete all locally stored farm data'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(const LocalDataScreen()))),
            Card(
                child: ListTile(
                    leading: const CircleAvatar(
                        child: Icon(Icons.notifications_none)),
                    title: const AppText('Notifications'),
                    subtitle: const AppText(
                        'Calendar reminders will be enabled when the calendar integration is connected.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(NotificationsScreen(
                        calendarConnected: widget.calendarConnected,
                        remindersConnected: widget.remindersConnected,
                        calendarService: widget.calendarService,
                        reminderService: widget.reminderService))))
          ]);
}

class NotificationsScreen extends StatelessWidget {
  final bool calendarConnected;
  final bool remindersConnected;
  final FarmingCalendarService? calendarService;
  final FarmingReminderService? reminderService;

  const NotificationsScreen({
    super.key,
    required this.calendarConnected,
    required this.remindersConnected,
    this.calendarService,
    this.reminderService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('Notification settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: Icon(calendarConnected
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined),
              title: const AppText('Calendar integration'),
              subtitle:
                  AppText(calendarConnected ? 'Connected' : 'Not connected'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(remindersConnected
                  ? Icons.notifications_active
                  : Icons.notifications_off),
              title: const AppText('Farming reminders'),
              subtitle:
                  AppText(remindersConnected ? 'Connected' : 'Not connected'),
            ),
          ),
          AppText(calendarConnected && remindersConnected
              ? 'Reminders can be scheduled for events supplied by your calendar integration.'
              : 'Calendar entries and reminders require integrations configured by the app provider. No calendar is connected.'),
          if (calendarConnected)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => CalendarScreen(
                            calendarService: calendarService,
                            reminderService: reminderService))),
                icon: const Icon(Icons.calendar_month),
                label: const AppText('Open farming calendar'),
              ),
            ),
        ],
      ),
    );
  }
}

class FarmManagementScreen extends StatefulWidget {
  const FarmManagementScreen({super.key});
  @override
  State<FarmManagementScreen> createState() => _FarmManagementScreenState();
}

class _FarmManagementScreenState extends State<FarmManagementScreen> {
  List<Map<String, Object?>> farms = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => loading = true);
    final rows = await LocalStore.instance.farms();
    if (mounted)
      setState(() {
        farms = rows;
        loading = false;
      });
  }

  Future<void> _editFarm([Map<String, Object?>? farm]) async {
    final name = TextEditingController(text: (farm?['name'] as String?) ?? '');
    final location =
        TextEditingController(text: (farm?['location'] as String?) ?? '');
    double? lat = farm?['lat'] as double?, lon = farm?['lon'] as double?;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: AppText(farm == null ? 'Add farm' : 'Edit farm'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: name,
                      decoration: InputDecoration(
                          labelText: translateAppText(ctx, 'Farm name *'))),
                  TextField(
                      controller: location,
                      decoration: InputDecoration(
                          labelText:
                              translateAppText(ctx, 'Location (optional)'))),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                          onPressed: () async {
                            try {
                              var permission =
                                  await Geolocator.checkPermission();
                              if (permission == LocationPermission.denied)
                                permission =
                                    await Geolocator.requestPermission();
                              if (permission == LocationPermission.denied ||
                                  permission ==
                                      LocationPermission.deniedForever) {
                                if (ctx.mounted)
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content: AppText(
                                              'Location permission was not granted. You can enter the location manually.')));
                                return;
                              }
                              final position =
                                  await Geolocator.getCurrentPosition();
                              lat = position.latitude;
                              lon = position.longitude;
                              location.text = 'GPS location';
                              if (ctx.mounted)
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content:
                                            AppText('GPS location captured.')));
                            } catch (_) {
                              if (ctx.mounted)
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content: AppText(
                                            'Could not get GPS location. Enter the location manually.')));
                            }
                          },
                          icon: const Icon(Icons.my_location),
                          label: const AppText('Use current location')))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const AppText('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const AppText('Save'))
                ]));
    if (ok == true && name.text.trim().isNotEmpty) {
      await LocalStore.instance.saveFarm(
          id: farm?['id'] as int?,
          name: name.text.trim(),
          location: location.text.trim(),
          lat: lat,
          lon: lon);
      await _refresh();
    }
  }

  Future<void> _deleteFarm(int id) async {
    final yes = await _confirm(
        context, 'Delete this farm and all its fields and soil history?');
    if (yes) {
      final store = LocalStore.instance;
      final rows = <Map<String, Object?>>[];
      rows.addAll(await store.photos('farm', id));
      for (final field in await store.fields(id)) {
        rows.addAll(await store.photos('field', field['id'] as int));
      }
      await store.deleteFarm(id);
      final media = FarmMediaService();
      for (final photo in rows) {
        await media.deletePhotoFile(photo['path'] as String);
      }
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const AppText('Farm management'), actions: [
        IconButton(
            onPressed: () => _editFarm(),
            icon: const Icon(Icons.add),
            tooltip: translateAppText(context, 'Add farm'))
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : farms.isEmpty
              ? const Center(
                  child: AppText('No farms yet. Add your first farm.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: farms.length,
                  itemBuilder: (ctx, i) {
                    final farm = farms[i];
                    final id = farm['id'] as int;
                    return Card(
                        child: ExpansionTile(
                            title: AppText(farm['name'] as String,
                                translate: false),
                            subtitle: (farm['location'] as String).isEmpty
                                ? const AppText('Location not set')
                                : AppText(farm['location'] as String,
                                    translate: false),
                            children: [
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Wrap(spacing: 4, children: [
                                TextButton.icon(
                                    onPressed: () => _editFarm(farm),
                                    icon: const Icon(Icons.edit),
                                    label: const AppText('Edit')),
                                TextButton.icon(
                                    onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => FarmPhotosScreen(
                                                ownerType: 'farm',
                                                ownerId: id,
                                                title:
                                                    '${farm['name']} photos'))),
                                    icon: const Icon(
                                        Icons.photo_library_outlined),
                                    label: const AppText('Photos')),
                                TextButton.icon(
                                    onPressed: () => _addField(id),
                                    icon: const Icon(Icons.add),
                                    label: const AppText('Add field')),
                                TextButton.icon(
                                    onPressed: () => _deleteFarm(id),
                                    icon: const Icon(Icons.delete_outline),
                                    label: const AppText('Delete'))
                              ])),
                          FutureBuilder<List<Map<String, Object?>>>(
                              future: LocalStore.instance.fields(id),
                              builder: (ctx, snapshot) {
                                final fields = snapshot.data ?? [];
                                if (fields.isEmpty)
                                  return const ListTile(
                                      title: AppText('No fields yet'));
                                return Column(
                                    children: fields
                                        .map((f) => ListTile(
                                            onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        FieldHistoryScreen(
                                                            fieldId:
                                                                f['id'] as int,
                                                            fieldName: f['name']
                                                                as String))),
                                            leading:
                                                const Icon(Icons.crop_square),
                                            title: AppText(f['name'] as String,
                                                translate: false),
                                            subtitle: AppText((f['area']
                                                        as String)
                                                    .isEmpty
                                                ? 'Area not set | Tap to view soil history'
                                                : '${f['area']} | Tap to view soil history'),
                                            trailing: Wrap(children: [
                                              IconButton(
                                                  tooltip: translateAppText(
                                                      context, 'Edit field'),
                                                  icon: const Icon(Icons.edit),
                                                  onPressed: () =>
                                                      _addField(id, f)),
                                              IconButton(
                                                  tooltip: translateAppText(
                                                      context, 'Field photos'),
                                                  icon: const Icon(Icons
                                                      .photo_library_outlined),
                                                  onPressed: () => Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (_) =>
                                                              FarmPhotosScreen(
                                                                  ownerType:
                                                                      'field',
                                                                  ownerId: f[
                                                                          'id']
                                                                      as int,
                                                                  title:
                                                                      '${f['name']} photos')))),
                                              IconButton(
                                                  tooltip: translateAppText(
                                                      context, 'Delete field'),
                                                  icon: const Icon(
                                                      Icons.delete_outline),
                                                  onPressed: () => _deleteField(
                                                      f['id'] as int))
                                            ])))
                                        .toList());
                              })
                        ]));
                  }));
  Future<void> _addField(int farmId, [Map<String, Object?>? field]) async {
    final name = TextEditingController(text: (field?['name'] as String?) ?? ''),
        area = TextEditingController(text: (field?['area'] as String?) ?? '');
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: AppText(field == null ? 'Add field' : 'Edit field'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: name,
                      decoration: InputDecoration(
                          labelText: translateAppText(ctx, 'Field name *'))),
                  TextField(
                      controller: area,
                      decoration: InputDecoration(
                          labelText: translateAppText(ctx, 'Area (optional)')))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const AppText('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const AppText('Save'))
                ]));
    if (ok == true && name.text.trim().isNotEmpty) {
      await LocalStore.instance.saveField(
          id: field?['id'] as int?,
          farmId: farmId,
          name: name.text.trim(),
          area: area.text.trim());
      await _refresh();
    }
  }

  Future<void> _deleteField(int id) async {
    final yes =
        await _confirm(context, 'Delete this field and its soil-test history?');
    if (yes) {
      final store = LocalStore.instance;
      final photos = await store.photos('field', id);
      await store.deleteField(id);
      final media = FarmMediaService();
      for (final photo in photos) {
        await media.deletePhotoFile(photo['path'] as String);
      }
      await _refresh();
    }
  }
}

class FarmPhotosScreen extends StatefulWidget {
  final String ownerType, title;
  final int ownerId;
  const FarmPhotosScreen(
      {super.key,
      required this.ownerType,
      required this.ownerId,
      required this.title});
  @override
  State<FarmPhotosScreen> createState() => _FarmPhotosScreenState();
}

class _FarmPhotosScreenState extends State<FarmPhotosScreen> {
  final media = FarmMediaService();
  List<Map<String, Object?>> photos = [];
  bool loading = true, saving = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows =
        await LocalStore.instance.photos(widget.ownerType, widget.ownerId);
    if (mounted)
      setState(() {
        photos = rows;
        loading = false;
      });
  }

  Future<void> _add() async {
    setState(() => saving = true);
    try {
      final paths = await media.pickCompressedPhotos();
      for (final path in paths) {
        await LocalStore.instance
            .addPhoto(widget.ownerType, widget.ownerId, path);
      }
      await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: AppText(
                'Could not add photos. Check photo library access and available storage.')));
    }
    if (mounted) setState(() => saving = false);
  }

  Future<void> _delete(Map<String, Object?> photo) async {
    if (!await _confirm(context, 'Delete this photo?')) return;
    final path = photo['path'] as String;
    await LocalStore.instance.deletePhoto(photo['id'] as int);
    await media.deletePhotoFile(path);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: AppText(widget.title), actions: [
        IconButton(
            onPressed: saving ? null : _add,
            icon: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_photo_alternate_outlined),
            tooltip: translateAppText(context, 'Add photos'))
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : photos.isEmpty
              ? const Center(
                  child: AppText('No photos yet. Add photos from your device.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10),
                  itemCount: photos.length,
                  itemBuilder: (ctx, i) {
                    final photo = photos[i];
                    return Stack(fit: StackFit.expand, children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(File(photo['path'] as String),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const ColoredBox(
                                  color: Color(0xffe7ece6),
                                  child: Icon(Icons.broken_image)))),
                      Positioned(
                          right: 4,
                          top: 4,
                          child: IconButton.filledTonal(
                              onPressed: () => _delete(photo),
                              icon: const Icon(Icons.delete_outline),
                              tooltip:
                                  translateAppText(context, 'Delete photo')))
                    ]);
                  }));
}

class SavedDevicesScreen extends StatefulWidget {
  const SavedDevicesScreen({super.key});
  @override
  State<SavedDevicesScreen> createState() => _SavedDevicesScreenState();
}

class _SavedDevicesScreenState extends State<SavedDevicesScreen> {
  List<Map<String, Object?>> devices = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await LocalStore.instance.devices();
    if (mounted)
      setState(() {
        devices = rows;
        loading = false;
      });
  }

  Future<void> _delete(String id) async {
    if (!await _confirm(context, 'Remove this saved device?')) return;
    await LocalStore.instance.deleteDevice(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const AppText('Saved devices')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : devices.isEmpty
              ? const Center(
                  child: AppText(
                      'No saved devices yet. Save one when it is discovered.'))
              : ListView(
                  children: devices
                      .map((d) => ListTile(
                          leading: const Icon(Icons.bluetooth),
                          title: AppText(d['name'] as String, translate: false),
                          subtitle:
                              AppText(d['id'] as String, translate: false),
                          trailing: IconButton(
                              tooltip: translateAppText(
                                  context, 'Remove saved device'),
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(d['id'] as String))))
                      .toList()));
}

class LocalDataScreen extends StatefulWidget {
  const LocalDataScreen({super.key});
  @override
  State<LocalDataScreen> createState() => _LocalDataScreenState();
}

class _LocalDataScreenState extends State<LocalDataScreen> {
  bool clearing = false;
  Future<void> _clear() async {
    if (!await _confirm(context,
        'Delete all farms, fields, photos, saved devices, crop selections and soil-test history from this device? This cannot be undone.'))
      return;
    setState(() => clearing = true);
    final store = LocalStore.instance;
    final photos = await store.allPhotos();
    final media = FarmMediaService();
    for (final photo in photos) {
      await media.deletePhotoFile(photo['path'] as String);
    }
    await store.clearFarmerData();
    if (mounted) setState(() => clearing = false);
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('Local farm data deleted.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const AppText('Local data')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const AppText(
            'Farm records, photos, crop selections, saved devices and soil history are stored only on this device.'),
        const SizedBox(height: 20),
        FilledButton.tonalIcon(
            onPressed: clearing ? null : _clear,
            icon: const Icon(Icons.delete_forever_outlined),
            label:
                AppText(clearing ? 'Deleting…' : 'Delete all local farm data'))
      ]));
}

Future<bool> _confirm(BuildContext context, String message) async =>
    await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(content: AppText(message), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const AppText('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const AppText('Delete'))
            ])) ??
    false;

class FieldHistoryScreen extends StatefulWidget {
  final int fieldId;
  final String fieldName;
  const FieldHistoryScreen(
      {super.key, required this.fieldId, required this.fieldName});
  @override
  State<FieldHistoryScreen> createState() => _FieldHistoryScreenState();
}

class _FieldHistoryScreenState extends State<FieldHistoryScreen> {
  List<Map<String, Object?>> tests = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await LocalStore.instance.testHistory(widget.fieldId);
    rows.sort((a, b) => DateTime.parse(a['tested_at'] as String)
        .compareTo(DateTime.parse(b['tested_at'] as String)));
    if (mounted)
      setState(() {
        tests = rows;
        loading = false;
      });
  }

  Future<void> _note(Map<String, Object?> test) async {
    final controller = TextEditingController(text: test['note'] as String);
    final id = test['id'] as int;
    final favorite = (test['favorite'] as int) == 1;
    final save = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const AppText('Test note'),
                content: TextField(
                    controller: controller,
                    maxLines: 4,
                    decoration: InputDecoration(
                        hintText: translateAppText(ctx, 'Optional note'))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const AppText('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const AppText('Save'))
                ]));
    if (save == true) {
      await LocalStore.instance
          .updateTest(id, note: controller.text.trim(), favorite: favorite);
      await _load();
    }
  }

  Future<void> _delete(int id) async {
    if (await _confirm(context, 'Delete this soil-test record?')) {
      await LocalStore.instance.deleteTest(id);
      await _load();
    }
  }

  Future<void> _favorite(Map<String, Object?> test) async {
    await LocalStore.instance.updateTest(test['id'] as int,
        note: test['note'] as String, favorite: (test['favorite'] as int) != 1);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: AppText('${widget.fieldName} history')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : tests.isEmpty
              ? const Center(
                  child: AppText('No saved tests for this field yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tests.length,
                  itemBuilder: (ctx, i) {
                    final t = tests[i];
                    final date =
                        DateTime.parse(t['tested_at'] as String).toLocal();
                    return Card(
                        child: ListTile(
                            isThreeLine: true,
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => SoilResultDetailsScreen(
                                        fieldName: widget.fieldName, test: t))),
                            title: AppText(
                                '${date.toString().substring(0, 16)} · N ${t['n']}  P ${t['p']}  K ${t['k']} ${t['unit']}'),
                            subtitle: (t['note'] as String).isEmpty
                                ? const AppText('No note')
                                : AppText(t['note'] as String,
                                    translate: false),
                            leading: Icon((t['favorite'] as int) == 1
                                ? Icons.star
                                : Icons.science_outlined),
                            trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'note') _note(t);
                                  if (v == 'favorite') _favorite(t);
                                  if (v == 'delete') _delete(t['id'] as int);
                                },
                                itemBuilder: (_) => [
                                      const PopupMenuItem(
                                          value: 'note',
                                          child: AppText('Edit note')),
                                      PopupMenuItem(
                                          value: 'favorite',
                                          child: AppText(
                                              (t['favorite'] as int) == 1
                                                  ? 'Remove favorite'
                                                  : 'Favorite')),
                                      const PopupMenuItem(
                                          value: 'delete',
                                          child: AppText('Delete test'))
                                    ])));
                  }));
}

class SoilResultDetailsScreen extends StatelessWidget {
  final String fieldName;
  final Map<String, Object?> test;
  const SoilResultDetailsScreen(
      {super.key, required this.fieldName, required this.test});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(test['tested_at'] as String).toLocal();
    return Scaffold(
      appBar: AppBar(title: const AppText('Soil result details')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(fieldName, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        AppText(date.toString().substring(0, 16)),
        const SizedBox(height: 16),
        Card(
            child: Column(children: [
          _resultValue(context, 'Nitrogen (N)', test['n'], test['unit']),
          const Divider(height: 1),
          _resultValue(context, 'Phosphorus (P)', test['p'], test['unit']),
          const Divider(height: 1),
          _resultValue(context, 'Potassium (K)', test['k'], test['unit']),
        ])),
        const SizedBox(height: 8),
        ListTile(
          leading: Icon((test['favorite'] as int) == 1
              ? Icons.star
              : Icons.check_circle_outline),
          title: const AppText('Saved result'),
          subtitle: AppText((test['favorite'] as int) == 1
              ? 'Favorite result'
              : 'Stored on this device'),
        ),
        ListTile(
          leading: const Icon(Icons.notes),
          title: const AppText('Test note'),
          subtitle: AppText(
              (test['note'] as String).isEmpty
                  ? 'No note'
                  : test['note'] as String,
              translate: (test['note'] as String).isEmpty),
        )
      ]),
    );
  }

  Widget _resultValue(
      BuildContext context, String label, Object? amount, Object? unit) {
    final numeric = (amount as num).toDouble();
    return ListTile(
      title: AppText(label),
      trailing: Text('${numeric.toStringAsFixed(1)} $unit',
          style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _Page extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children;
  const _Page(
      {required this.title, required this.subtitle, required this.children});
  @override
  Widget build(BuildContext context) => SafeArea(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
            AppText(localizedPageText(context, title),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            AppText(localizedPageText(context, subtitle),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.black54)),
            const SizedBox(height: 20),
            ...children
          ]));
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final VoidCallback? onTap;
  const _Card({
    required this.icon,
    required this.title,
    required this.body,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
          isThreeLine: true,
          leading: CircleAvatar(child: Icon(icon)),
          title: AppText(title),
          subtitle: AppText(body),
          onTap: onTap,
          trailing: onTap == null ? null : const Icon(Icons.chevron_right)));
}

void _notice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(message)));
