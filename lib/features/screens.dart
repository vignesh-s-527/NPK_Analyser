import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import '../app/app_language.dart';
import '../app/ferta_components.dart';
import '../app/ferta_theme.dart';
import '../data/local_store.dart';
import '../models/domain.dart';
import '../services/contracts.dart';
import '../services/farm_media_service.dart';

class HomeScreen extends StatefulWidget {
  final WeatherService? weatherService;
  final FarmingCalendarService? calendarService;
  final CropRecommendationService? recommendationService;
  final FarmingReminderService? reminderService;
  final NpkDeviceService? npkDevice;
  final ReadingSubmissionService? readingSubmission;
  final FertilizerAdviceService? fertilizerAdviceService;
  final AiAssistantService? assistantService;
  final ValueChanged<int>? onNavigate;
  const HomeScreen(
      {super.key,
      this.weatherService,
      this.calendarService,
      this.recommendationService,
      this.reminderService,
      this.npkDevice,
      this.readingSubmission,
      this.fertilizerAdviceService,
      this.assistantService,
      this.onNavigate});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, Object?>> farms = [], tests = [];
  Map<int, int> farmFieldCounts = {};
  int? selectedFarmId;
  int fieldCount = 0;
  WeatherSummary? weather;
  List<CalendarEvent> events = [];
  List<CropEstimate> recommendations = [];
  String? farmerName;
  DeviceConnection? connection;
  StreamSubscription<DeviceConnection>? connectionSub;
  bool weatherError = false, calendarError = false, recommendationError = false;
  @override
  void initState() {
    super.initState();
    connectionSub = widget.npkDevice?.connectionEvents.listen((value) {
      if (mounted) setState(() => connection = value);
    });
    _load();
  }

  Future<void> _load() async {
    final store = LocalStore.instance;
    final f = await store.farms();
    final profile = await store.profile();
    final counts = <int, int>{};
    for (final farm in f) {
      counts[farm['id'] as int] =
          (await store.fields(farm['id'] as int)).length;
    }
    final activeFarmId = f.any((farm) => farm['id'] == selectedFarmId)
        ? selectedFarmId
        : (f.isEmpty ? null : f.first['id'] as int);
    final activeFields = activeFarmId == null
        ? <Map<String, Object?>>[]
        : await store.fields(activeFarmId);
    final t = <Map<String, Object?>>[];
    for (final field in activeFields) {
      final history = await store.testHistory(field['id'] as int);
      if (history.isNotEmpty) {
        t.add({...history.last, 'field_name': field['name']});
      }
    }
    t.sort((a, b) => DateTime.parse(b['tested_at'] as String)
        .compareTo(DateTime.parse(a['tested_at'] as String)));
    if (mounted)
      setState(() {
        farms = f;
        selectedFarmId = activeFarmId;
        farmFieldCounts = counts;
        farmerName = (profile?['name'] as String?)?.trim();
        fieldCount = counts.values.fold(0, (sum, count) => sum + count);
        tests = t;
      });
    if (widget.weatherService != null) {
      try {
        final first = activeFarmId == null
            ? null
            : f.firstWhere((farm) => farm['id'] == activeFarmId);
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
              unit: row['unit'] as String,
              source: row['source'] as String? ?? 'manual');
        }
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

  Future<void> _openCrops() async => _open(CropsScreen(
        recommendationService: widget.recommendationService,
        fertilizerAdviceService: widget.fertilizerAdviceService,
        calendarService: widget.calendarService,
        reminderService: widget.reminderService,
        readingSubmission: widget.readingSubmission,
      ));

  Future<void> _selectFarm(int id) async {
    setState(() => selectedFarmId = id);
    final fields = await LocalStore.instance.fields(id);
    final readings = <Map<String, Object?>>[];
    for (final field in fields) {
      final history = await LocalStore.instance.testHistory(field['id'] as int);
      if (history.isNotEmpty) {
        readings.add({...history.last, 'field_name': field['name']});
      }
    }
    readings.sort((a, b) => DateTime.parse(b['tested_at'] as String)
        .compareTo(DateTime.parse(a['tested_at'] as String)));
    if (mounted) setState(() => tests = readings);
    final farm = farms.firstWhere((item) => item['id'] == id);
    if (widget.weatherService != null) {
      try {
        weather = await widget.weatherService!
            .summary(farm['lat'] as double?, farm['lon'] as double?);
        weatherError = false;
      } catch (_) {
        weatherError = true;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    connectionSub?.cancel();
    super.dispose();
  }

  void _goTo(int destination, Widget fallback) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(destination);
    } else {
      _open(fallback);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = tests.isEmpty ? null : tests.first;
    final fieldName = latest?['field_name'] as String?;
    final firstName = farmerName?.trim().isNotEmpty == true
        ? farmerName!.trim().split(' ').first
        : localized(context, 'Farmer', 'விவசாயி');
    final connected = connection?.connected ?? false;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
            children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: FertaColors.forest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.grass_rounded,
                      color: FertaColors.lime, size: 25),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FERTA',
                        style: TextStyle(
                            color: FertaColors.forest,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1)),
                    Text(localized(context, 'FIELD JOURNAL', 'வயல் பதிவேடு'),
                        style: TextStyle(
                            color: FertaColors.muted,
                            fontSize: 9,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const Spacer(),
                IconButton.filledTonal(
                  onPressed: () => _goTo(4, const ProfileScreen()),
                  tooltip: translateAppText(context, 'Profile'),
                  icon: const Icon(Icons.person_outline_rounded),
                ),
              ]),
              const SizedBox(height: 22),
              Text(localized(context, 'Good morning', 'காலை வணக்கம்'),
                  style: Theme.of(context).textTheme.bodyMedium),
              Text(firstName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 18),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [FertaColors.forest, FertaColors.forestDeep],
                  ),
                  borderRadius: BorderRadius.circular(FertaRadius.lg),
                ),
                child: Stack(children: [
                  Positioned(
                    right: -22,
                    bottom: -44,
                    child: Icon(Icons.eco_outlined,
                        size: 190, color: Colors.white.withValues(alpha: .07)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                            connected
                                ? Icons.bluetooth_connected_rounded
                                : Icons.bluetooth_searching_rounded,
                            color: connected
                                ? FertaColors.lime
                                : const Color(0xffc7d7cc),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.npkDevice == null
                                  ? localized(
                                      context,
                                      'Analyzer not configured',
                                      'கருவி அமைக்கப்படவில்லை')
                                  : widget.npkDevice!.isSimulator
                                      ? localized(
                                          context,
                                          'Demo analyzer ready',
                                          'செய்முறை கருவி தயார்')
                                      : connected
                                          ? localized(
                                              context,
                                              'Analyzer connected',
                                              'கருவி இணைக்கப்பட்டது')
                                          : localized(
                                              context,
                                              'Analyzer disconnected',
                                              'கருவி இணைக்கப்படவில்லை'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (widget.npkDevice?.isSimulator ?? false)
                            _SourceBadge(
                              label: localized(context, 'DEMO', 'செய்முறை'),
                              light: true,
                            ),
                        ]),
                        const SizedBox(height: 22),
                        Text(
                          localized(context, 'Start with your soil',
                              'உங்கள் மண்ணைச் சோதிக்கத் தொடங்குங்கள்'),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: Colors.white, fontSize: 24),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          localized(
                            context,
                            'Choose a field, connect the analyzer and save your reading.',
                            'வயலைத் தேர்ந்தெடுத்து கருவியை இணைத்து அளவீட்டைப் பதிவு செய்யுங்கள்.',
                          ),
                          style: const TextStyle(
                              color: Color(0xffd6e2d9), height: 1.4),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: FertaColors.lime,
                            foregroundColor: FertaColors.forestDeep,
                          ),
                          onPressed: () => _goTo(
                              1,
                              SoilScreen(
                                  service: widget.npkDevice,
                                  readingSubmission: widget.readingSubmission)),
                          icon: const Icon(Icons.science_outlined),
                          label: AppText('Start soil test'),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 26),
              _DashboardSectionHeading(
                title: localized(context, 'Your farm', 'உங்கள் பண்ணை'),
                action: localized(context, 'Manage', 'நிர்வகி'),
                onTap: () => _goTo(
                    3,
                    FarmManagementScreen(
                        readingSubmission: widget.readingSubmission)),
              ),
              if (farms.isEmpty)
                _DashboardEmptyState(
                  icon: Icons.landscape_outlined,
                  title: localized(context, 'Add your first farm',
                      'உங்கள் முதல் பண்ணையைச் சேர்க்கவும்'),
                  description: localized(
                    context,
                    'Farm and field records stay on this device. Add one to organize soil tests.',
                    'பண்ணை மற்றும் வயல் பதிவுகள் இந்தச் சாதனத்தில் சேமிக்கப்படும். மண் பரிசோதனைகளை ஒழுங்குபடுத்த ஒன்றைச் சேர்க்கவும்.',
                  ),
                  action: localized(context, 'Add farm', 'பண்ணையைச் சேர்'),
                  onTap: () => _goTo(
                      3,
                      FarmManagementScreen(
                          readingSubmission: widget.readingSubmission)),
                )
              else
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(FertaRadius.md),
                    onTap: () => _goTo(
                        3,
                        FarmManagementScreen(
                            readingSubmission: widget.readingSubmission)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: FertaColors.leafLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.agriculture_outlined,
                              color: FertaColors.forest),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: selectedFarmId,
                                  isExpanded: true,
                                  borderRadius:
                                      BorderRadius.circular(FertaRadius.sm),
                                  icon: const Icon(
                                      Icons.keyboard_arrow_down_rounded),
                                  items: farms
                                      .map((farm) => DropdownMenuItem<int>(
                                            value: farm['id'] as int,
                                            child: Text(
                                              farm['name'] as String,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (id) {
                                    if (id != null) _selectFarm(id);
                                  },
                                ),
                              ),
                              Text(
                                (farmFieldCounts[selectedFarmId] ?? 0)
                                        .toString() +
                                    ' ' +
                                    localized(context, 'fields', 'வயல்கள்') +
                                    ' · ' +
                                    farms.length.toString() +
                                    ' ' +
                                    localized(context, 'farms', 'பண்ணைகள்'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: FertaColors.muted),
                      ]),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _DashboardSectionHeading(
                title: localized(
                    context, 'Latest soil reading', 'சமீபத்திய மண் அளவீடு'),
                action: latest == null
                    ? null
                    : localized(context, 'History', 'வரலாறு'),
                onTap: latest == null
                    ? null
                    : () => _open(FieldHistoryScreen(
                          fieldId: latest['field_id'] as int,
                          fieldName: fieldName ?? '',
                          submissionService: widget.readingSubmission,
                        )),
              ),
              if (latest == null)
                _DashboardEmptyState(
                  icon: Icons.science_outlined,
                  title: localized(
                      context, 'No readings yet', 'அளவீடுகள் இன்னும் இல்லை'),
                  description: localized(
                    context,
                    'Your saved N, P and K values will appear here. Start a soil test when you are ready.',
                    'சேமித்த N, P, K அளவுகள் இங்கே தோன்றும். தயாரானதும் மண் பரிசோதனையைத் தொடங்குங்கள்.',
                  ),
                  action:
                      localized(context, 'Start a test', 'பரிசோதனை தொடங்கு'),
                  onTap: () => _goTo(
                      1,
                      SoilScreen(
                          service: widget.npkDevice,
                          readingSubmission: widget.readingSubmission)),
                )
              else
                _LatestReadingCard(
                  reading: latest,
                  onTap: () => _open(FieldHistoryScreen(
                    fieldId: latest['field_id'] as int,
                    fieldName: fieldName ?? '',
                    submissionService: widget.readingSubmission,
                  )),
                ),
              const SizedBox(height: 14),
              _DashboardSectionHeading(
                  title: localized(context, 'Quick access', 'விரைவான அணுகல்')),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _QuickAction(
                    icon: Icons.spa_outlined,
                    label:
                        localized(context, 'Crop shortlist', 'பயிர் பட்டியல்'),
                    onTap: _openCrops,
                  ),
                  _QuickAction(
                      icon: Icons.yard_outlined,
                      label: 'Terrace garden',
                      onTap: () => _open(const TerraceGardeningScreen())),
                  _QuickAction(
                      icon: Icons.storefront_outlined,
                      label: 'Crops in demand',
                      onTap: () => _open(const CropDemandScreen())),
                  _QuickAction(
                      icon: Icons.calendar_month_outlined,
                      label: 'Farm calendar',
                      onTap: () => _open(CalendarScreen(
                          calendarService: widget.calendarService,
                          reminderService: widget.reminderService))),
                  _QuickAction(
                    icon: Icons.forum_outlined,
                    label: localized(context, 'Ask FERTA', 'FERTA-விடம் கேள்'),
                    onTap: () => _goTo(
                        2, AssistantScreen(service: widget.assistantService)),
                  ),
                  _QuickAction(
                    icon: Icons.notifications_outlined,
                    label: localized(context, 'Notifications', 'அறிவிப்புகள்'),
                    onTap: () => _open(NotificationsScreen(
                      calendarConnected: widget.calendarService != null,
                      remindersConnected: widget.reminderService != null,
                      calendarService: widget.calendarService,
                      reminderService: widget.reminderService,
                    )),
                  ),
                  if (weather != null || weatherError)
                    _QuickAction(
                      icon: Icons.cloud_outlined,
                      label: localized(context, 'Weather', 'வானிலை'),
                      onTap: () =>
                          _open(WeatherScreen(service: widget.weatherService)),
                    ),
                ],
              ),
              if (widget.recommendationService != null &&
                  recommendations.isNotEmpty) ...[
                const SizedBox(height: 22),
                _DashboardSectionHeading(
                  title: localized(context, 'Crop outlook', 'பயிர் பார்வை'),
                  action: localized(context, 'Details', 'விவரங்கள்'),
                  onTap: _openCrops,
                ),
                ...recommendations.take(2).map((item) => _Card(
                      icon: Icons.eco_outlined,
                      title: localized(context, 'Suggested crop',
                              'பரிந்துரைக்கப்படும் பயிர்') +
                          ': ' +
                          item.crop,
                      body: localized(
                        context,
                        'Planning estimate · review local conditions before deciding.',
                        'திட்டமிடல் மதிப்பீடு · முடிவு செய்வதற்கு முன் உள்ளூர் நிலைகளைச் சரிபார்க்கவும்.',
                      ),
                      onTap: _openCrops,
                    )),
              ],
              if (widget.calendarService != null && events.isNotEmpty) ...[
                const SizedBox(height: 22),
                _DashboardSectionHeading(
                  title: localized(
                      context, 'Upcoming activities', 'வரவிருக்கும் செயல்கள்'),
                  onTap: () => _open(CalendarScreen(
                      calendarService: widget.calendarService,
                      reminderService: widget.reminderService)),
                ),
                ...events.map((event) => _Card(
                      icon: Icons.event_outlined,
                      title: event.title,
                      body:
                          event.type + ' · ' + event.date.toLocal().toString(),
                      onTap: () => _open(CalendarScreen(
                          calendarService: widget.calendarService,
                          reminderService: widget.reminderService)),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
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
  final int? initialFarmId, focusTaskId;
  const CalendarScreen(
      {super.key,
      this.calendarService,
      this.reminderService,
      this.initialFarmId,
      this.focusTaskId});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<Map<String, Object?>> farms = [];
  List<Map<String, Object?>> fields = [];
  List<CalendarEvent> events = [];
  int? farmId, selectedFieldId;
  bool loading = true;
  bool failed = false;
  bool weekly = false;
  DateTime focus = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int? selectedFarmId, int? selectedField}) async {
    if (mounted) {
      setState(() {
        loading = true;
        failed = false;
      });
    }
    try {
      farms = await LocalStore.instance.farms();
      farmId = selectedFarmId ??
          widget.initialFarmId ??
          farmId ??
          (farms.isEmpty ? null : farms.first['id'] as int);
      fields = farmId == null ? [] : await LocalStore.instance.fields(farmId!);
      selectedFieldId = fields.any((field) => field['id'] == selectedField)
          ? selectedField
          : (fields.any((field) => field['id'] == selectedFieldId)
              ? selectedFieldId
              : null);
      if (widget.calendarService != null && farmId != null) {
        events = await widget.calendarService!.events(farmId!);
        events.sort((a, b) => a.date.compareTo(b.date));
        final target =
            events.where((event) => event.id == widget.focusTaskId).firstOrNull;
        if (target != null) focus = target.date;
      } else {
        events = [];
      }
    } catch (_) {
      failed = true;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _editTask([CalendarEvent? task]) async {
    final service = widget.calendarService;
    final selectedFarm = farmId;
    if (service == null || selectedFarm == null) return;
    final title = TextEditingController(text: task?.title ?? '');
    var type = task?.type ?? 'Watering';
    var date = task?.date ?? DateTime.now().add(const Duration(days: 1));
    var fieldKey = task?.fieldId ?? selectedFieldId ?? -1;
    final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, refresh) => AlertDialog(
                  title: Text(
                      task == null ? 'Add farming task' : 'Edit farming task'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: title,
                        decoration:
                            const InputDecoration(labelText: 'Task name')),
                    DropdownButtonFormField<String>(
                        initialValue: type,
                        items: const [
                          'Planting',
                          'Watering',
                          'Fertilizer',
                          'Harvest',
                          'Soil testing',
                          'Other'
                        ]
                            .map((v) =>
                                DropdownMenuItem(value: v, child: Text(v)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) refresh(() => type = v);
                        }),
                    if (fields.isNotEmpty)
                      DropdownButtonFormField<int>(
                        initialValue: fieldKey,
                        decoration: const InputDecoration(
                            labelText: 'Field (optional)'),
                        items: [
                          const DropdownMenuItem(
                              value: -1, child: Text('Whole farm')),
                          ...fields.map((field) => DropdownMenuItem(
                              value: field['id'] as int,
                              child: Text(field['name'] as String)))
                        ],
                        onChanged: (value) {
                          if (value != null) refresh(() => fieldKey = value);
                        },
                      ),
                    TextButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                              context: ctx,
                              initialDate: date,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 365)),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 3650)));
                          if (picked != null)
                            refresh(() => date = DateTime(
                                picked.year, picked.month, picked.day, 9));
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: Text('${date.day}/${date.month}/${date.year}')),
                    TextButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay.fromDateTime(date));
                          if (picked != null) {
                            refresh(() => date = DateTime(date.year, date.month,
                                date.day, picked.hour, picked.minute));
                          }
                        },
                        icon: const Icon(Icons.schedule),
                        label: Text(TimeOfDay.fromDateTime(date).format(ctx))),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Save task'))
                  ],
                )));
    if (saved != true || title.text.trim().isEmpty) return;
    final savedId = await service.saveTask(
        selectedFarm,
        CalendarEvent(type, title.text.trim(), date,
            id: task?.id,
            farmId: selectedFarm,
            fieldId: fieldKey < 0 ? null : fieldKey,
            completed: task?.completed ?? false));
    if (mounted) await _load();
    final created = events.where((event) => event.id == savedId).firstOrNull;
    if (created != null) await widget.reminderService?.schedule(created);
  }

  List<CalendarEvent> _visibleEvents() => events.where((event) {
        if (selectedFieldId != null &&
            event.fieldId != null &&
            event.fieldId != selectedFieldId) return false;
        if (weekly) {
          final start = focus.subtract(Duration(days: focus.weekday - 1));
          return !event.date
                  .isBefore(DateTime(start.year, start.month, start.day)) &&
              event.date.isBefore(start.add(const Duration(days: 7)));
        }
        return event.date.year == focus.year && event.date.month == focus.month;
      }).toList();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const AppText('Farming calendar'), actions: [
          IconButton(
              onPressed: () => setState(() => weekly = !weekly),
              tooltip: 'Toggle week/month',
              icon: Icon(weekly ? Icons.calendar_month : Icons.view_week))
        ]),
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
          if (fields.isNotEmpty)
            DropdownButtonFormField<int>(
              initialValue: selectedFieldId ?? -1,
              decoration: const InputDecoration(labelText: 'Field filter'),
              items: [
                const DropdownMenuItem(value: -1, child: Text('All fields')),
                ...fields.map((field) => DropdownMenuItem(
                    value: field['id'] as int,
                    child: Text(field['name'] as String)))
              ],
              onChanged: (id) => setState(
                  () => selectedFieldId = id == null || id < 0 ? null : id),
            ),
          const SizedBox(height: 16),
          Text(
              weekly
                  ? 'Week of ${focus.subtract(Duration(days: focus.weekday - 1)).day}/${focus.subtract(Duration(days: focus.weekday - 1)).month}/${focus.year}'
                  : '${_monthName(focus.month)} ${focus.year}',
              style: Theme.of(context).textTheme.titleLarge),
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
                    'No tasks for this farm in this period. Add a task and set a local reminder if you need one.')
          else
            ..._visibleEvents().map((event) => Card(
                  child: ListTile(
                    leading: event.id == null
                        ? const Icon(Icons.event)
                        : Checkbox(
                            value: event.completed,
                            onChanged: (value) async {
                              if (value == true) {
                                await widget.reminderService?.cancel(event);
                              } else {
                                await widget.reminderService?.schedule(event);
                              }
                              await widget.calendarService
                                  ?.setCompleted(event.id!, value ?? false);
                              await _load();
                            }),
                    title: Text(event.title,
                        style: TextStyle(
                            decoration: event.completed
                                ? TextDecoration.lineThrough
                                : null)),
                    subtitle:
                        AppText('${event.type} · ${event.date.toLocal()}'),
                    trailing: event.id == null
                        ? null
                        : PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') await _editTask(event);
                              if (value == 'delete') {
                                await widget.reminderService?.cancel(event);
                                await widget.calendarService
                                    ?.deleteTask(event.id!);
                                await _load();
                              }
                              if (value == 'remind')
                                await widget.reminderService?.schedule(event);
                            },
                            itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(
                                      value: 'remind',
                                      child: Text('Set reminder')),
                                  PopupMenuItem(
                                      value: 'delete', child: Text('Delete'))
                                ]),
                    onTap: () => _showCalendarEvent(
                        context, event, widget.reminderService),
                  ),
                )),
          TextButton.icon(
              onPressed: () => setState(() => focus = DateTime(
                  focus.year,
                  focus.month + (weekly ? 0 : 1),
                  focus.day + (weekly ? 7 : 0))),
              icon: const Icon(Icons.arrow_forward),
              label: Text('Next ${weekly ? 'week' : 'month'}')),
          const AppText(
              'Tasks stay on this device. Dates are user entered, not generated agronomic advice.'),
        ]),
        floatingActionButton: widget.calendarService == null || farms.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _editTask(),
                icon: const Icon(Icons.add),
                label: const Text('Add task')),
      );
}

String _monthName(int month) => const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ][month - 1];

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
  final ReadingSubmissionService? readingSubmission;
  const SoilScreen({super.key, this.service, this.readingSubmission});
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
      if (!event.result.isValid) {
        if (mounted) {
          setState(() => statusError =
              'The analyzer returned an invalid reading. No result was saved.');
        }
        return;
      }
      final target = fieldId;
      if (target == null) {
        if (mounted)
          _notice(context,
              'Choose a field before starting a test. This result was not saved.');
        return;
      }
      final isSimulated = event.result.source == 'simulated';
      final measuredAt = DateTime.now().toUtc();
      final save = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    localized(ctx, 'Review your reading',
                        'உங்கள் அளவீட்டைப் பாருங்கள்'),
                    style: Theme.of(ctx).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: Text(
                      localized(ctx, 'Reported values · mg/kg',
                          'பதிவான அளவுகள் · mg/kg'),
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                  ),
                  if (isSimulated)
                    _SourceBadge(label: localized(ctx, 'DEMO', 'செய்முறை')),
                ]),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      _NutrientMetric(
                          label: 'N',
                          value: event.result.nitrogen,
                          color: const Color(0xff39734a)),
                      _NutrientMetric(
                          label: 'P',
                          value: event.result.phosphorus,
                          color: const Color(0xff376a9f)),
                      _NutrientMetric(
                          label: 'K',
                          value: event.result.potassium,
                          color: const Color(0xffa96b25)),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  localized(
                    ctx,
                    'Measured at ${measuredAt.toLocal().toString().substring(0, 16)}',
                    'அளவீட்டு நேரம் ${measuredAt.toLocal().toString().substring(0, 16)}',
                  ),
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  isSimulated
                      ? localized(
                          ctx,
                          'Demo values are simulated and are not measurements from a real analyzer.',
                          'செய்முறை மதிப்புகள் உருவகப்படுத்தப்பட்டவை; உண்மையான கருவி அளவீடுகள் அல்ல.',
                        )
                      : localized(
                          ctx,
                          'These are reported values. Calibration and deficiency status have not been verified.',
                          'இவை பதிவான அளவுகள். அளவுத்திருத்தமும் குறைபாட்டு நிலையும் சரிபார்க்கப்படவில்லை.',
                        ),
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(localized(ctx, 'Discard', 'நீக்கு')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: Text(
                          localized(ctx, 'Save reading', 'அளவீட்டைச் சேமி')),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
      if (save == true) {
        final testId = await LocalStore.instance.saveTest(
            fieldId: target,
            n: event.result.nitrogen,
            p: event.result.phosphorus,
            k: event.result.potassium,
            unit: event.result.unit,
            testedAt: measuredAt,
            source: event.result.source);
        final submission = widget.readingSubmission;
        if (submission != null) {
          try {
            final remoteId = await submission.submitReading(event.result,
                measuredAt: measuredAt);
            await LocalStore.instance.markTestSynced(testId, remoteId);
            if (mounted) {
              _notice(context, 'Saved on this device and sent to the backend.');
            }
          } catch (_) {
            if (mounted) {
              _notice(context,
                  'Saved on this device, but not sent to the backend. You can retry from field history.');
            }
          }
        }
      }
      if (mounted) setState(() => statusError = null);
    }
  }

  @override
  Widget build(BuildContext context) => _Page(
        title: 'Soil testing',
        subtitle: 'Connect your analyzer and test a field',
        children: [
          _SoilWorkflowCard(
            simulator: widget.service?.isSimulator ?? false,
            scanning: scanning,
            connected: connection?.connected ?? false,
            testing: testing,
            hasField: fieldId != null,
            hasError: statusError != null,
          ),
          if (widget.service?.isSimulator ?? false)
            Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: const ListTile(
                    leading: Icon(Icons.science_outlined),
                    title: AppText('Demo mode: simulated readings'),
                    subtitle: AppText(
                        'These demonstration values are not measurements from a real analyzer.'))),
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
            onChanged: testing ? null : (id) => setState(() => fieldId = id),
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
                title: AppText(widget.service?.isSimulator == true
                    ? 'Demo analyzer connected'
                    : 'Device connected'),
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
                    builder: (_) => FarmManagementScreen(
                        readingSubmission: widget.readingSubmission)));
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
                            fieldName: field['name'] as String,
                            submissionService: widget.readingSubmission)));
                  },
          ),
          if (fieldId == null)
            Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => FarmManagementScreen(
                              readingSubmission: widget.readingSubmission)));
                      if (mounted) _loadFields();
                    },
                    icon: const Icon(Icons.add),
                    label: const AppText('Add a field to view history'))),
        ],
      );
}

class CropsScreen extends StatefulWidget {
  final CropRecommendationService? recommendationService;
  final FertilizerAdviceService? fertilizerAdviceService;
  final FarmingCalendarService? calendarService;
  final FarmingReminderService? reminderService;
  final ReadingSubmissionService? readingSubmission;
  const CropsScreen(
      {super.key,
      this.recommendationService,
      this.fertilizerAdviceService,
      this.calendarService,
      this.reminderService,
      this.readingSubmission});
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
  FertilizerAdvice? fertilizerAdvice;
  List<CalendarEvent> events = [];
  Map<String, Object?>? latestReading;
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
    final selectedId = farmRows.any((farm) => farm['id'] == farmId)
        ? farmId
        : (farmRows.isEmpty ? null : farmRows.first['id'] as int);
    final cropRows = selectedId == null
        ? <Map<String, Object?>>[]
        : await store.crops(selectedId);
    Map<String, Object?>? newestReading;
    if (selectedId != null) {
      for (final field in await store.fields(selectedId)) {
        final history = await store.testHistory(field['id'] as int);
        if (history.isEmpty) continue;
        final row = history.last;
        if (newestReading == null ||
            DateTime.parse(row['tested_at'] as String).isAfter(
                DateTime.parse(newestReading['tested_at'] as String))) {
          newestReading = {...row, 'field_name': field['name']};
        }
      }
    }
    final soil = newestReading == null
        ? null
        : NpkResult(
            (newestReading['n'] as num).toDouble(),
            (newestReading['p'] as num).toDouble(),
            (newestReading['k'] as num).toDouble(),
            unit: newestReading['unit'] as String,
            source: newestReading['source'] as String? ?? 'manual',
          );
    List<CropEstimate> recs = [];
    FertilizerAdvice? nutrientAdvice;
    List<CalendarEvent> calendarEvents = [];
    var recFailed = false, calendarFailed = false;
    if (selectedId != null && widget.recommendationService != null) {
      try {
        final profile = await store.profile();
        recs = await widget.recommendationService!
            .recommend((profile?['language'] as String?) ?? 'en', soil);
      } catch (_) {
        recFailed = true;
      }
    }
    if (selectedId != null && widget.fertilizerAdviceService != null) {
      try {
        if (soil != null) {
          nutrientAdvice = await widget.fertilizerAdviceService!.recommend(
            soil,
            crop: cropRows.isEmpty ? null : cropRows.first['crop'] as String,
          );
        }
      } catch (_) {
        recFailed = true;
      }
    }
    if (selectedId != null && widget.calendarService != null) {
      try {
        calendarEvents = await widget.calendarService!.events(selectedId);
        calendarEvents.sort((a, b) => a.date.compareTo(b.date));
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
        fertilizerAdvice = nutrientAdvice;
        latestReading = newestReading;
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
                        builder: (_) => FarmManagementScreen(
                            readingSubmission: widget.readingSubmission)));
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
            if (farmId != null) ...[
              const SizedBox(height: 18),
              _DashboardSectionHeading(
                title: localized(
                    context, 'Latest soil reading', 'சமீபத்திய மண் அளவீடு'),
              ),
              if (latestReading == null)
                _DashboardEmptyState(
                  icon: Icons.science_outlined,
                  title: localized(context, 'No reading for this farm yet',
                      'இந்தப் பண்ணைக்கு இன்னும் அளவீடு இல்லை'),
                  description: localized(
                      context,
                      'Save a field reading to ground crop and fertilizer guidance in your soil data.',
                      'பயிர் மற்றும் உர வழிகாட்டுதலை உங்கள் மண் தரவில் அமைக்க வயல் அளவீட்டைச் சேமிக்கவும்.'),
                  action:
                      localized(context, 'Manage fields', 'வயல்களை நிர்வகி'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FarmManagementScreen(
                          readingSubmission: widget.readingSubmission),
                    ),
                  ),
                )
              else
                _LatestReadingCard(
                  reading: latestReading!,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FieldHistoryScreen(
                        fieldId: latestReading!['field_id'] as int,
                        fieldName:
                            latestReading!['field_name'] as String? ?? '',
                        submissionService: widget.readingSubmission,
                      ),
                    ),
                  ),
                ),
            ],
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
            if (widget.fertilizerAdviceService != null)
              if (fertilizerAdvice == null)
                const _Card(
                    icon: Icons.science_outlined,
                    title: 'Fertilizer advice',
                    body:
                        'Save a soil reading to request advice. The app will not show fertilizer quantities without verified local calibration.')
              else
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                  'Fertilizer advice · ${fertilizerAdvice!.status}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              const AppText(
                                  'No fertilizer quantities are shown because verified local crop and soil calibration is not configured.'),
                              ...fertilizerAdvice!.advice.map((line) =>
                                  ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.info_outline),
                                      title: AppText(line))),
                              if (fertilizerAdvice!
                                  .additionalInformation.isNotEmpty)
                                AppText(
                                    'Information needed: ${fertilizerAdvice!.additionalInformation.join(', ')}'),
                              if (fertilizerAdvice!.sources.isNotEmpty)
                                AppText(
                                    'Sources: ${fertilizerAdvice!.sources.join(', ')}')
                            ]))),
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
  final composerFocus = FocusNode();
  final speech = stt.SpeechToText();
  final tts = FlutterTts();
  final messages = <_ChatItem>[];
  bool sending = false, listening = false;
  String? lastQuestion;
  String? failedQuestion;
  File? diseasePhoto;
  String diseaseCrop = 'Tomato';
  final imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final rows = await LocalStore.instance.chatMessages();
    final restored = <_ChatItem>[];
    for (final row in rows) {
      if (row['role'] == 'farmer') {
        restored.add(_ChatItem.question(row['content'] as String));
      } else {
        List<String> sources = const [];
        try {
          final decoded = jsonDecode(row['sources'] as String);
          if (decoded is List) sources = decoded.whereType<String>().toList();
        } on FormatException {
          // Ignore malformed optional source metadata; keep the answer text.
        }
        restored.add(_ChatItem.answer(AssistantReply(
          row['content'] as String,
          sources,
          row['answer_type'] as String? ?? 'general_information',
          row['provider_status'] as String? ?? 'unknown',
          (row['insufficient_information'] as int? ?? 0) == 1,
        )));
      }
    }
    if (mounted) setState(() => messages.addAll(restored));
  }

  Future<String> _language() async {
    final profile = await LocalStore.instance.profile();
    return (profile?['language'] as String?) ?? 'en';
  }

  Future<void> _ask({String? retryQuestion}) async {
    final question = retryQuestion ?? controller.text.trim();
    final retry = retryQuestion != null;
    final service = widget.service;
    if (question.isEmpty || service == null || sending) return;
    if (!retry) controller.clear();
    setState(() {
      if (!retry) messages.add(_ChatItem.question(question));
      sending = true;
      lastQuestion = question;
      failedQuestion = null;
    });
    try {
      if (!retry)
        await LocalStore.instance
            .addChatMessage(role: 'farmer', content: question);
      final language = await _language();
      AssistantReply? latest;
      await for (final reply in service.ask(question, language)) {
        latest = reply;
      }
      final answer = latest;
      if (answer == null) throw StateError('Assistant returned no response');
      await LocalStore.instance.addChatMessage(
        role: 'assistant',
        content: answer.text,
        sources: answer.sources,
        answerType: answer.answerType,
        providerStatus: answer.providerStatus,
        insufficientInformation: answer.insufficientInformation,
      );
      if (mounted) setState(() => messages.add(_ChatItem.answer(answer)));
      failedQuestion = null;
      await tts.setLanguage(language == 'ta' ? 'ta-IN' : 'en-US');
      await tts.speak(answer.text);
    } catch (_) {
      if (mounted) setState(() => failedQuestion = question);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _selectDiseasePhoto() async {
    final file = await imagePicker.pickImage(
        source: ImageSource.gallery, imageQuality: 82, maxWidth: 1800);
    if (file != null && mounted) setState(() => diseasePhoto = File(file.path));
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
    final colors = Theme.of(context).colorScheme;
    final isFarmer = item.farmer;
    final reply = item.reply;
    final status = reply?.providerStatus == 'knowledge_fallback'
        ? localized(
            context, 'Safe information fallback', 'பாதுகாப்பான தகவல் மாற்று')
        : reply?.providerStatus == 'ollama_generated'
            ? localized(context, 'AI-generated · review sources',
                'AI உருவாக்கியது · ஆதாரங்களைப் பாருங்கள்')
            : localized(context, 'Answer status unavailable',
                'பதில் நிலை கிடைக்கவில்லை');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
      child: Align(
        alignment: isFarmer ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isFarmer ? FertaColors.forest : Colors.white,
              borderRadius: BorderRadius.circular(18).copyWith(
                bottomRight: isFarmer ? const Radius.circular(5) : null,
                bottomLeft: isFarmer ? null : const Radius.circular(5),
              ),
              border: isFarmer ? null : Border.all(color: FertaColors.line),
            ),
            child: isFarmer
                ? Text(item.question,
                    style: const TextStyle(color: Colors.white, height: 1.4))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.eco_outlined,
                            size: 16, color: FertaColors.leaf),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(status,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: FertaColors.muted)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(reply?.text ?? '',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(height: 1.5)),
                      if (reply?.sources.isNotEmpty ?? false) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Text(localized(context, 'Sources', 'ஆதாரங்கள்'),
                            style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 4),
                        ...reply!.sources.map((source) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: SelectableText(
                                source,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: colors.primary),
                              ),
                            )),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    composerFocus.dispose();
    speech.stop();
    tts.stop();
    super.dispose();
  }

  void _useQuestion(String question) {
    controller.text = question;
    controller.selection = TextSelection.collapsed(offset: question.length);
    composerFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: SizedBox.expand(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: FertaColors.leafLight,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.forum_outlined,
                                color: FertaColors.forest),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  localized(context, 'Ask FERTA',
                                      'FERTA-விடம் கேளுங்கள்'),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(
                                  localized(
                                      context,
                                      'Grounded soil and farming guidance',
                                      'மண் மற்றும் விவசாயத்திற்கான நம்பகமான வழிகாட்டல்'),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (sending)
                            const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                    if (widget.service == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: FertaColors.warningLight,
                            borderRadius: BorderRadius.circular(FertaRadius.sm),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.cloud_off_outlined,
                                  color: FertaColors.warning, size: 20),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  localized(
                                    context,
                                    'Assistant service is not connected. Your questions stay on this device.',
                                    'உதவியாளர் சேவை இணைக்கப்படவில்லை. உங்கள் கேள்விகள் இந்தச் சாதனத்தில் மட்டுமே இருக்கும்.',
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: messages.isEmpty
                          ? Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 66,
                                      height: 66,
                                      decoration: const BoxDecoration(
                                        color: FertaColors.leafLight,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.eco_outlined,
                                          color: FertaColors.forest, size: 32),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      localized(context, 'How can I help?',
                                          'நான் எப்படி உதவலாம்?'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      localized(
                                        context,
                                        'Ask about soil tests, nutrients or general crop care. Advice depends on verified local information.',
                                        'மண் பரிசோதனை, ஊட்டச்சத்து அல்லது பொதுவான பயிர் பராமரிப்பு பற்றி கேளுங்கள். ஆலோசனை சரிபார்க்கப்பட்ட உள்ளூர் தகவல்களைப் பொறுத்தது.',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                    const SizedBox(height: 18),
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ActionChip(
                                          avatar: const Icon(
                                              Icons.science_outlined,
                                              size: 16),
                                          label: Text(localized(
                                              context,
                                              'How do soil tests guide fertilizer?',
                                              'மண் பரிசோதனை உரத் தேர்வுக்கு எப்படி உதவும்?')),
                                          onPressed: widget.service == null
                                              ? null
                                              : () => _useQuestion(
                                                  'How do soil tests guide fertilizer decisions?'),
                                        ),
                                        ActionChip(
                                          avatar: const Icon(
                                              Icons.grass_outlined,
                                              size: 16),
                                          label: Text(localized(
                                              context,
                                              'What affects nutrient availability?',
                                              'ஊட்டச்சத்து கிடைப்பதை எது பாதிக்கிறது?')),
                                          onPressed: widget.service == null
                                              ? null
                                              : () => _useQuestion(
                                                  'What factors affect nutrient availability in soil?'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 16, 18, 20),
                              itemCount: messages.length,
                              itemBuilder: (_, index) =>
                                  _message(messages[index]),
                            ),
                    ),
                    if (failedQuestion != null)
                      Card(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        color: FertaColors.errorLight,
                        child: ListTile(
                          leading: const Icon(Icons.cloud_off_outlined,
                              color: FertaColors.error),
                          title: const Text('Could not reach the assistant'),
                          subtitle: const Text(
                              'Check your connection or backend service, then retry.'),
                          trailing: IconButton(
                              tooltip: 'Retry',
                              onPressed: sending || widget.service == null
                                  ? null
                                  : () => _ask(retryQuestion: failedQuestion),
                              icon: const Icon(Icons.refresh)),
                        ),
                      ),
                    if (diseasePhoto != null)
                      Card(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(children: [
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(diseasePhoto!,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    DropdownButton<String>(
                                        value: diseaseCrop,
                                        isExpanded: true,
                                        items: const [
                                          'Tomato',
                                          'Rice',
                                          'Cotton',
                                          'Groundnut',
                                          'Potato'
                                        ]
                                            .map((crop) => DropdownMenuItem(
                                                value: crop, child: Text(crop)))
                                            .toList(),
                                        onChanged: (crop) => setState(() =>
                                            diseaseCrop = crop ?? diseaseCrop)),
                                    const Text(
                                        'Photo analysis is not configured. This image stays on your device and was not uploaded.',
                                        style: TextStyle(fontSize: 12)),
                                  ])),
                              IconButton(
                                  tooltip: 'Remove photo',
                                  onPressed: () =>
                                      setState(() => diseasePhoto = null),
                                  icon: const Icon(Icons.close)),
                            ])),
                      ),
                    if (lastQuestion != null)
                      TextButton.icon(
                        onPressed:
                            widget.service == null ? null : _contactExpert,
                        icon: const Icon(Icons.support_agent_outlined),
                        label: Text(localized(
                            context,
                            'Contact an agricultural expert',
                            'வேளாண் நிபுணரைத் தொடர்புகொள்ளுங்கள்')),
                      ),
                    if (sending)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 9),
                            Text(
                              localized(context, 'Preparing a sourced answer…',
                                  'ஆதாரமுள்ள பதிலைத் தயாரிக்கிறது…'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border:
                            Border(top: BorderSide(color: FertaColors.line)),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton.filledTonal(
                            onPressed: _selectDiseasePhoto,
                            tooltip: 'Choose plant photo',
                            icon: const Icon(Icons.attach_file),
                          ),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              focusNode: composerFocus,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _ask(),
                              decoration: InputDecoration(
                                hintText: translateAppText(
                                    context, 'Type your question'),
                                fillColor: FertaColors.canvas,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide:
                                      const BorderSide(color: FertaColors.leaf),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton.filledTonal(
                            onPressed: widget.service == null
                                ? null
                                : (listening ? _stopListening : _listen),
                            icon: Icon(listening
                                ? Icons.mic_rounded
                                : Icons.mic_none_rounded),
                            tooltip: translateAppText(
                                context, 'Speak your question'),
                          ),
                          IconButton.filled(
                            onPressed:
                                widget.service == null || sending ? null : _ask,
                            icon: const Icon(Icons.arrow_upward_rounded),
                            tooltip: translateAppText(context, 'Ask'),
                          ),
                        ],
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

class ProfileScreen extends StatefulWidget {
  final bool calendarConnected;
  final bool remindersConnected;
  final FarmingCalendarService? calendarService;
  final FarmingReminderService? reminderService;
  final ReadingSubmissionService? readingSubmission;
  const ProfileScreen({
    super.key,
    this.calendarConnected = false,
    this.remindersConnected = false,
    this.calendarService,
    this.reminderService,
    this.readingSubmission,
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
              clipBehavior: Clip.antiAlias,
              color: FertaColors.forest,
              child: InkWell(
                onTap: _editName,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: FertaColors.lime,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.person_rounded,
                            color: FertaColors.forest, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              farmerName ?? 'Guest farmer',
                              translate: farmerName == null,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const AppText(
                              'Local profile · no account required',
                              style: TextStyle(color: Color(0xffd6e2d9)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_outlined, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
            _DashboardSectionHeading(
                title: localized(context, 'Preferences', 'விருப்பங்கள்')),
            _DashboardSectionHeading(
                title: localized(
                    context, 'Farm & device data', 'பண்ணை மற்றும் கருவி தரவு')),
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
                    onTap: () => _open(FarmManagementScreen(
                        readingSubmission: widget.readingSubmission)))),
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
                    leading:
                        const CircleAvatar(child: Icon(Icons.support_agent)),
                    title: const AppText('Expert dashboard'),
                    subtitle:
                        const AppText('Expert workspace integration status'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(const ExpertDashboardScreen()))),
            _DashboardSectionHeading(
                title: localized(context, 'Connections', 'இணைப்புகள்')),
            Card(
                child: ListTile(
                    leading: const CircleAvatar(
                        child: Icon(Icons.notifications_none)),
                    title: const AppText('Notifications'),
                    subtitle: const AppText(
                        'Local reminder preferences, scheduled tasks and history.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(NotificationsScreen(
                        calendarConnected: widget.calendarConnected,
                        remindersConnected: widget.remindersConnected,
                        calendarService: widget.calendarService,
                        reminderService: widget.reminderService))))
          ]);
}

class NotificationsScreen extends StatefulWidget {
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
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Map<String, bool> preferences = {};
  List<Map<String, Object?>> history = [];
  static const categories = {
    'watering': 'Watering',
    'fertilizer': 'Fertilizer',
    'planting': 'Planting',
    'harvesting': 'Harvesting',
    'calendar_tasks': 'Calendar tasks',
    'appointments': 'Appointments',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await LocalStore.instance.notificationPreferences();
    final h = await LocalStore.instance.notificationHistory();
    if (mounted)
      setState(() {
        preferences = p;
        history = h;
      });
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Clear notification history?'),
              content: const Text(
                  'This removes saved history and cancels scheduled local reminders.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Keep')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Clear history'))
              ],
            ));
    if (confirmed != true) return;
    for (final row in history) {
      await widget.reminderService
          ?.cancelNotification(row['notification_id'] as int);
    }
    await LocalStore.instance.clearNotificationHistory();
    await _load();
  }

  Future<void> _toggleCategory(String category, bool enabled) async {
    await LocalStore.instance.setNotificationPreference(category, enabled);
    if (!enabled && widget.reminderService != null) {
      for (final row in history.where((item) =>
          item['category'] == category && item['is_scheduled'] == 1)) {
        await widget.reminderService!
            .cancelNotification(row['notification_id'] as int);
      }
    }
    await _load();
  }

  Future<void> _openHistoryItem(Map<String, Object?> item) async {
    await LocalStore.instance.markNotificationRead(item['id'] as int);
    final farmId = item['related_farm_id'] as int?;
    final taskId = item['related_task_id'] as int?;
    await _load();
    if (farmId == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CalendarScreen(
              calendarService: widget.calendarService,
              reminderService: widget.reminderService,
              initialFarmId: farmId,
              focusTaskId: taskId,
            )));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const AppText('Notification settings')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Card(
              child: ListTile(
                  leading: Icon(Icons.phone_android),
                  title: Text('Local notifications'),
                  subtitle: Text(
                      'Reminders stay on this device. Remote push notifications are not configured.'))),
          const Text('Reminder categories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ...categories.entries.map((entry) => SwitchListTile(
              title: Text(entry.value),
              value: preferences[entry.key] ?? true,
              onChanged: (value) => _toggleCategory(entry.key, value))),
          Row(children: [
            const Expanded(
                child: Text('History',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            TextButton(
                onPressed: history.any((row) => row['is_read'] == 0)
                    ? () async {
                        await LocalStore.instance.markAllNotificationsRead();
                        await _load();
                      }
                    : null,
                child: const Text('Mark all read')),
            IconButton(
                onPressed: history.isEmpty ? null : _clearHistory,
                tooltip: 'Clear history',
                icon: const Icon(Icons.delete_outline))
          ]),
          if (history.isEmpty)
            const Card(
                child: ListTile(
                    leading: Icon(Icons.notifications_none),
                    title: Text('No notification history yet'),
                    subtitle:
                        Text('Schedule a calendar reminder to see it here.'))),
          ...history.map((row) => Card(
                  child: ListTile(
                leading: Icon(
                    row['is_read'] == 1
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                    color: row['is_read'] == 1
                        ? FertaColors.muted
                        : FertaColors.forest),
                title: Text(row['title'] as String),
                subtitle: Text(
                    '${categories[row['category']] ?? row['category']} · ${DateTime.parse(row['scheduled_for'] as String).toLocal()}${row['is_scheduled'] == 1 ? ' · scheduled' : ''}'),
                trailing: row['is_read'] == 1
                    ? null
                    : IconButton(
                        tooltip: 'Mark as read',
                        icon: const Icon(Icons.mark_email_read_outlined),
                        onPressed: () async {
                          await LocalStore.instance
                              .markNotificationRead(row['id'] as int);
                          await _load();
                        }),
                onTap: () => _openHistoryItem(row),
              ))),
          if (widget.calendarConnected)
            Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => CalendarScreen(
                              calendarService: widget.calendarService,
                              reminderService: widget.reminderService))),
                  icon: const Icon(Icons.calendar_month),
                  label: const AppText('Open farming calendar'),
                )),
        ]),
      );
}

class FarmManagementScreen extends StatefulWidget {
  final ReadingSubmissionService? readingSubmission;
  const FarmManagementScreen({super.key, this.readingSubmission});
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
                                                    builder: (_) => FieldHistoryScreen(
                                                        fieldId: f['id'] as int,
                                                        fieldName:
                                                            f['name'] as String,
                                                        submissionService: widget
                                                            .readingSubmission))),
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
        'Delete all farms, fields, photos, saved devices, crop selections, soil-test history and assistant conversations from this device? This cannot be undone.'))
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
            'Farm records, photos, crop selections, saved devices, soil history and assistant conversations are stored only on this device.'),
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
  final ReadingSubmissionService? submissionService;
  const FieldHistoryScreen(
      {super.key,
      required this.fieldId,
      required this.fieldName,
      this.submissionService});
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

  Future<void> _sync(Map<String, Object?> test) async {
    final service = widget.submissionService;
    if (service == null) return;
    final reading = NpkResult(
      (test['n'] as num).toDouble(),
      (test['p'] as num).toDouble(),
      (test['k'] as num).toDouble(),
      unit: test['unit'] as String,
      source: test['source'] as String? ?? 'manual',
    );
    try {
      final remoteId = await service.submitReading(reading,
          measuredAt: DateTime.parse(test['tested_at'] as String));
      await LocalStore.instance.markTestSynced(test['id'] as int, remoteId);
      await _load();
      if (mounted) _notice(context, 'Reading sent to the backend.');
    } catch (_) {
      if (mounted) {
        _notice(context,
            'The reading is still saved on this device. Check the backend connection and retry.');
      }
    }
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
                  itemCount: tests.length + (tests.length > 1 ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (tests.length > 1 && i == 0) {
                      return _NpkTrendChart(tests: tests);
                    }
                    final testIndex = i - (tests.length > 1 ? 1 : 0);
                    final t = tests[testIndex];
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
                                '${date.toString().substring(0, 16)} · N ${t['n']}  P ${t['p']}  K ${t['k']} ${t['unit']}${t['source'] == 'simulated' ? ' · SIMULATED DEMO' : ''}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 5),
                                Text(
                                  'N ${t['n']}  ·  P ${t['p']}  ·  K ${t['k']} ${t['unit']}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 5),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (t['source'] == 'simulated')
                                      _SourceBadge(
                                          label: localized(
                                              context, 'DEMO', 'செய்முறை')),
                                    Icon(
                                      (t['sync_status'] as String? ??
                                                  'local') ==
                                              'synced'
                                          ? Icons.cloud_done_outlined
                                          : Icons.cloud_off_outlined,
                                      size: 14,
                                      color: FertaColors.muted,
                                    ),
                                    Text(
                                      (t['sync_status'] as String? ??
                                                  'local') ==
                                              'synced'
                                          ? localized(context, 'Synced',
                                              'ஒத்திசைக்கப்பட்டது')
                                          : localized(
                                              context,
                                              'Saved on device · sync pending',
                                              'சாதனத்தில் சேமிக்கப்பட்டது · ஒத்திசைவு நிலுவையில்'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                    if ((t['note'] as String).isNotEmpty)
                                      Text(
                                        t['note'] as String,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            leading: Icon((t['favorite'] as int) == 1
                                ? Icons.star
                                : Icons.science_outlined),
                            trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'note') _note(t);
                                  if (v == 'favorite') _favorite(t);
                                  if (v == 'delete') _delete(t['id'] as int);
                                  if (v == 'sync') _sync(t);
                                },
                                itemBuilder: (_) => [
                                      if (widget.submissionService != null &&
                                          (t['sync_status'] as String? ??
                                                  'local') !=
                                              'synced')
                                        const PopupMenuItem(
                                            value: 'sync',
                                            child:
                                                AppText('Retry backend sync')),
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

class _NpkTrendChart extends StatelessWidget {
  const _NpkTrendChart({required this.tests});

  final List<Map<String, Object?>> tests;

  @override
  Widget build(BuildContext context) {
    final first = DateTime.parse(tests.first['tested_at'] as String).toLocal();
    final last = DateTime.parse(tests.last['tested_at'] as String).toLocal();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText('NPK history trend',
                style: TextStyle(fontWeight: FontWeight.bold)),
            AppText('Recorded values only · ${tests.first['unit']}'),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              width: double.infinity,
              child: CustomPaint(painter: _NpkTrendPainter(tests)),
            ),
            const Wrap(spacing: 16, children: [
              _ChartLegend(color: Color(0xff2e7d32), label: 'N'),
              _ChartLegend(color: Color(0xff1565c0), label: 'P'),
              _ChartLegend(color: Color(0xffef6c00), label: 'K'),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              AppText(first.toString().substring(0, 10)),
              AppText(last.toString().substring(0, 10)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          AppText(label),
        ],
      );
}

class _NpkTrendPainter extends CustomPainter {
  _NpkTrendPainter(this.tests);

  final List<Map<String, Object?>> tests;
  static const colors = [
    Color(0xff2e7d32),
    Color(0xff1565c0),
    Color(0xffef6c00)
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 10.0;
    final chart =
        Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset);
    final gridPaint = Paint()
      ..color = const Color(0xffdfe5df)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    final series = [
      tests.map((row) => (row['n'] as num).toDouble()).toList(),
      tests.map((row) => (row['p'] as num).toDouble()).toList(),
      tests.map((row) => (row['k'] as num).toDouble()).toList(),
    ];
    var maximum = 1.0;
    for (final values in series) {
      for (final value in values) {
        if (value.isFinite && value > maximum) maximum = value;
      }
    }
    for (var s = 0; s < series.length; s++) {
      final values = series[s];
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final x = values.length == 1
            ? chart.center.dx
            : chart.left + chart.width * i / (values.length - 1);
        final y = chart.bottom - chart.height * values[i] / maximum;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = colors[s]);
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = colors[s]
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _NpkTrendPainter oldDelegate) =>
      !identical(oldDelegate.tests, tests);
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
          leading: const Icon(Icons.cloud_upload_outlined),
          title: const AppText('Backend sync'),
          subtitle: AppText(
              (test['sync_status'] as String? ?? 'local') == 'synced'
                  ? 'Sent to the backend'
                  : 'Saved locally; not yet sent to the backend'),
        ),
        ListTile(
          leading: const Icon(Icons.sensors_outlined),
          title: const AppText('Reading source'),
          subtitle: AppText(test['source'] == 'simulated'
              ? 'Simulated demo reading, not a device measurement'
              : (test['source'] as String? ?? 'manual')),
        ),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Builder(builder: (context) {
              final reduceMotion = MediaQuery.disableAnimationsOf(context);
              final content = ListView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
                children: [
                  Row(children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: FertaColors.forest,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(Icons.grass_rounded,
                          size: 20, color: FertaColors.lime),
                    ),
                    const SizedBox(width: 10),
                    Text('FERTA',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: FertaColors.forest,
                              letterSpacing: 1.4,
                            )),
                    const Spacer(),
                    const Icon(Icons.eco_outlined,
                        size: 19, color: FertaColors.leaf),
                  ]),
                  const SizedBox(height: 24),
                  AppText(
                    localizedPageText(context, title),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 7),
                  AppText(
                    localizedPageText(context, subtitle),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  ...children,
                ],
              );
              if (reduceMotion) return content;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 9 * (1 - value)),
                    child: child,
                  ),
                ),
                child: content,
              );
            }),
          ),
        ),
      );
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
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [FertaColors.sage, FertaColors.leafLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(FertaRadius.sm),
                  ),
                  child: Icon(icon, color: FertaColors.forest),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 3),
                      AppText(body,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded,
                      color: FertaColors.muted),
                ],
              ],
            ),
          ),
        ),
      );
}

class _SoilWorkflowCard extends StatelessWidget {
  final bool simulator;
  final bool scanning;
  final bool connected;
  final bool testing;
  final bool hasField;
  final bool hasError;

  const _SoilWorkflowCard({
    required this.simulator,
    required this.scanning,
    required this.connected,
    required this.testing,
    required this.hasField,
    required this.hasError,
  });

  @override
  Widget build(BuildContext context) {
    final stage = testing
        ? 2
        : connected
            ? 1
            : 0;
    final status = hasError
        ? localized(context, 'Needs attention', 'கவனம் தேவை')
        : testing
            ? localized(context, 'Testing', 'பரிசோதிக்கிறது')
            : scanning
                ? localized(context, 'Searching', 'தேடுகிறது')
                : connected
                    ? localized(context, 'Connected', 'இணைக்கப்பட்டது')
                    : hasField
                        ? localized(
                            context, 'Ready to connect', 'இணைக்கத் தயார்')
                        : localized(context, 'Choose a field',
                            'வயலைத் தேர்ந்தெடுக்கவும்');
    final statusColor = hasError
        ? FertaColors.error
        : testing || connected
            ? FertaColors.success
            : FertaColors.muted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                    localized(context, 'Test workflow', 'பரிசோதனை நடைமுறை'),
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Container(
                  key: ValueKey(status),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(FertaRadius.pill),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Row(
              children: [
                _WorkflowStep(
                  number: '1',
                  label: localized(context, 'Field', 'வயல்'),
                  complete: hasField,
                  active: stage == 0 && !hasField,
                ),
                const _WorkflowConnector(),
                _WorkflowStep(
                  number: '2',
                  label: localized(context, 'Analyzer', 'கருவி'),
                  complete: connected,
                  active: stage == 1 || scanning,
                ),
                const _WorkflowConnector(),
                _WorkflowStep(
                  number: '3',
                  label: localized(context, 'Reading', 'அளவீடு'),
                  complete: false,
                  active: testing,
                ),
              ],
            ),
            if (testing) ...[
              const SizedBox(height: 15),
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 7),
              Text(
                simulator
                    ? localized(context, 'Demo reading in progress · simulated',
                        'செய்முறை அளவீடு நடைபெறுகிறது · உருவகப்படுத்தப்பட்டது')
                    : localized(context, 'Waiting for analyzer reading',
                        'கருவி அளவீட்டிற்காக காத்திருக்கிறது'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  final String number;
  final String label;
  final bool complete;
  final bool active;

  const _WorkflowStep({
    required this.number,
    required this.label,
    required this.complete,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = complete || active ? FertaColors.forest : FertaColors.muted;
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: complete || active ? FertaColors.leafLight : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                  color: complete || active ? color : FertaColors.line),
            ),
            child: complete
                ? Icon(Icons.check_rounded, size: 16, color: color)
                : Text(number,
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _WorkflowConnector extends StatelessWidget {
  const _WorkflowConnector();

  @override
  Widget build(BuildContext context) => Container(
        width: 14,
        height: 1,
        color: FertaColors.line,
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );
}

class _DashboardSectionHeading extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onTap;

  const _DashboardSectionHeading({
    required this.title,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: FertaSectionLabel(children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 18,
                          )),
                ),
              ]),
            ),
            if (action != null && onTap != null)
              TextButton(onPressed: onTap, child: Text(action!)),
          ],
        ),
      );
}

class _SourceBadge extends StatelessWidget {
  final String label;
  final bool light;

  const _SourceBadge({required this.label, this.light = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: light ? const Color(0xffd8e8a8) : FertaColors.warningLight,
          borderRadius: BorderRadius.circular(FertaRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: light ? FertaColors.forestDeep : FertaColors.warning,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
          ),
        ),
      );
}

class _DashboardEmptyState extends StatelessWidget {
  final IconData icon;
  final String title, description, action;
  final VoidCallback onTap;

  const _DashboardEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: FertaColors.leaf, size: 26),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(description,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 9),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onTap,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: Text(action),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _LatestReadingCard extends StatelessWidget {
  final Map<String, Object?> reading;
  final VoidCallback onTap;

  const _LatestReadingCard({required this.reading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final measured = DateTime.parse(reading['tested_at'] as String).toLocal();
    final isDemo = reading['source'] == 'simulated';
    final synced = reading['sync_status'] == 'synced';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.query_stats_rounded,
                    size: 18, color: FertaColors.leaf),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    reading['field_name'] as String? ?? 'Field',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (isDemo)
                  _SourceBadge(label: localized(context, 'DEMO', 'செய்முறை')),
              ]),
              const SizedBox(height: 4),
              Text(
                measured.toString().substring(0, 16) +
                    ' · ' +
                    localized(
                      context,
                      synced ? 'Synced' : 'Saved on device',
                      synced
                          ? 'ஒத்திசைக்கப்பட்டது'
                          : 'சாதனத்தில் சேமிக்கப்பட்டது',
                    ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _NutrientMetric(
                      label: 'N',
                      value: reading['n'],
                      color: FertaColors.nitrogen),
                  _NutrientMetric(
                      label: 'P',
                      value: reading['p'],
                      color: FertaColors.phosphorus),
                  _NutrientMetric(
                      label: 'K',
                      value: reading['k'],
                      color: FertaColors.potassium),
                  Text(reading['unit'] as String,
                      style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutrientMetric extends StatelessWidget {
  final String label;
  final Object? value;
  final Color color;

  const _NutrientMetric(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Row(
          children: [
            Container(
              width: 27,
              height: 27,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .1), shape: BoxShape.circle),
              child: Text(label,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: value is num
                  ? FertaAnimatedNumber(
                      value: value as num,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontSize: 16),
                    )
                  : Text(value?.toString() ?? '—',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontSize: 16)),
            ),
          ],
        ),
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: FertaColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        ),
      );
}

void _notice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(message)));

class TerraceGardeningScreen extends StatefulWidget {
  const TerraceGardeningScreen({super.key});
  @override
  State<TerraceGardeningScreen> createState() => _TerraceGardeningScreenState();
}

class _TerraceGardeningScreenState extends State<TerraceGardeningScreen> {
  static const steps = [
    'Choose a stable, well-drained growing area',
    'Check sunlight across the day',
    'Choose containers with drainage holes',
    'Use a clean growing medium and compost',
    'Start with a few easy-to-manage plants',
    'Check leaves regularly and harvest gently'
  ];
  String space = 'Small balcony',
      sunlight = 'Not sure',
      experience = 'Beginner',
      budget = 'Low';
  List<String> checked = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await LocalStore.instance.terraceProgress();
    final raw = jsonDecode(p['checklist'] as String);
    if (!mounted) return;
    setState(() {
      space = p['space'] as String;
      sunlight = p['sunlight'] as String;
      experience = p['experience'] as String;
      budget = p['budget'] as String;
      checked = raw is List ? raw.whereType<String>().toList() : [];
    });
  }

  Future<void> _save() => LocalStore.instance.saveTerraceProgress(
      space: space,
      sunlight: sunlight,
      experience: experience,
      budget: budget,
      checklist: checked);
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const AppText('Terrace gardening')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [FertaColors.forest, FertaColors.leaf]),
                  borderRadius: BorderRadius.circular(24)),
              child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.yard, color: FertaColors.lime, size: 34),
                    SizedBox(height: 12),
                    Text('Grow at your pace',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text(
                        'Begin with a few containers. Check local weather, roof load and seasonal advice before planting.',
                        style: TextStyle(color: Colors.white, height: 1.4))
                  ])),
          const SizedBox(height: 18),
          const Text('Your space',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          _choice(
              'Available space',
              space,
              ['Small balcony', 'Medium terrace', 'Large terrace'],
              (v) => space = v),
          _choice(
              'Direct sunlight',
              sunlight,
              ['Not sure', 'Under 3 hours', '3–6 hours', 'Over 6 hours'],
              (v) => sunlight = v),
          _choice(
              'Experience',
              experience,
              ['Beginner', 'Some experience', 'Experienced'],
              (v) => experience = v),
          _choice('Budget', budget, ['Low', 'Moderate', 'Flexible'],
              (v) => budget = v),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your starting plan',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('$space · $sunlight · $experience · $budget budget'),
                    const SizedBox(height: 6),
                    const Text(
                        'Start with a manageable number of containers, observe sunlight and drainage, and confirm planting dates with a local seasonal source.'),
                  ]),
            ),
          ),
          const SizedBox(height: 16),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Beginner checklist',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                              begin: 0, end: checked.length / steps.length),
                          duration: const Duration(milliseconds: 300),
                          builder: (context, value, _) =>
                              LinearProgressIndicator(
                                  value: value,
                                  minHeight: 7,
                                  borderRadius: BorderRadius.circular(8)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                            '${checked.length} of ${steps.length} steps complete',
                            style: Theme.of(context).textTheme.bodySmall),
                        ...steps.map((step) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: checked.contains(step),
                            title: Text(step),
                            onChanged: (value) async {
                              setState(() {
                                if (value == true) {
                                  checked.add(step);
                                } else {
                                  checked.remove(step);
                                }
                              });
                              await _save();
                            }))
                      ]))),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Starter crop ideas',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text(
                            'Leafy greens, coriander, mint and chilli are common home-garden choices. Match the crop to your local season and sunlight; container size, watering and duration vary by variety and climate. Follow a local horticulture guide or seed packet for specifics.'),
                        SizedBox(height: 12),
                        Text(
                            'Use containers with drainage. Water when the growing medium needs it; avoid leaving roots waterlogged. Compost is useful, but fertilizer amounts depend on the medium and crop.')
                      ]))),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Common problems',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text(
                            'Avoid overwatering, overcrowding and placing heavy wet pots where roof capacity is uncertain. Inspect leaves often. For pests or disease, take clear photos and seek a local horticulture adviser; this app has no image diagnosis service configured.')
                      ]))),
        ]),
      );

  Widget _choice(String label, String value, List<String> values,
          ValueChanged<String> setValue) =>
      DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: values
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (next) async {
            if (next == null) return;
            setState(() => setValue(next));
            await _save();
          });
}

class CropDemandScreen extends StatefulWidget {
  const CropDemandScreen({super.key});
  @override
  State<CropDemandScreen> createState() => _CropDemandScreenState();
}

class _CropDemandScreenState extends State<CropDemandScreen> {
  static const crops = [
    'Rice',
    'Maize',
    'Groundnut',
    'Cotton',
    'Millet',
    'Tomato',
    'Banana',
    'Pulses',
    'Potato',
    'Onion'
  ];
  List<String> saved = [];
  String type = 'All';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await LocalStore.instance.savedCrops();
    if (mounted) setState(() => saved = values);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const AppText('Crops in demand')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Card(
            color: FertaColors.warningLight,
            child: const ListTile(
                leading: Icon(Icons.info_outline, color: FertaColors.warning),
                title: Text('Market demand feed unavailable'),
                subtitle: Text(
                    'No market source is configured. We do not have verified demand, prices, update dates, or regional suitability to show.'))),
        const Text('Crop information shortlist',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Padding(
            padding: EdgeInsets.only(top: 6, bottom: 14),
            child: Text(
                'These are crop names for your own research, not demand rankings or recommendations. Compare local season, water, soil, budget and buyer access before choosing.')),
        DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Crop type'),
            items: const [
              'All',
              'Cereal',
              'Pulse',
              'Oilseed',
              'Vegetable',
              'Other'
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => type = v ?? 'All')),
        const SizedBox(height: 12),
        ...crops.where((crop) => type == 'All' || _matches(crop, type)).map(
            (crop) => Card(
                child: ListTile(
                    leading: CircleAvatar(
                        backgroundColor: FertaColors.leafLight,
                        child:
                            const Icon(Icons.eco, color: FertaColors.forest)),
                    title: Text(crop),
                    subtitle: const Text(
                        'Market demand: unavailable · Local season and requirements: check with a regional source'),
                    trailing: IconButton(
                        tooltip: saved.contains(crop)
                            ? 'Remove from shortlist'
                            : 'Save crop',
                        icon: Icon(saved.contains(crop)
                            ? Icons.bookmark
                            : Icons.bookmark_border),
                        onPressed: () async {
                          await LocalStore.instance
                              .setCropSaved(crop, !saved.contains(crop));
                          await _load();
                        })))),
        if (saved.isNotEmpty) Text('Saved shortlist: ${saved.join(', ')}'),
      ]));
  bool _matches(String crop, String selected) => switch (selected) {
        'Cereal' => ['Rice', 'Maize', 'Millet'].contains(crop),
        'Pulse' => crop == 'Pulses',
        'Oilseed' => crop == 'Groundnut',
        'Vegetable' => ['Tomato', 'Potato', 'Onion'].contains(crop),
        _ => crop == 'Cotton' || crop == 'Banana',
      };
}

class ExpertDashboardScreen extends StatelessWidget {
  const ExpertDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const AppText('Expert support')),
      body: ListView(padding: const EdgeInsets.all(20), children: const [
        Card(
            child: ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Expert workspace needs a backend'),
                subtitle: Text(
                    'This app has no verified expert roles, farmer request queue, appointments, or messaging API. No real farmer requests are available on this device.'))),
        Card(
            child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What is needed for a live dashboard',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 10),
                      Text(
                          'Add authenticated expert accounts and role checks, user-scoped farmer support requests, secure image upload and storage, conversation endpoints, appointment records and availability, and audit controls. Keep this local-only app in farmer mode until that service is configured.')
                    ]))),
      ]));
}
