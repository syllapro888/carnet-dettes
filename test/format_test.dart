import 'package:carnet_dettes/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseAmount comprend les formats courants', () {
    expect(parseAmount('5000'), 5000);
    expect(parseAmount('5 000'), 5000);
    expect(parseAmount('5.000'), 5000);
    expect(parseAmount('1,500'), 1500);
    expect(parseAmount('250,5'), 250.5);
    expect(parseAmount(''), isNull);
  });

  test('whatsappNumber ajoute l’indicatif', () {
    expect(whatsappNumber('06 123 45 67'), '242061234567');
    expect(whatsappNumber('+242 06 123 45 67'), '242061234567');
    expect(whatsappNumber('00242061234567'), '242061234567');
    expect(whatsappNumber(null), isNull);
  });
}
