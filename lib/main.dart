import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'router.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  usePathUrlStrategy();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  FlutterNativeSplash.remove();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const ReefMobileApp(),
    ),
  );
}

class ReefMobileApp extends StatelessWidget {
  const ReefMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'reefguide.org',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
