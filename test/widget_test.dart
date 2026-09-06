import 'package:flutter_test/flutter_test.dart';
import 'package:net_speed_controller/main.dart';

void main() {
  testWidgets('Net Guard App Smoke Test', (WidgetTester tester) async {
    await tester.pumpWidget(const NetGuardApp());
  });
}
