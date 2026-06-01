import 'package:flutter_test/flutter_test.dart';

import 'package:openclaw_pos_bigluna/main.dart';

void main() {
  testWidgets('shows Big Luna POS title', (tester) async {
    await tester.pumpWidget(const BigLunaApp());
    await tester.pump();

    expect(find.text('Big Luna POS'), findsWidgets);
  });
}
