import 'dart:io';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/format.dart';

const _avatarPalette = [
  Color(0xFF00A884),
  Color(0xFF7E57C2),
  Color(0xFFEF6C00),
  Color(0xFF1E88E5),
  Color(0xFFD81B60),
  Color(0xFF43A047),
  Color(0xFF6D4C41),
  Color(0xFF00897B),
  Color(0xFF5C6BC0),
  Color(0xFFF4511E),
];

String initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

Color colorForName(String name) {
  final sum = name.codeUnits.fold<int>(0, (a, b) => a + b);
  return _avatarPalette[sum % _avatarPalette.length];
}

bool photoExists(String? path) => path != null && File(path).existsSync();

/// Avatar rond comme WhatsApp : photo si elle existe, sinon initiales colorées.
class ClientAvatar extends StatelessWidget {
  final String name;
  final String? photo;
  final double radius;

  const ClientAvatar({super.key, required this.name, this.photo, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    if (photoExists(photo)) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade300,
        backgroundImage: FileImage(File(photo!)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: colorForName(name),
      child: Text(
        initials(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Affiche la photo du client en plein écran (zoom possible).
void showClientPhoto(BuildContext context, String name, String? photo) {
  if (!photoExists(photo)) return;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(name)),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image.file(File(photo!)),
        ),
      ),
    ),
  ));
}

/// Pastille de solde : rouge = dette, vert = à jour, bleu = avance.
class BalanceBadge extends StatelessWidget {
  final double balance;
  const BalanceBadge({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String text;
    if (balance >= 1) {
      color = AppColors.debt;
      text = money(balance);
    } else if (balance <= -1) {
      color = AppColors.advance;
      text = 'Avance ${moneyShort(-balance)}';
    } else {
      color = AppColors.paid;
      text = 'À jour';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12.5),
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Supprimer',
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.debt),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return res ?? false;
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
