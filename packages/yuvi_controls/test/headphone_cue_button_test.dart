import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuvi_controls/src/headphone_cue_button.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('tapping calls onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(HeadphoneCueButton(active: false, onPressed: () => taps++)));
    await tester.tap(find.byType(HeadphoneCueButton));
    expect(taps, 1);
  });

  testWidgets('shows a headphone icon, dark when lit', (tester) async {
    await tester.pumpWidget(host(HeadphoneCueButton(active: true, onPressed: () {})));
    final icon = tester.widget<Icon>(find.byIcon(Icons.headphones));
    expect(icon.color, const Color(0xFF1C1C1E));
  });

  testWidgets('unlit uses the deck colour', (tester) async {
    const deck = Color(0xFFFF9500);
    await tester.pumpWidget(host(HeadphoneCueButton(active: false, onPressed: () {}, color: deck)));
    final icon = tester.widget<Icon>(find.byIcon(Icons.headphones));
    expect(icon.color, deck.withValues(alpha: 0.8));
  });

  testWidgets('has a tooltip explaining PFL', (tester) async {
    await tester.pumpWidget(host(HeadphoneCueButton(active: false, onPressed: () {})));
    expect(find.byTooltip('Headphone cue (PFL): hear this deck in the headphones'), findsOneWidget);
  });
}
