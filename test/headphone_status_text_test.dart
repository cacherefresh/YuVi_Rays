import 'package:flutter_test/flutter_test.dart';
import 'package:yuvi_audio_engine/mixer_contracts.dart';
import 'package:yuvi_rays/settings/headphone_status_text.dart';

import 'support/fake_audio_outputs.dart';

void main() {
  test('every status has text and a colour', () {
    final o = FakeAudioOutputs();
    for (final s in HeadphoneStatus.values) {
      o.status = s;
      final (text, _) = describeHeadphoneStatus(o);
      expect(text, isNotEmpty, reason: s.name);
    }
  });

  test('names the chosen device when playing', () async {
    final o = FakeAudioOutputs();
    await o.setHeadphoneDevice(const AudioOutputDevice(id: 'usb1', name: 'USB Audio'));
    final (text, color) = describeHeadphoneStatus(o);
    expect(text, 'Playing on USB Audio');
    expect(color, HeadphoneColors.ok);
  });

  test('off, waiting for a click, unplugged and error are told apart', () {
    final o = FakeAudioOutputs()..headphoneDeviceName = 'USB Audio';
    o.status = HeadphoneStatus.off;
    expect(describeHeadphoneStatus(o).$1, 'Headphones off');
    o.status = HeadphoneStatus.waitingForClick;
    expect(describeHeadphoneStatus(o).$1, contains('Click anywhere'));
    expect(describeHeadphoneStatus(o).$2, HeadphoneColors.warn);
    o.status = HeadphoneStatus.lost;
    expect(describeHeadphoneStatus(o).$1, contains('unplugged'));
    o
      ..status = HeadphoneStatus.error
      ..statusMessage = 'NotFoundError';
    expect(describeHeadphoneStatus(o).$1, 'Headphones error: NotFoundError');
    expect(describeHeadphoneStatus(o).$2, HeadphoneColors.bad);
  });

  test('a device with no name is described generically', () {
    final o = FakeAudioOutputs()
      ..status = HeadphoneStatus.playing
      ..headphoneDeviceName = '';
    expect(describeHeadphoneStatus(o).$1, 'Playing on the chosen device');
  });

  test('turning headphones off clears the device', () async {
    final o = FakeAudioOutputs();
    await o.setHeadphoneDevice(const AudioOutputDevice(id: 'x', name: 'X'));
    await o.setHeadphoneDevice(null);
    expect(o.status, HeadphoneStatus.off);
    expect(o.headphoneDeviceId, isNull);
  });
}
