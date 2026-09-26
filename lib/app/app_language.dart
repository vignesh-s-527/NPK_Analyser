import 'package:flutter/widgets.dart';

class AppLanguage {
  static final locale = ValueNotifier<Locale>(const Locale('en'));
  static void select(String languageCode) => locale.value = Locale(languageCode);
}

String localized(BuildContext context, String english, String tamil) =>
    Localizations.localeOf(context).languageCode == 'ta' ? tamil : english;

String localizedPageText(BuildContext context, String value) {
  const tamil = <String, String>{
    'Good morning, Farmer': 'வணக்கம், விவசாயி',
    'Your farm at a glance': 'உங்கள் பண்ணையின் சுருக்கம்',
    'Soil testing': 'மண் பரிசோதனை',
    'Connect your analyzer and test a field': 'கருவியை இணைத்து வயலைப் பரிசோதிக்கவும்',
    'Crops & calendar': 'பயிர்கள் மற்றும் நாள்காட்டி',
    'Plan your next season': 'அடுத்த பருவத்தைத் திட்டமிடுங்கள்',
    'AI Assistant': 'AI உதவியாளர்',
    'Ask a question about your farm': 'உங்கள் பண்ணையைப் பற்றி கேளுங்கள்',
    'Profile & settings': 'சுயவிவரம் மற்றும் அமைப்புகள்',
    'Your information stays on this device': 'உங்கள் தகவல்கள் இந்தச் சாதனத்தில் இருக்கும்',
  };
  return localized(context, value, tamil[value] ?? value);
}
