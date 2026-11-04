import 'package:flutter/foundation.dart';

/// Observable state of the master section: master fader, headphone fader
/// and crossfader. All values are normalized 0.0..1.0.
class MasterState extends ChangeNotifier {
  double masterVolume = 1.0;
  double headphoneVolume = 1.0;

  /// 0.0 = full Deck A, 0.5 = centre, 1.0 = full Deck B.
  double crossfader = 0.5;

  void update({double? masterVolume, double? headphoneVolume, double? crossfader}) {
    var changed = false;
    if (masterVolume != null && masterVolume != this.masterVolume) {
      this.masterVolume = masterVolume;
      changed = true;
    }
    if (headphoneVolume != null && headphoneVolume != this.headphoneVolume) {
      this.headphoneVolume = headphoneVolume;
      changed = true;
    }
    if (crossfader != null && crossfader != this.crossfader) {
      this.crossfader = crossfader;
      changed = true;
    }
    if (changed) notifyListeners();
  }
}
