import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/db.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/tx_sheet.dart';
import 'client_form_screen.dart';

/// Fiche client façon conversation WhatsApp :
/// achats à gauche, paiements à droite, solde toujours visible.
class ClientChatScreen extends StatefulWidget {
  final int clientId;
  const ClientChatScreen({super.key, required this.clientId});

  @override
  State<ClientChatScreen> createState() => _ClientChatScreenState();
}

class _ClientChatScreenState extends State<ClientChatScreen> {
  Client? _client;
  List<Tx> _txs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await AppDb.instance.client(widget.clientId);
    final txs = await AppDb.instance.transactions(widget.clientId);
    if (!mounted) return;
    if (c == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _client = c;
      _txs = txs;
    });
  }

  Future<void> _newTx(TxType type, {Tx? existing}) async {
    final c = _client!;
    final tx = await showTxSheet(
      context,
      clientId: c.id!,
      type: type,
      balance: c.balance,
      existing: existing,
    );
    if (tx == null) return;
    if (tx.id == null) {
      await AppDb.instance.insertTx(tx);
    } else {
      await AppDb.instance.updateTx(tx);
    }
    await _load();
    if (!mounted) return;
    if (existing == null && tx.type == TxType.paiement && !_client!.hasDebt) {
      toast(context, '🎉 ${c.name} a tout remboursé !');
    }
  }

  void _txMenu(Tx tx) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                '${tx.isPurchase ? 'Achat' : 'Paiement'} de ${money(tx.amount)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(fullDate(tx.date)),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Modifier'),
              onTap: () {
                Navigator.pop(ctx);
                _newTx(tx.type, existing: tx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.debt),
              title: const Text('Supprimer', style: TextStyle(color: AppColors.debt)),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await confirmDialog(
                  context,
                  title: 'Supprimer cette opération ?',
                  message: 'Le solde du client sera recalculé.',
                );
                if (!ok) return;
                await AppDb.instance.deleteTx(tx.id!);
                _load();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit() async {
    await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => ClientFormScreen(client: _client)),
    );
    _load();
  }

  Future<void> _delete() async {
    final c = _client!;
    final ok = await confirmDialog(
      context,
      title: 'Supprimer ${c.name} ?',
      message: 'Le client et tout son historique seront supprimés définitivement.',
    );
    if (!ok) return;
    await AppDb.instance.deleteClient(c.id!);
    if (photoExists(c.photo)) {
      try {
        await File(c.photo!).delete();
      } catch (_) {}
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _call() async {
    final phone = _client?.phone;
    if (phone == null) return;
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
    if (!ok && mounted) toast(context, "Impossible de lancer l'appel");
  }

  Future<void> _remindWhatsApp() async {
    final c = _client!;
    final number = whatsappNumber(c.phone);
    if (number == null) {
      toast(context, "Ajoutez d'abord le numéro du client");
      return;
    }
    if (!c.hasDebt) {
      toast(context, "${c.name} n'a aucune dette");
      return;
    }
    final msg = 'Bonjour ${c.name}, petit rappel de la boutique : '
        'votre solde à payer est de ${money(c.balance)} '
        '(achats ${money(c.totalPurchases)}, déjà payé ${money(c.totalPayments)}). '
        'Merci pour votre fidélité 🙏';
    final uri = Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(msg)}');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) toast(context, "WhatsApp n'a pas pu être ouvert");
    } catch (_) {
      if (mounted) toast(context, "WhatsApp n'a pas pu être ouvert");
    }
  }

  List<Widget> _buildItems(bool isDark) {
    final items = <Widget>[];
    double running = 0;
    DateTime? lastDay;
    for (final tx in _txs) {
      running += tx.isPurchase ? tx.amount : -tx.amount;
      if (lastDay == null || !sameDay(lastDay, tx.date)) {
        items.add(_DateChip(label: dayLabel(tx.date), isDark: isDark));
        lastDay = tx.date;
      }
      items.add(_TxBubble(
        tx: tx,
        balanceAfter: running,
        isDark: isDark,
        onLongPress: () => _txMenu(tx),
      ));
    }
    return items.reversed.toList(); // la liste est inversée (plus récent en bas)
  }

  @override
  Widget build(BuildContext context) {
    final c = _client;
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = _buildItems(isDark);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _edit,
          child: Row(children: [
            GestureDetector(
              onTap: () => photoExists(c.photo)
                  ? showClientPhoto(context, c.name, c.photo)
                  : _edit(),
              child: Hero(
                tag: 'avatar-${c.id}',
                child: ClientAvatar(name: c.name, photo: c.photo, radius: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  Text(
                    c.phone ?? 'Touchez ici pour les infos',
                    maxLines: 1,
                    style: const TextStyle(fontSize: 12.5, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ]),
        ),
        actions: [
          if (c.phone != null)
            IconButton(
              tooltip: 'Appeler',
              icon: const Icon(Icons.call_outlined),
              onPressed: _call,
            ),
          IconButton(
            tooltip: 'Rappel WhatsApp',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: _remindWhatsApp,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') _edit();
              if (v == 'delete') _delete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Modifier le client')),
              PopupMenuItem(value: 'delete', child: Text('Supprimer le client')),
            ],
          ),
        ],
      ),
      body: Container(
        color: isDark ? AppColors.chatBgDark : AppColors.chatBgLight,
        child: Column(
          children: [
            _BalanceBar(client: c),
            Expanded(
              child: items.isEmpty
                  ? _EmptyChat(isDark: isDark)
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                      itemCount: items.length,
                      itemBuilder: (_, i) => items[i],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: isDark ? AppColors.chatBgDark : AppColors.chatBgLight,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Row(children: [
              Expanded(
                child: _ActionButton(
                  color: AppColors.debt,
                  icon: Icons.add_shopping_cart,
                  label: 'Achat',
                  onTap: () => _newTx(TxType.achat),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  color: AppColors.paid,
                  icon: Icons.payments_outlined,
                  label: 'Paiement',
                  onTap: () => _newTx(TxType.paiement),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _BalanceBar extends StatelessWidget {
  final Client client;
  const _BalanceBar({required this.client});

  @override
  Widget build(BuildContext context) {
    final c = client;
    final scheme = Theme.of(context).colorScheme;
    final color = c.hasDebt
        ? AppColors.debt
        : (c.balance <= -1 ? AppColors.advance : AppColors.paid);
    final label = c.hasDebt
        ? 'Reste à payer'
        : (c.balance <= -1 ? 'Avance du client' : 'Aucune dette');
    final progress = c.totalPurchases <= 0
        ? 1.0
        : (c.totalPayments / c.totalPurchases).clamp(0.0, 1.0);

    return Material(
      color: scheme.surface,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          money(c.balance.abs()),
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800, color: color),
                        ),
                      ),
                    ],
                  ),
                ),
                _MiniStat(label: 'Achats', value: c.totalPurchases, color: AppColors.debt),
                const SizedBox(width: 14),
                _MiniStat(label: 'Payé', value: c.totalPayments, color: AppColors.paid),
              ],
            ),
            if (c.totalPurchases > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  color: AppColors.paid,
                  backgroundColor: AppColors.debt.withOpacity(0.18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(moneyShort(value),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final bool isDark;
  const _DateChip({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? AppColors.dateChipDark : AppColors.dateChipLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : const Color(0xFF54656F),
          ),
        ),
      ),
    );
  }
}

class _TxBubble extends StatelessWidget {
  final Tx tx;
  final double balanceAfter;
  final bool isDark;
  final VoidCallback onLongPress;

  const _TxBubble({
    required this.tx,
    required this.balanceAfter,
    required this.isDark,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final purchase = tx.isPurchase;
    final accent = purchase ? AppColors.debt : AppColors.paid;
    final bg = purchase
        ? (isDark ? AppColors.purchaseBubbleDark : AppColors.purchaseBubbleLight)
        : (isDark ? AppColors.paymentBubbleDark : AppColors.paymentBubbleLight);
    final textColor = isDark ? Colors.white : const Color(0xFF111B21);
    final muted = isDark ? Colors.white60 : const Color(0xFF667781);
    final radius = BorderRadius.only(
      topLeft: Radius.circular(purchase ? 4 : 16),
      topRight: Radius.circular(purchase ? 16 : 4),
      bottomLeft: const Radius.circular(16),
      bottomRight: const Radius.circular(16),
    );

    return Align(
      alignment: purchase ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Material(
            color: bg,
            elevation: 0.6,
            shadowColor: Colors.black26,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        purchase ? Icons.shopping_basket_rounded : Icons.payments_rounded,
                        size: 16,
                        color: accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        purchase ? 'Achat à crédit' : 'Paiement reçu',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700, color: accent),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    Text(
                      '${purchase ? '+' : '−'} ${money(tx.amount)}',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800, color: textColor),
                    ),
                    if (tx.note != null && tx.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(tx.note!, style: TextStyle(fontSize: 15, color: textColor)),
                    ],
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        balanceAfter >= 1
                            ? 'Reste ${moneyShort(balanceAfter)}'
                            : (balanceAfter <= -1
                                ? 'Avance ${moneyShort(-balanceAfter)}'
                                : 'Soldé ✓'),
                        style: TextStyle(fontSize: 11.5, color: muted),
                      ),
                      const SizedBox(width: 10),
                      Text(timeLabel(tx.date),
                          style: TextStyle(fontSize: 11.5, color: muted)),
                      if (!purchase) ...[
                        const SizedBox(width: 3),
                        const Icon(Icons.done_all, size: 15, color: Color(0xFF53BDEB)),
                      ],
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  final bool isDark;
  const _EmptyChat({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.dateChipDark : const Color(0xFFFFF5C4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          '🧾 Aucune opération.\n\nAppuyez sur « Achat » quand le client prend '
          'à crédit, et sur « Paiement » quand il rembourse.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14.5, height: 1.35),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          elevation: 2,
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
