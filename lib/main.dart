import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/vlc_provider.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';
import 'services/voice/voice_command_executor.dart';
import 'services/voice/voice_command_service.dart';

void main() {
  // Le impostazioni sono condivise: il provider le inizializza per il suo
  // uso, il motore vocale per il proprio. La stessa istanza evita due
  // copie della cache di SharedPreferences.
  runApp(VlcRemoteApp(settingsService: SettingsService()));
}

class VlcRemoteApp extends StatelessWidget {
  const VlcRemoteApp({super.key, required this.settingsService});

  final SettingsService settingsService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SettingsService>.value(value: settingsService),
        ChangeNotifierProvider(
          create: (_) => VlcProvider(settingsService: settingsService),
        ),
        // Il motore vocale non conosce il provider: riceve un esecutore che
        // gliela passa, cosi' il riconoscimento si puo' provare da solo.
        ChangeNotifierProxyProvider<VlcProvider, VoiceCommandService>(
          lazy: false,
          create: (context) => VoiceCommandService(
            executor: VlcVoiceCommandExecutor(context.read<VlcProvider>()),
            settingsService: settingsService,
          ),
          update: (context, provider, previous) => previous!,
        ),
      ],
      child: MaterialApp(
        title: 'VLC Remote',
        debugShowCheckedModeBanner: false,
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: ThemeMode.dark, // Default a dark mode
        home: const HomeScreen(),
      ),
    );
  }

  /// Tema chiaro
  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// Tema scuro
  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
        surface: const Color(0xFF1E1E1E),
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardTheme: const CardThemeData(
        elevation: 4,
        color: Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        elevation: 0,
      ),
    );
  }
}
