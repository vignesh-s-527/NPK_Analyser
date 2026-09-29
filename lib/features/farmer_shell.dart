import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_language.dart';
import 'screens.dart';
import '../services/contracts.dart';

class FarmerShell extends StatefulWidget {
  final FarmerServices services;
  const FarmerShell({super.key, this.services = const FarmerServices()});

  @override
  State<FarmerShell> createState() => _FarmerShellState();
}

class _FarmerShellState extends State<FarmerShell> {
  int index = 0;

  late final pages = [
    HomeScreen(
      weatherService: widget.services.weather,
      calendarService: widget.services.calendar,
      recommendationService: widget.services.cropRecommendations,
      reminderService: widget.services.reminders,
      npkDevice: widget.services.npkDevice,
      readingSubmission: widget.services.readingSubmission,
      fertilizerAdviceService: widget.services.fertilizerAdvice,
      assistantService: widget.services.assistant,
      onNavigate: (value) => setState(() => index = value),
    ),
    SoilScreen(
      service: widget.services.npkDevice,
      readingSubmission: widget.services.readingSubmission,
    ),
    AssistantScreen(service: widget.services.assistant),
    FarmManagementScreen(
      readingSubmission: widget.services.readingSubmission,
    ),
    ProfileScreen(
      calendarConnected: widget.services.calendar != null,
      remindersConnected: widget.services.reminders != null,
      calendarService: widget.services.calendar,
      reminderService: widget.services.reminders,
      readingSubmission: widget.services.readingSubmission,
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: List.generate(pages.length, (pageIndex) {
            final selected = index == pageIndex;
            return AnimatedOpacity(
              key: ValueKey(pageIndex),
              opacity: selected ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: IgnorePointer(
                ignoring: !selected,
                child: TickerMode(
                  enabled: selected,
                  child: ExcludeSemantics(
                    excluding: !selected,
                    child: pages[pageIndex],
                  ),
                ),
              ),
            );
          }),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) {
            if (value == index) return;
            HapticFeedback.selectionClick();
            setState(() => index = value);
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: localized(context, 'Home', 'முகப்பு'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.science_outlined),
              selectedIcon: const Icon(Icons.science_rounded),
              label: localized(context, 'Soil tests', 'மண் பரிசோதனை'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.forum_outlined),
              selectedIcon: const Icon(Icons.forum_rounded),
              label: localized(context, 'Assistant', 'உதவியாளர்'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.agriculture_outlined),
              selectedIcon: const Icon(Icons.agriculture_rounded),
              label: localized(context, 'Farms', 'பண்ணைகள்'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person_rounded),
              label: localized(context, 'Profile', 'சுயவிவரம்'),
            ),
          ],
        ),
      );
}
