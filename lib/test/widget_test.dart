import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test — widget tree builds', (WidgetTester tester) async {
    // Verify a basic MaterialApp renders without throwing
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('R2U-NET')),
        ),
      ),
    );
    expect(find.text('R2U-NET'), findsOneWidget);
  });
}
