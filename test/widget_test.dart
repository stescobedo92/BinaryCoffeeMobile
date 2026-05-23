import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:binary_coffee_mobile/main.dart';
import 'package:binary_coffee_mobile/src/state/app_controller.dart';

void main() {
  testWidgets('renders Binary Coffee shell', (tester) async {
    final controller = AppController();
    await tester.pumpWidget(BinaryCoffeeApp(controller: controller));

    expect(find.text('Binary Coffee'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });
}
