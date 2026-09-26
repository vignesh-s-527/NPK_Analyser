import 'package:flutter/material.dart';
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
        reminderService: widget.services.reminders),
    SoilScreen(service: widget.services.npkDevice),
    CropsScreen(
        recommendationService: widget.services.cropRecommendations,
        calendarService: widget.services.calendar,
        reminderService: widget.services.reminders),
    AssistantScreen(service: widget.services.assistant),
    ProfileScreen(
        calendarConnected: widget.services.calendar != null,
        remindersConnected: widget.services.reminders != null,
        calendarService: widget.services.calendar,
        reminderService: widget.services.reminders)
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(key: ValueKey(index), child: pages[index])),
        bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            destinations: [
              NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: localized(context, 'Home', 'முகப்பு')),
              NavigationDestination(
                  icon: const Icon(Icons.science_outlined),
                  label: localized(context, 'Soil', 'மண்')),
              NavigationDestination(
                  icon: const Icon(Icons.spa_outlined),
                  label: localized(context, 'Crops', 'பயிர்கள்')),
              NavigationDestination(
                  icon: const Icon(Icons.forum_outlined),
                  label: localized(context, 'AI Assistant', 'AI உதவியாளர்')),
              NavigationDestination(
                  icon: const Icon(Icons.person_outline),
                  label: localized(context, 'Profile', 'சுயவிவரம்'))
            ]),
      );
}
