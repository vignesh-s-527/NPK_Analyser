import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app_language.dart';
import '../data/local_store.dart';
import '../features/farmer_shell.dart';
import '../services/contracts.dart';

class NpkApp extends StatelessWidget {
  final FarmerServices services;
  const NpkApp({super.key,this.services=const FarmerServices()});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale>(
    valueListenable: AppLanguage.locale,
    builder: (context, locale, _) => MaterialApp(
      title: 'NPK Soil Analyzer', debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ta')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff39734a), brightness: Brightness.light), useMaterial3: true, scaffoldBackgroundColor: const Color(0xfff6f8f4)),
      home: LaunchScreen(services:services),
    ),
  );
}

class LaunchScreen extends StatelessWidget {
  final FarmerServices services;
  const LaunchScreen({super.key,this.services=const FarmerServices()});
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.grass, size: 76, color: Color(0xff39734a)), const SizedBox(height: 16),
    Text('NPK Soil Analyzer', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
    const Text('Healthy soil. Confident farming.', textAlign: TextAlign.center), const SizedBox(height: 40),
    FilledButton.icon(onPressed: () async {final profile=await LocalStore.instance.profile();if(!context.mounted)return;final done=(profile?['tutorial_done'] as int?)==1;Navigator.of(context).pushReplacement(MaterialPageRoute(builder:(_)=>done?FarmerShell(services:services):TutorialScreen(services:services)));}, icon: const Icon(Icons.agriculture), label: const Text('Continue as Farmer'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54))),
    const SizedBox(height: 12), OutlinedButton.icon(onPressed: () {final builder=services.expertDashboardBuilder;if(builder==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('The agricultural expert dashboard has not been connected yet.')));}else{Navigator.of(context).push(MaterialPageRoute(builder:builder));}}, icon: const Icon(Icons.support_agent), label: const Text('Agricultural Expert'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54))),
  ])))));
}

class TutorialScreen extends StatefulWidget { final FarmerServices services;const TutorialScreen({super.key,this.services=const FarmerServices()}); @override State<TutorialScreen> createState()=>_TutorialScreenState(); }
class _TutorialScreenState extends State<TutorialScreen> {
  final controller=PageController(); int page=0;
  static const items=[(Icons.bluetooth_searching,'Connect your analyzer','Turn on your NPK device and connect to it from Soil. You will connect manually each time.'),(Icons.grass,'Collect and test soil','Collect a representative soil sample, prepare it as instructed by your analyzer, then start a test.'),(Icons.science,'Review your NPK results','When the measurement finishes, review the final nitrogen, phosphorus and potassium results.'),(Icons.eco,'Plan with recommendations','Choose crops and view farming recommendations when the crop and calendar services are connected.')];
  Future<void> finish() async {await LocalStore.instance.markTutorialDone();if(mounted)Navigator.of(context).pushReplacement(MaterialPageRoute(builder:(_)=>FarmerShell(services:widget.services)));}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(actions:[TextButton(onPressed:finish,child:const Text('Skip'))]),body:Column(children:[Expanded(child:PageView.builder(controller:controller,itemCount:items.length,onPageChanged:(v)=>setState(()=>page=v),itemBuilder:(context,index)=>Padding(padding:const EdgeInsets.all(32),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(items[index].$1,size:86,color:Theme.of(context).colorScheme.primary),const SizedBox(height:28),Text(items[index].$2,style:Theme.of(context).textTheme.headlineSmall,textAlign:TextAlign.center),const SizedBox(height:12),Text(items[index].$3,textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodyLarge)])))),Row(mainAxisAlignment:MainAxisAlignment.center,children:List.generate(items.length,(i)=>Container(width:8,height:8,margin:const EdgeInsets.all(4),decoration:BoxDecoration(shape:BoxShape.circle,color:i==page?Theme.of(context).colorScheme.primary:Colors.black26)))),Padding(padding:const EdgeInsets.all(20),child:FilledButton(onPressed:page==items.length-1?finish:()=>controller.nextPage(duration:const Duration(milliseconds:250),curve:Curves.easeOut),child:Text(page==items.length-1?'Get started':'Next')))]));
}
