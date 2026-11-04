import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'input/command_dispatcher.dart';
import 'input/input_controller.dart';
import 'providers/mixer_provider.dart';
import 'screens/mixer_screen.dart';
import 'settings/app_settings.dart';

class YuViRaysApp extends StatelessWidget {
  const YuViRaysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettings()),
        ChangeNotifierProvider(create: (ctx) {
          final mixer = MixerProvider();
          final settings = ctx.read<AppSettings>();
          void apply() => mixer.setPreferTagBpm(settings.preferTagBpm);
          apply();
          settings.addListener(apply); // both live for the app's lifetime
          return mixer;
        }),
        // Not lazy: keyboard shortcuts must work before anything reads it.
        Provider<InputController>(
          lazy: false,
          create: (ctx) => InputController(
            dispatch: CommandDispatcher(ctx.read<MixerProvider>()),
            settings: ctx.read<AppSettings>(),
          ),
          dispose: (_, c) => c.dispose(),
        ),
      ],
      child: MaterialApp(
        title: 'YuVi Rays DVS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF1C1C1E),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00D4AA),
            secondary: Color(0xFFFF9500),
            surface: Color(0xFF252527),
          ),
          sliderTheme: const SliderThemeData(
            activeTrackColor: Color(0xFF00D4AA),
            thumbColor: Color(0xFF00D4AA),
          ),
        ),
        home: const MixerScreen(),
      ),
    );
  }
}
