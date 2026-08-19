import 'package:flutter_test/flutter_test.dart';
import 'package:dinaflutter/main.dart';

void main() {
  testWidgets('DinaApp létrejön', (WidgetTester tester) async {
    const app = DinaApp();

    expect(app, isA<DinaApp>());
  });
}