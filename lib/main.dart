import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/managers/vpn_manager.dart';
import 'core/themes/app_theme.dart';
import 'ui/screens/root_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NetGuardApp());
}

class NetGuardApp extends StatelessWidget {
  const NetGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VpnManager(),
      child: Consumer<VpnManager>(
        builder: (context, manager, _) {
          return MaterialApp(
            title: 'Net Guard',
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.dark,
            darkTheme: AppTheme.darkTheme,
            theme: AppTheme.darkTheme,
            locale: manager.currentLocale,
            supportedLocales: const [
              Locale('ar'),
              Locale('en'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const RootScreen(),
          );
        },
      ),
    );
  }
}
