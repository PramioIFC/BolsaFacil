import 'package:bolsa_facil/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exibe a identidade do aplicativo', (tester) async {
    await tester.pumpWidget(const BolsaFacilApp());
    await tester.pump();
    expect(find.text('Bolsa Fácil'), findsOneWidget);
  });
}
