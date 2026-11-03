import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuvi_midi_engine/yuvi_midi_engine.dart';

import 'providers/app_mode_provider.dart';
import 'providers/mixer_provider.dart';
import 'screens/mixer_screen.dart';

class YuViRaysApp extends StatelessWidget {
  const YuViRaysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppModeProvider()),
        ChangeNotifierProvider(create: (_) => MixerProvider()),
        ChangeNotifierProvider(create: (_) => MidiLearnController()),
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
