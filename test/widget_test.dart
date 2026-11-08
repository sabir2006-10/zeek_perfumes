import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zeek/app.dart';

void main() {
  testWidgets('Zeek POS App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ZeekApp(),
      ),
    );
    expect(find.byType(ZeekApp), findsOneWidget);
  });
}
