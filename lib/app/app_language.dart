import 'package:flutter/material.dart';

class AppLanguage {
  static final locale = ValueNotifier<Locale>(const Locale('en'));

  static void select(String languageCode) {
    final supported = languageCode == 'ta' ? 'ta' : 'en';
    locale.value = Locale(supported);
  }
}

String localized(BuildContext context, String english, String tamil) =>
    Localizations.localeOf(context).languageCode == 'ta' ? tamil : english;

String translateAppText(BuildContext context, String value) {
  if (Localizations.localeOf(context).languageCode != 'ta') return value;
  final exact = _tamilText[value];
  if (exact != null) return exact;

  final recommendedCrop = value.startsWith('Recommended crop: ');
  if (recommendedCrop) {
    return 'பரிந்துரைக்கப்படும் பயிர்: ${value.substring('Recommended crop: '.length)}';
  }
  if (value.startsWith('Battery ')) {
    return 'மின்கலம் ${value.substring('Battery '.length)}';
  }
  if (value.endsWith(' photos')) {
    return '${value.substring(0, value.length - ' photos'.length)} புகைப்படங்கள்';
  }
  if (value.endsWith(' history')) {
    return '${value.substring(0, value.length - ' history'.length)} வரலாறு';
  }
  final farmCounts =
      RegExp(r'^(\d+) farms? \| (\d+) fields?$').firstMatch(value);
  if (farmCounts != null) {
    return '${farmCounts[1]} பண்ணைகள் | ${farmCounts[2]} வயல்கள்';
  }

  var translated = value;
  for (final entry in _tamilText.entries) {
    if (entry.key.length > 12 && translated.contains(entry.key)) {
      translated = translated.replaceAll(entry.key, entry.value);
    }
  }
  translated = translated
      .replaceAll('Cost:', 'செலவு:')
      .replaceAll('Yield:', 'விளைச்சல்:')
      .replaceAll('Market price:', 'சந்தை விலை:')
      .replaceAll('Potential profit:', 'சாத்தியமான லாபம்:');
  return translated;
}

String localizedPageText(BuildContext context, String value) =>
    translateAppText(context, value);

/// Text wrapper for app-owned copy. Keeping localization at the widget level
/// means existing screens and open dialogs rebuild immediately when locale
/// changes, without translating user-entered names or assistant responses.
class AppText extends StatelessWidget {
  final String data;
  final bool translate;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  const AppText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.translate = true,
  });

  @override
  Widget build(BuildContext context) => Text(
        translate ? translateAppText(context, data) : data,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel == null || !translate
            ? semanticsLabel
            : translateAppText(context, semanticsLabel!),
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
}

const _tamilText = <String, String>{
  'FERTA': 'FERTA',
  'No farms yet. Add a farm and field to get started.':
      'பண்ணைகள் இல்லை. தொடங்க பண்ணையையும் வயலையும் சேர்க்கவும்.',
  'Add a field to view history': 'வரலாற்றைப் பார்க்க வயலைச் சேர்க்கவும்',
  'Select a field to view its saved soil history.':
      'சேமித்த மண் வரலாற்றைப் பார்க்க வயலைத் தேர்ந்தெடுக்கவும்.',
  'Select a field to view soil history.':
      'மண் வரலாற்றைப் பார்க்க வயலைத் தேர்ந்தெடுக்கவும்.',
  'Weather service not connected': 'வானிலைச் சேவை இணைக்கப்படவில்லை',
  'Weather data is unavailable until a weather provider is configured.':
      'வானிலை வழங்குநர் அமைக்கப்படும் வரை வானிலைத் தரவு கிடைக்காது.',
  'Weather unavailable': 'வானிலை கிடைக்கவில்லை',
  'Could not load current weather. Check the provider configuration and try again.':
      'தற்போதைய வானிலையை ஏற்ற முடியவில்லை. வழங்குநர் அமைப்பைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
  'Current conditions': 'தற்போதைய நிலை',
  'Refresh weather': 'வானிலையைப் புதுப்பி',
  'Calendar service not connected': 'நாள்காட்டிச் சேவை இணைக்கப்படவில்லை',
  'Calendar entries are unavailable until a farming calendar provider is configured.':
      'விவசாய நாள்காட்டி வழங்குநர் அமைக்கப்படும் வரை நிகழ்வுகள் கிடைக்காது.',
  'Calendar unavailable': 'நாள்காட்டி கிடைக்கவில்லை',
  'Could not load activities. Check the calendar provider and try again.':
      'செயல்பாடுகளை ஏற்ற முடியவில்லை. நாள்காட்டி வழங்குநரைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
  'No activities yet': 'செயல்பாடுகள் இன்னும் இல்லை',
  'No activities were returned for this farm. Sowing, irrigation, fertilizer and harvest entries will appear when supplied by the calendar integration.':
      'இந்தப் பண்ணைக்கு செயல்பாடுகள் இல்லை. நாள்காட்டி இணைப்பு வழங்கும்போது விதைத்தல், நீர்ப்பாசனம், உரமிடுதல் மற்றும் அறுவடை பதிவுகள் தோன்றும்.',
  'Calendar is connected, but reminders are not configured.':
      'நாள்காட்டி இணைக்கப்பட்டுள்ளது; நினைவூட்டல்கள் அமைக்கப்படவில்லை.',
  'Set reminder': 'நினைவூட்டலை அமை',
  'Reminder scheduled.': 'நினைவூட்டல் அமைக்கப்பட்டது.',
  'Could not schedule reminder.': 'நினைவூட்டலை அமைக்க முடியவில்லை.',
  'Soil result details': 'மண் முடிவு விவரங்கள்',
  'Nitrogen (N)': 'நைட்ரஜன் (N)',
  'Phosphorus (P)': 'பாஸ்பரஸ் (P)',
  'Potassium (K)': 'பொட்டாசியம் (K)',
  'Saved result': 'சேமித்த முடிவு',
  'Stored on this device': 'இந்தச் சாதனத்தில் சேமிக்கப்பட்டது',
  'Favorite result': 'விருப்பமான முடிவு',
  'AI service not connected': 'AI சேவை இணைக்கப்படவில்லை',
  'Configure an AiAssistantService backend to send questions. No sample answers are generated.':
      'கேள்விகளை அனுப்ப AiAssistantService பின்தளத்தை அமைக்கவும். மாதிரி பதில்கள் உருவாக்கப்படாது.',
  'Farming reminders': 'விவசாய நினைவூட்டல்கள்',
  'Reminders can be scheduled for events supplied by your calendar integration.':
      'நாள்காட்டி இணைப்பு வழங்கும் நிகழ்வுகளுக்கு நினைவூட்டல்களை அமைக்கலாம்.',
  'Calendar entries and reminders require integrations configured by the app provider. No calendar is connected.':
      'நாள்காட்டி நிகழ்வுகளுக்கும் நினைவூட்டல்களுக்கும் செயலி வழங்குநரின் இணைப்புகள் தேவை. நாள்காட்டி இணைக்கப்படவில்லை.',
  'Open farming calendar': 'விவசாய நாள்காட்டியைத் திற',
  'NPK Soil Analyzer': 'NPK மண் பகுப்பாய்வி',
  'Healthy soil. Confident farming.': 'ஆரோக்கியமான மண். நம்பிக்கையான விவசாயம்.',
  'Continue as Farmer': 'விவசாயியாகத் தொடரவும்',
  'Agricultural Expert': 'வேளாண் நிபுணர்',
  'The agricultural expert dashboard has not been connected yet.':
      'வேளாண் நிபுணர் பலகை இன்னும் இணைக்கப்படவில்லை.',
  'The assistant could not answer right now. You can contact an agricultural expert.':
      'உதவியாளர் இப்போது பதிலளிக்க முடியவில்லை. வேளாண் நிபுணரைத் தொடர்புகொள்ளலாம்.',
  'Connect your analyzer': 'உங்கள் பகுப்பாய்வியை இணைக்கவும்',
  'Turn on your NPK device and connect to it from Soil. You will connect manually each time.':
      'உங்கள் NPK சாதனத்தை இயக்கி, மண் திரையில் இருந்து இணைக்கவும். ஒவ்வொரு முறையும் கைமுறையாக இணைக்க வேண்டும்.',
  'Collect and test soil': 'மண்ணைச் சேகரித்து பரிசோதிக்கவும்',
  'Collect a representative soil sample, prepare it as instructed by your analyzer, then start a test.':
      'மாதிரியாக இருக்கும் மண் மாதிரியைச் சேகரித்து, சாதனத்தின் அறிவுறுத்தலின்படி தயார் செய்து பரிசோதனையைத் தொடங்கவும்.',
  'Review your NPK results': 'உங்கள் NPK முடிவுகளைப் பாருங்கள்',
  'When the measurement finishes, review the final nitrogen, phosphorus and potassium results.':
      'அளவீடு முடிந்ததும் நைட்ரஜன், பாஸ்பரஸ், பொட்டாசியம் முடிவுகளைப் பாருங்கள்.',
  'Plan with recommendations': 'பரிந்துரைகளுடன் திட்டமிடுங்கள்',
  'Choose crops and view farming recommendations when the crop and calendar services are connected.':
      'பயிர் மற்றும் நாள்காட்டி சேவைகள் இணைக்கப்பட்டதும் பயிர்களைத் தேர்ந்தெடுத்து விவசாயப் பரிந்துரைகளைப் பாருங்கள்.',
  'Skip': 'தவிர்',
  'Get started': 'தொடங்கவும்',
  'Next': 'அடுத்து',
  'Home': 'முகப்பு',
  'Soil': 'மண்',
  'Crops': 'பயிர்கள்',
  'Crops & calendar': 'பயிர்கள் மற்றும் நாள்காட்டி',
  'AI Assistant': 'AI உதவியாளர்',
  'Profile': 'சுயவிவரம்',
  'Profile & settings': 'சுயவிவரம் மற்றும் அமைப்புகள்',
  'Good morning, Farmer': 'காலை வணக்கம், விவசாயி',
  'Your farm at a glance': 'உங்கள் பண்ணையின் சுருக்கம்',
  'Farms & fields': 'பண்ணைகள் மற்றும் வயல்கள்',
  'Latest soil results': 'சமீபத்திய மண் முடிவுகள்',
  'Saved soil results will appear here.':
      'சேமித்த மண் பரிசோதனை முடிவுகள் இங்கே தோன்றும்.',
  'Weather': 'வானிலை',
  'Weather service will be connected here.': 'வானிலை சேவை இங்கே இணைக்கப்படும்.',
  'Weather is unavailable right now.': 'வானிலை விவரம் இப்போது கிடைக்கவில்லை.',
  'Partly cloudy': 'ஓரளவு மேகமூட்டம்',
  'Mostly cloudy': 'பெரும்பாலும் மேகமூட்டம்',
  'Cloudy': 'மேகமூட்டம்',
  'Overcast': 'முழு மேகமூட்டம்',
  'Light rain': 'லேசான மழை',
  'Heavy rain': 'கனமழை',
  'Clear': 'தெளிவான வானம்',
  'Loading weather...': 'வானிலை விவரம் ஏற்றப்படுகிறது...',
  'Crop recommendations': 'பயிர் பரிந்துரைகள்',
  'Crop recommendation service will be connected here.':
      'பயிர் பரிந்துரை சேவை இங்கே இணைக்கப்படும்.',
  'Recommendations could not be loaded.': 'பரிந்துரைகளை ஏற்ற முடியவில்லை.',
  'Recommended crop: ': 'பரிந்துரைக்கப்படும் பயிர்: ',
  'Cost, yield, market price and potential profit are estimates.':
      'செலவு, விளைச்சல், சந்தை விலை மற்றும் சாத்தியமான லாபம் ஆகியவை மதிப்பீடுகள்.',
  'Upcoming activities': 'வரவிருக்கும் பணிகள்',
  'Calendar service will be connected here.':
      'நாள்காட்டி சேவை இங்கே இணைக்கப்படும்.',
  'Calendar events could not be loaded.':
      'நாள்காட்டி நிகழ்வுகளை ஏற்ற முடியவில்லை.',
  'No upcoming events.': 'வரவிருக்கும் நிகழ்வுகள் இல்லை.',
  'Soil testing': 'மண் பரிசோதனை',
  'Connect your analyzer and test a field':
      'பகுப்பாய்வியை இணைத்து வயலைப் பரிசோதிக்கவும்',
  'The BLE adapter will be supplied by the device integration.':
      'சாதன இணைப்பு மூலம் BLE அடாப்டர் வழங்கப்படும்.',
  'Could not scan for devices. Check Bluetooth permissions and try again.':
      'சாதனங்களைத் தேட முடியவில்லை. Bluetooth அனுமதியைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
  'Could not connect. Turn on the analyzer and keep it nearby, then retry.':
      'இணைக்க முடியவில்லை. பகுப்பாய்வியை இயக்கி அருகில் வைத்து மீண்டும் முயற்சிக்கவும்.',
  'Save device': 'சாதனத்தைச் சேமி',
  'Device name': 'சாதனத்தின் பெயர்',
  'Cancel': 'ரத்து செய்',
  'Save': 'சேமி',
  'Device saved. It will still need manual connection next time.':
      'சாதனம் சேமிக்கப்பட்டது. அடுத்த முறை கைமுறையாக இணைக்க வேண்டும்.',
  'Save soil test?': 'மண் பரிசோதனை முடிவைச் சேமிக்கவா?',
  'Save this successful result to the selected field?':
      'இந்த வெற்றிகரமான முடிவைத் தேர்ந்தெடுத்த வயலில் சேமிக்கவா?',
  'Discard': 'நிராகரி',
  'Save result': 'முடிவைச் சேமி',
  'Choose a field before starting a test. This result was not saved.':
      'பரிசோதனையைத் தொடங்குவதற்கு முன் வயலைத் தேர்ந்தெடுக்கவும். இந்த முடிவு சேமிக்கப்படவில்லை.',
  'Test field': 'பரிசோதனை வயல்',
  'Searching…': 'தேடுகிறது…',
  'Find NPK device': 'NPK சாதனத்தைக் கண்டறி',
  'Stop search': 'தேடலை நிறுத்து',
  'NPK device': 'NPK சாதனம்',
  'Connect': 'இணை',
  'Save device name': 'சாதனப் பெயரைச் சேமி',
  'Device connected': 'சாதனம் இணைக்கப்பட்டது',
  'Ready to test': 'பரிசோதனைக்குத் தயார்',
  'Battery ': 'மின்கலம் ',
  'Disconnect': 'துண்டி',
  'Connection or test issue': 'இணைப்பு அல்லது பரிசோதனைச் சிக்கல்',
  'Testing in progress.': 'பரிசோதனை நடைபெறுகிறது.',
  'Start soil test': 'மண் பரிசோதனையைத் தொடங்கு',
  'Test could not start. Check the sample, device connection and battery, then try again.':
      'பரிசோதனையைத் தொடங்க முடியவில்லை. மாதிரி, சாதன இணைப்பு மற்றும் மின்கலத்தைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
  'Add a field first': 'முதலில் வயலைச் சேர்க்கவும்',
  'Create a farm and field in Profile before saving soil test results.':
      'மண் பரிசோதனை முடிவுகளைச் சேமிப்பதற்கு முன் சுயவிவரத்தில் பண்ணையையும் வயலையும் சேர்க்கவும்.',
  'Field history': 'வயல் வரலாறு',
  'Successful tests are saved only after you choose Save result.':
      'முடிவைச் சேமி என்பதைத் தேர்ந்தெடுத்த பிறகே வெற்றிகரமான பரிசோதனைகள் சேமிக்கப்படும்.',
  'Add a farm first': 'முதலில் பண்ணையைச் சேர்க்கவும்',
  'Create a farm in Profile to save crop selections.':
      'பயிர் தேர்வுகளைச் சேமிக்க சுயவிவரத்தில் பண்ணையைச் சேர்க்கவும்.',
  'Farm': 'பண்ணை',
  'Selected crops': 'தேர்ந்தெடுத்த பயிர்கள்',
  'Choose crops for this farm.':
      'இந்தப் பண்ணைக்கான பயிர்களைத் தேர்ந்தெடுக்கவும்.',
  'Estimates only, not guarantees.':
      'இவை மதிப்பீடுகள் மட்டுமே; உறுதியான பலன்கள் அல்ல.',
  'unavailable': 'கிடைக்கவில்லை',
  'Farming calendar': 'விவசாய நாள்காட்டி',
  'Recommendation service is not connected yet.':
      'பரிந்துரை சேவை இன்னும் இணைக்கப்படவில்லை.',
  'Recommendations could not be loaded. Try again later.':
      'பரிந்துரைகளை ஏற்ற முடியவில்லை. பின்னர் மீண்டும் முயற்சிக்கவும்.',
  'No recommendations are available yet.':
      'இன்னும் பரிந்துரைகள் எதுவும் இல்லை.',
  'No upcoming events for this farm.':
      'இந்தப் பண்ணைக்கு வரவிருக்கும் நிகழ்வுகள் இல்லை.',
  'Calendar service is not connected yet.':
      'நாள்காட்டி சேவை இன்னும் இணைக்கப்படவில்லை.',
  'Ask a question about your farm': 'உங்கள் பண்ணையைப் பற்றி கேளுங்கள்',
  'Speech input is unavailable on this device.':
      'இந்தச் சாதனத்தில் குரல் உள்ளீடு கிடைக்கவில்லை.',
  'Could not start speech input.': 'குரல் உள்ளீட்டைத் தொடங்க முடியவில்லை.',
  'Could not save language preference.':
      'மொழி விருப்பத்தைச் சேமிக்க முடியவில்லை.',
  'Your request was sent to the expert service.':
      'உங்கள் கோரிக்கை நிபுணர் சேவைக்கு அனுப்பப்பட்டது.',
  'Expert contact is unavailable right now.':
      'நிபுணரைத் தொடர்புகொள்ளும் வசதி இப்போது கிடைக்கவில்லை.',
  'Sources: ': 'ஆதாரங்கள்: ',
  'Ask a question in English or Tamil':
      'ஆங்கிலம் அல்லது தமிழில் கேள்வி கேளுங்கள்',
  'Assistant service is not connected yet.':
      'உதவியாளர் சேவை இன்னும் இணைக்கப்படவில்லை.',
  'Ask a farming question to get started.':
      'தொடங்க விவசாயம் குறித்த கேள்வியைக் கேளுங்கள்.',
  'Contact an agricultural expert': 'வேளாண் நிபுணரைத் தொடர்புகொள்',
  'Type your question': 'உங்கள் கேள்வியைத் தட்டச்சு செய்யவும்',
  'Speak your question': 'உங்கள் கேள்வியைப் பேசவும்',
  'Ask': 'கேள்',
  'Farmer name': 'விவசாயியின் பெயர்',
  'Optional name': 'விருப்பமான பெயர்',
  'Guest farmer': 'விருந்தினர் விவசாயி',
  'Language': 'மொழி',
  'English': 'ஆங்கிலம்',
  'தமிழ்': 'தமிழ்',
  'Your information stays on this device':
      'உங்கள் தகவல்கள் இந்தச் சாதனத்திலேயே இருக்கும்',
  'Farm management': 'பண்ணை மேலாண்மை',
  'Manage farms, fields and locations':
      'பண்ணைகள், வயல்கள் மற்றும் இடங்களை நிர்வகிக்கவும்',
  'Saved devices': 'சேமித்த சாதனங்கள்',
  'Saved names for your analyzer devices':
      'உங்கள் பகுப்பாய்வி சாதனங்களின் சேமித்த பெயர்கள்',
  'Local data': 'சாதனத் தரவு',
  'Delete all locally stored farm data':
      'சாதனத்தில் சேமித்த பண்ணைத் தரவுகள் அனைத்தையும் நீக்கு',
  'Notifications': 'அறிவிப்புகள்',
  'Calendar reminders will be enabled when the calendar integration is connected.':
      'நாள்காட்டி இணைக்கப்பட்டதும் நினைவூட்டல்கள் செயல்படுத்தப்படும்.',
  'Notification settings': 'அறிவிப்பு அமைப்புகள்',
  'Calendar integration': 'நாள்காட்டி இணைப்பு',
  'Connected': 'இணைக்கப்பட்டுள்ளது',
  'Not connected': 'இணைக்கப்படவில்லை',
  'Reminders are scheduled automatically when calendar events are available.':
      'நாள்காட்டி நிகழ்வுகள் கிடைக்கும்போது நினைவூட்டல்கள் தானாகத் திட்டமிடப்படும்.',
  'Connect a calendar service to receive farming reminders.':
      'விவசாய நினைவூட்டல்களைப் பெற நாள்காட்டி சேவையை இணைக்கவும்.',
  'Add farm': 'பண்ணையைச் சேர்',
  'Edit farm': 'பண்ணையைத் திருத்து',
  'Farm name *': 'பண்ணையின் பெயர் *',
  'Location (optional)': 'இடம் (விருப்பம்)',
  'Location permission was not granted. You can enter the location manually.':
      'இருப்பிட அனுமதி வழங்கப்படவில்லை. இருப்பிடத்தை கைமுறையாக உள்ளிடலாம்.',
  'GPS location': 'GPS இருப்பிடம்',
  'GPS location captured.': 'GPS இருப்பிடம் பெறப்பட்டது.',
  'Could not get GPS location. Enter the location manually.':
      'GPS இருப்பிடத்தைப் பெற முடியவில்லை. இருப்பிடத்தை கைமுறையாக உள்ளிடவும்.',
  'Use current location': 'தற்போதைய இருப்பிடத்தைப் பயன்படுத்து',
  'Delete this farm and all its fields and soil history?':
      'இந்தப் பண்ணையையும் அதன் வயல்கள் மற்றும் மண் பரிசோதனை வரலாற்றையும் நீக்கவா?',
  'No farms yet. Add your first farm.':
      'பண்ணைகள் இல்லை. உங்கள் முதல் பண்ணையைச் சேர்க்கவும்.',
  'Location not set': 'இருப்பிடம் அமைக்கப்படவில்லை',
  'Edit': 'திருத்து',
  'Photos': 'புகைப்படங்கள்',
  'Add field': 'வயலைச் சேர்',
  'Delete': 'நீக்கு',
  'No fields yet': 'வயல்கள் இல்லை',
  'Area not set | Tap to view soil history':
      'பரப்பளவு குறிப்பிடப்படவில்லை | மண் வரலாற்றைப் பார்க்கத் தட்டவும்',
  'Tap to view soil history': 'மண் வரலாற்றைப் பார்க்கத் தட்டவும்',
  'Edit field': 'வயலைத் திருத்து',
  'Field photos': 'வயல் புகைப்படங்கள்',
  'Delete field': 'வயலை நீக்கு',
  'Field name *': 'வயலின் பெயர் *',
  'Area (optional)': 'பரப்பளவு (விருப்பம்)',
  'Delete this field and its soil-test history?':
      'இந்த வயலையும் அதன் மண் பரிசோதனை வரலாற்றையும் நீக்கவா?',
  'Could not add photos. Check photo library access and available storage.':
      'புகைப்படங்களைச் சேர்க்க முடியவில்லை. புகைப்பட அணுகலையும் சேமிப்பிடத்தையும் சரிபார்க்கவும்.',
  'Delete this photo?': 'இந்தப் புகைப்படத்தை நீக்கவா?',
  'Add photos': 'புகைப்படங்களைச் சேர்',
  'No photos yet. Add photos from your device.':
      'புகைப்படங்கள் இல்லை. உங்கள் சாதனத்திலிருந்து சேர்க்கவும்.',
  'Delete photo': 'புகைப்படத்தை நீக்கு',
  'Remove this saved device?': 'சேமித்த இந்தச் சாதனத்தை நீக்கவா?',
  'Remove saved device': 'சேமித்த சாதனத்தை நீக்கு',
  'No saved devices yet. Save one when it is discovered.':
      'சேமித்த சாதனங்கள் இல்லை. சாதனம் கண்டறியப்பட்டதும் சேமிக்கவும்.',
  'Delete all farms, fields, photos, saved devices, crop selections and soil-test history from this device? This cannot be undone.':
      'இந்தச் சாதனத்திலுள்ள பண்ணைகள், வயல்கள், புகைப்படங்கள், சேமித்த சாதனங்கள், பயிர் தேர்வுகள் மற்றும் மண் பரிசோதனை வரலாறு அனைத்தையும் நீக்கவா? இதை மீட்டெடுக்க முடியாது.',
  'Farm records, photos, crop selections, saved devices and soil history are stored only on this device.':
      'பண்ணைப் பதிவுகள், புகைப்படங்கள், பயிர் தேர்வுகள், சேமித்த சாதனங்கள் மற்றும் மண் வரலாறு இந்தச் சாதனத்தில் மட்டுமே சேமிக்கப்படும்.',
  'Deleting…': 'நீக்கப்படுகிறது…',
  'Delete all local farm data':
      'சாதனத்தில் உள்ள பண்ணைத் தரவுகள் அனைத்தையும் நீக்கு',
  'Local farm data deleted.': 'சாதனத்தில் உள்ள பண்ணைத் தரவு நீக்கப்பட்டது.',
  'Test note': 'பரிசோதனைக் குறிப்பு',
  'Optional note': 'விருப்பக் குறிப்பு',
  'Delete this soil-test record?': 'இந்த மண் பரிசோதனைப் பதிவை நீக்கவா?',
  'No saved tests for this field yet.':
      'இந்த வயலுக்கு இன்னும் சேமித்த பரிசோதனைகள் இல்லை.',
  'No note': 'குறிப்பு இல்லை',
  'Edit note': 'குறிப்பைத் திருத்து',
  'Remove favorite': 'பிடித்தவற்றிலிருந்து நீக்கு',
  'Favorite': 'பிடித்தது',
  'Delete test': 'பரிசோதனையை நீக்கு',
  'Rice': 'நெல்',
  'Maize': 'மக்காச்சோளம்',
  'Groundnut': 'நிலக்கடலை',
  'Cotton': 'பருத்தி',
  'Sugarcane': 'கரும்பு',
  'Millet': 'சிறுதானியம்',
  'Tomato': 'தக்காளி',
  'Banana': 'வாழை',
  'Pulses': 'பருப்பு வகைகள்',
};
