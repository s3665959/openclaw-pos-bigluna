import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders Big Luna POS text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Big Luna POS'),
          ),
        ),
      ),
    );

    expect(find.text('Big Luna POS'), findsOneWidget);
  });
}
