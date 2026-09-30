import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_language.dart';
import 'ferta_theme.dart';
import '../data/local_store.dart';
import '../features/farmer_shell.dart';
import '../services/contracts.dart';

final GlobalKey<NavigatorState> fertaNavigatorKey = GlobalKey<NavigatorState>();

class NpkApp extends StatelessWidget {
  final FarmerServices services;
  const NpkApp({super.key, this.services = const FarmerServices()});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale>(
        valueListenable: AppLanguage.locale,
        builder: (context, locale, _) => MaterialApp(
          navigatorKey: fertaNavigatorKey,
          title: 'FERTA',
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('ta')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate
          ],
          theme: buildFertaTheme(),
          home: LaunchScreen(services: services),
        ),
      );
}

class LaunchScreen extends StatelessWidget {
  final FarmerServices services;
  const LaunchScreen({super.key, this.services = const FarmerServices()});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 520),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) => Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 16 * (1 - value)),
                            child: child,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              height: 210,
                              decoration: BoxDecoration(
                                color: const Color(0xff173f35),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    right: -24,
                                    bottom: -54,
                                    child: Icon(Icons.eco_outlined,
                                        size: 210,
                                        color: Colors.white
                                            .withValues(alpha: .08)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: const Color(0xffd8e8a8),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: const Icon(Icons.grass,
                                              color: Color(0xff173f35),
                                              size: 30),
                                        ),
                                        const SizedBox(height: 24),
                                        const AppText('FERTA',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 32,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.2,
                                            )),
                                        const AppText(
                                          'Know your soil. Grow with confidence.',
                                          style: TextStyle(
                                              color: Color(0xffdbe8dd),
                                              fontSize: 15),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              localized(context, 'A clearer view of your soil',
                                  'உங்கள் மண்ணைத் தெளிவாக அறியுங்கள்'),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              localized(
                                context,
                                'Keep farm records, review NPK readings and get grounded guidance in one place.',
                                'பண்ணை பதிவுகள், NPK அளவீடுகள் மற்றும் நம்பகமான வழிகாட்டுதலை ஒரே இடத்தில் பாருங்கள்.',
                              ),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 28),
                            FilledButton.icon(
                              onPressed: () async {
                                final profile =
                                    await LocalStore.instance.profile();
                                if (!context.mounted) return;
                                final done =
                                    (profile?['tutorial_done'] as int?) == 1;
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => done
                                        ? FarmerShell(services: services)
                                        : TutorialScreen(services: services),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.agriculture_outlined),
                              label: const AppText('Continue as Farmer'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                final builder = services.expertDashboardBuilder;
                                if (builder == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: AppText(
                                        'The agricultural expert dashboard has not been connected yet.',
                                      ),
                                    ),
                                  );
                                } else {
                                  Navigator.of(context).push(
                                      MaterialPageRoute(builder: builder));
                                }
                              },
                              icon: const Icon(Icons.support_agent_outlined),
                              label: const AppText('Agricultural Expert'),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              localized(
                                  context,
                                  'Works on this device without an account',
                                  'கணக்கு இல்லாமலும் இந்த சாதனத்தில் பயன்படுத்தலாம்'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: const Color(0xff68766d)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class TutorialScreen extends StatefulWidget {
  final FarmerServices services;
  const TutorialScreen({super.key, this.services = const FarmerServices()});
  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final controller = PageController();
  int page = 0;
  static const items = [
    (
      Icons.bluetooth_searching,
      'Connect your analyzer',
      'Turn on your NPK device and connect to it from Soil. You will connect manually each time.'
    ),
    (
      Icons.grass,
      'Collect and test soil',
      'Collect a representative soil sample, prepare it as instructed by your analyzer, then start a test.'
    ),
    (
      Icons.science,
      'Review your NPK results',
      'When the measurement finishes, review the final nitrogen, phosphorus and potassium results.'
    ),
    (
      Icons.eco,
      'Plan with recommendations',
      'Choose crops and view farming recommendations when the crop and calendar services are connected.'
    )
  ];
  Future<void> finish() async {
    await LocalStore.instance.markTutorialDone();
    if (mounted)
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => FarmerShell(services: widget.services)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(actions: [
        TextButton(onPressed: finish, child: const AppText('Skip'))
      ]),
      body: Column(children: [
        Expanded(
            child: PageView.builder(
                controller: controller,
                itemCount: items.length,
                onPageChanged: (v) => setState(() => page = v),
                itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(items[index].$1,
                              size: 86,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 28),
                          AppText(items[index].$2,
                              style: Theme.of(context).textTheme.headlineSmall,
                              textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          AppText(items[index].$3,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge)
                        ])))),
        Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                items.length,
                (i) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == page
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black26)))),
        Padding(
            padding: const EdgeInsets.all(20),
            child: FilledButton(
                onPressed: page == items.length - 1
                    ? finish
                    : () => controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut),
                child:
                    AppText(page == items.length - 1 ? 'Get started' : 'Next')))
      ]));
}
