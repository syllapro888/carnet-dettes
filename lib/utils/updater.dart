import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// Dépôt GitHub où sont publiées les nouvelles versions (onglet Releases).
const String kGithubRepo = 'syllapro888/carnet-dettes';

/// Numéro de build injecté par GitHub Actions (--dart-define=APP_BUILD=...).
const int kAppBuild = int.fromEnvironment('APP_BUILD', defaultValue: 0);

String get appVersion => kAppBuild == 0 ? '1.0.0 (dev)' : '1.0.$kAppBuild';

class UpdateInfo {
  final int build;
  final String version;
  final String apkUrl;
  final String notes;
  const UpdateInfo(this.build, this.version, this.apkUrl, this.notes);
}

/// Lit la dernière Release GitHub. Renvoie null si pas de connexion.
Future<UpdateInfo?> fetchLatestRelease() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final req = await client.getUrl(
        Uri.parse('https://api.github.com/repos/$kGithubRepo/releases/latest'));
    req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    req.headers.set(HttpHeaders.userAgentHeader, 'carnet-dettes-app');
    final res = await req.close().timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;

    final tag = json['tag_name'] as String? ?? '';
    final match = RegExp(r'(\d+)$').firstMatch(tag);
    if (match == null) return null;

    String? apk;
    for (final a in (json['assets'] as List? ?? const [])) {
      final url = (a as Map)['browser_download_url'] as String?;
      if (url != null && url.endsWith('.apk')) {
        apk = url;
        break;
      }
    }
    apk ??= json['html_url'] as String?;
    if (apk == null) return null;

    return UpdateInfo(
      int.parse(match.group(1)!),
      tag.startsWith('v') ? tag.substring(1) : tag,
      apk,
      (json['body'] as String?) ?? '',
    );
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Vérifie s'il existe une version plus récente et propose de l'installer.
/// [silent] = true au démarrage : n'affiche rien s'il n'y a pas de mise à jour.
Future<void> checkForUpdate(BuildContext context, {bool silent = true}) async {
  if (silent && kAppBuild == 0) return; // version de développement
  final info = await fetchLatestRelease();
  if (!context.mounted) return;

  if (info == null) {
    if (!silent) toast(context, 'Impossible de vérifier : pas de connexion internet ?');
    return;
  }
  if (info.build <= kAppBuild) {
    if (!silent) toast(context, '✅ Vous avez la dernière version ($appVersion)');
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.system_update, color: AppColors.primary, size: 40),
      title: const Text('Nouvelle version disponible'),
      content: Text(
        'La version ${info.version} est disponible '
        '(vous avez la $appVersion).\n\n'
        'Téléchargez-la puis ouvrez le fichier pour l’installer. '
        'Vos clients et vos dettes sont conservés.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Plus tard'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          icon: const Icon(Icons.download),
          label: const Text('Mettre à jour'),
          onPressed: () async {
            Navigator.pop(ctx);
            final ok = await launchUrl(Uri.parse(info.apkUrl),
                mode: LaunchMode.externalApplication);
            if (!ok && context.mounted) {
              toast(context, 'Impossible d’ouvrir le téléchargement');
            }
          },
        ),
      ],
    ),
  );
}
