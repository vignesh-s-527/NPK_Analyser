import 'package:flutter/material.dart';
import 'app/npk_app.dart';
import 'app/app_language.dart';
import 'data/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.instance.initialize();
  final profile = await LocalStore.instance.profile();
  AppLanguage.select((profile?['language'] as String?) ?? 'en');
  runApp(const NpkApp());
}
