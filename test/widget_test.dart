import 'package:carnet_dettes/widgets/common.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('initiales du client', () {
    expect(initials('Mamadou Sylla'), 'MS');
    expect(initials('awa'), 'A');
    expect(initials('  '), '?');
  });
}
