import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/controllers/transaction_controller.dart';

void main() {
  testWidgets('MoneyTrack app smoke test', (WidgetTester tester) async {
    Get.put(TransactionController());
    await tester.pumpWidget(
      const MoneyTrackApp(),
    );

    // Verify dashboard elements are present
    expect(find.text('Halo, Fiqri 👋'), findsOneWidget);
    expect(find.text('Transaksi Terakhir'), findsOneWidget);
  });
}
