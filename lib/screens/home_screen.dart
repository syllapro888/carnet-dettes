import 'dart:io';

import 'package:flutter/material.dart';

import '../data/db.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'client_chat_screen.dart';
import 'client_form_screen.dart';

enum _Filter { tous, dette, ajour }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  List<Client> _clients = [];
  bool _loading = true;
  bool _searching = false;
  String _query = '';
  _Filter _filter = _Filter.tous;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await AppDb.instance.clients();
    if (!mounted) return;
    setState(() {
      _clients = list;
      _loading = false;
    });
  }

  List<Client> get _visible {
    final q = _query.trim().toLowerCase();
    return _clients.where((c) {
      if (_filter == _Filter.dette && !c.hasDebt) return false;
      if (_filter == _Filter.ajour && c.hasDebt) return false;
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          (c.phone ?? '').replaceAll(' ', '').contains(q.replaceAll(' ', ''));
    }).toList();
  }

  double get _totalDebt =>
      _clients.where((c) => c.hasDebt).fold(0.0, (s, c) => s + c.balance);

  int get _debtorCount => _clients.where((c) => c.hasDebt).length;

  Future<void> _openClient(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ClientChatScreen(clientId: id)),
    );
    _load();
  }

  Future<void> _addClient() async {
    final id = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const ClientFormScreen()),
    );
    await _load();
    if (id != null && mounted) _openClient(id);
  }

  Future<void> _editClient(Client c) async {
    await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => ClientFormScreen(client: c)),
    );
    _load();
  }

  Future<void> _deleteClient(Client c) async {
    final ok = await confirmDialog(
      context,
      title: 'Supprimer ${c.name} ?',
      message: 'Le client et tout son historique (achats et paiements) seront supprimés définitivement.',
    );
    if (!ok) return;
    await AppDb.instance.deleteClient(c.id!);
    if (photoExists(c.photo)) {
      try {
        await File(c.photo!).delete();
      } catch (_) {}
    }
    if (mounted) toast(context, '${c.name} a été supprimé');
    _load();
  }

  void _clientMenu(Client c) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: ClientAvatar(name: c.name, photo: c.photo),
              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(c.hasDebt ? 'Doit ${money(c.balance)}' : 'À jour'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('Ouvrir'),
              onTap: () {
                Navigator.pop(ctx);
                _openClient(c.id!);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Modifier'),
              onTap: () {
                Navigator.pop(ctx);
                _editClient(c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.debt),
              title: const Text('Supprimer', style: TextStyle(color: AppColors.debt)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteClient(c);
              },
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    if (!_searching) {
      return AppBar(
        title: const Text('Carnet de Dettes'),
        actions: [
          IconButton(
            tooltip: 'Rechercher',
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _searching = true),
          ),
        ],
      );
    }
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => setState(() {
          _searching = false;
          _query = '';
          _searchCtrl.clear();
        }),
      ),
      title: TextField(
        controller: _searchCtrl,
        autofocus: true,
        cursorColor: Colors.white,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        decoration: const InputDecoration(
          hintText: 'Nom ou téléphone…',
          hintStyle: TextStyle(color: Colors.white70),
          filled: false,
          border: InputBorder.none,
        ),
        onChanged: (v) => setState(() => _query = v),
      ),
      actions: [
        if (_query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() {
              _query = '';
              _searchCtrl.clear();
            }),
          ),
      ],
    );
  }

  Widget _summary() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total à recevoir',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              money(_totalDebt),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _pill(Icons.people_alt_outlined, '${_clients.length} clients'),
              const SizedBox(width: 8),
              _pill(Icons.warning_amber_rounded, '$_debtorCount en dette'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ]),
      );

  Widget _filters() {
    Widget chip(_Filter f, String label) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: _filter == f,
            showCheckmark: false,
            onSelected: (_) => setState(() => _filter = f),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(children: [
        chip(_Filter.tous, 'Tous'),
        chip(_Filter.dette, 'En dette'),
        chip(_Filter.ajour, 'À jour'),
      ]),
    );
  }

  Widget _empty() {
    final noClients = _clients.isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      child: Column(
        children: [
          Icon(
            noClients ? Icons.storefront_outlined : Icons.search_off,
            size: 72,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            noClients ? 'Aucun client pour le moment' : 'Aucun résultat',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            noClients
                ? 'Appuyez sur « Nouveau client » pour commencer à noter les dettes.'
                : 'Essayez un autre nom ou un autre filtre.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      appBar: _appBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: visible.isEmpty ? 2 : visible.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Column(children: [
                      if (!_searching) _summary(),
                      _filters(),
                    ]);
                  }
                  if (visible.isEmpty) return _empty();
                  final c = visible[i - 1];
                  return _ClientTile(
                    client: c,
                    onTap: () => _openClient(c.id!),
                    onLongPress: () => _clientMenu(c),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addClient,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nouveau client'),
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  final Client client;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ClientTile({
    required this.client,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = client;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    String subtitle;
    IconData? icon;
    Color? iconColor;
    if (c.lastType == TxType.achat) {
      icon = Icons.shopping_basket_outlined;
      iconColor = AppColors.debt;
      subtitle = 'Achat ${money(c.lastAmount ?? 0)}';
    } else if (c.lastType == TxType.paiement) {
      icon = Icons.done_all;
      iconColor = AppColors.paid;
      subtitle = 'Paiement ${money(c.lastAmount ?? 0)}';
    } else {
      subtitle = c.phone?.isNotEmpty == true ? c.phone! : 'Aucune opération';
    }
    if (c.lastNote != null && c.lastNote!.isNotEmpty) {
      subtitle += ' · ${c.lastNote}';
    }

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => photoExists(c.photo)
                  ? showClientPhoto(context, c.name, c.photo)
                  : onTap(),
              child: Hero(
                tag: 'avatar-${c.id}',
                child: ClientAvatar(name: c.name, photo: c.photo, radius: 27),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(listDateLabel(c.activity),
                        style: TextStyle(fontSize: 12, color: muted)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: iconColor),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: muted, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    BalanceBadge(balance: c.balance),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
