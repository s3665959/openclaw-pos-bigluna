import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:openclaw_pos_bigluna/main.dart';

void main() {
  testWidgets('shows Big Luna POS title', (tester) async {
    await tester.pumpWidget(
      const BigLunaApp(
        home: Scaffold(
          body: Center(
            child: Text('Big Luna POS'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Big Luna POS'), findsWidgets);
  });
}
