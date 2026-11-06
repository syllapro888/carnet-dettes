import 'package:intl/intl.dart';

/// Monnaie affichée partout dans l'application.
const String kCurrency = 'FCFA';

/// Indicatif ajouté aux numéros locaux pour WhatsApp (242 = Congo-Brazzaville).
const String kDefaultCountryCode = '242';

final NumberFormat _nf = NumberFormat.decimalPattern('fr_FR');

String money(num value) => '${_nf.format(value.round())} $kCurrency';

String moneyShort(num value) => _nf.format(value.round());

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Étiquette de séparateur de jour dans le chat ("Aujourd'hui", "Hier", "Lundi", "3 mars 2026").
String dayLabel(DateTime d) {
  final now = DateTime.now();
  if (sameDay(d, now)) return "Aujourd'hui";
  if (sameDay(d, now.subtract(const Duration(days: 1)))) return 'Hier';
  if (now.difference(d).inDays < 7 && d.isBefore(now)) {
    return _cap(DateFormat.EEEE('fr_FR').format(d));
  }
  return DateFormat('d MMMM y', 'fr_FR').format(d);
}

String timeLabel(DateTime d) => DateFormat.Hm('fr_FR').format(d);

/// Date courte affichée dans la liste des clients.
String listDateLabel(DateTime d) {
  final now = DateTime.now();
  if (sameDay(d, now)) return timeLabel(d);
  if (sameDay(d, now.subtract(const Duration(days: 1)))) return 'Hier';
  return DateFormat('dd/MM/yy', 'fr_FR').format(d);
}

String fullDate(DateTime d) => DateFormat("d MMM y 'à' HH:mm", 'fr_FR').format(d);

/// Convertit "5 000", "5000,5" ou "5.000" en nombre.
double? parseAmount(String input) {
  var s = input.replaceAll(RegExp(r'[^0-9,.]'), '');
  if (s.isEmpty) return null;
  // "5.000" ou "5,000" sans décimales -> séparateur de milliers
  if (RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(s)) {
    s = s.replaceAll(RegExp(r'[.,]'), '');
  }
  s = s.replaceAll(',', '.');
  return double.tryParse(s);
}

/// Numéro au format international sans "+" pour wa.me.
String? whatsappNumber(String? phone) {
  if (phone == null) return null;
  var d = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (d.isEmpty) return null;
  if (d.startsWith('+')) return d.substring(1).replaceAll('+', '');
  d = d.replaceAll('+', '');
  if (d.startsWith('00')) return d.substring(2);
  if (d.startsWith(kDefaultCountryCode) && d.length > 10) return d;
  return '$kDefaultCountryCode$d';
}
