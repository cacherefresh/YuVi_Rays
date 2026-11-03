import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:yuvi_rays/app.dart';

void main() {
  testWidgets('app compiles and renders on a native (non-web) target', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const YuViRaysApp());
    await tester.pump();
    expect(find.text('YuVi Rays'), findsOneWidget);
  });
}
