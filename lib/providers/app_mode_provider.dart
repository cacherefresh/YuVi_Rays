import 'package:flutter/foundation.dart';

/// Toggles between the compact mobile layout (2 decks) and the desktop
/// layout (2 decks + AUX/VST channel). Kept separate from [MixerProvider]
/// so mixer state and layout/app-mode concerns don't bleed into each other.
class AppModeProvider extends ChangeNotifier {
  bool desktopMode = false;

  void toggleDesktopMode() {
    desktopMode = !desktopMode;
    notifyListeners();
  }
}
