import 'package:flutter/material.dart';

import '../data/db.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Ouvre la feuille de saisie d'un achat ou d'un paiement.
Future<Tx?> showTxSheet(
  BuildContext context, {
  required int clientId,
  required TxType type,
  required double balance,
  Tx? existing,
}) {
  return showModalBottomSheet<Tx>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _TxSheet(
      clientId: clientId,
      type: existing?.type ?? type,
      balance: balance,
      existing: existing,
    ),
  );
}

class _TxSheet extends StatefulWidget {
  final int clientId;
  final TxType type;
  final double balance;
  final Tx? existing;

  const _TxSheet({
    required this.clientId,
    required this.type,
    required this.balance,
    this.existing,
  });

  @override
  State<_TxSheet> createState() => _TxSheetState();
}

class _TxSheetState extends State<_TxSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  String? _error;

  bool get _isPurchase => widget.type == TxType.achat;
  Color get _color => _isPurchase ? AppColors.debt : AppColors.paid;

  static const _quick = [500, 1000, 2000, 5000, 10000];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amount = TextEditingController(text: e == null ? '' : moneyShort(e.amount));
    _note = TextEditingController(text: e?.note ?? '');
    _date = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _setAmount(double v) {
    final text = moneyShort(v);
    _amount.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() => _error = null);
  }

  void _addQuick(int v) => _setAmount((parseAmount(_amount.text) ?? 0) + v);

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    setState(() {
      _date = DateTime(d.year, d.month, d.day, t?.hour ?? _date.hour,
          t?.minute ?? _date.minute);
    });
  }

  void _save() {
    final v = parseAmount(_amount.text);
    if (v == null || v <= 0) {
      setState(() => _error = 'Entrez un montant valide');
      return;
    }
    final note = _note.text.trim();
    Navigator.pop(
      context,
      Tx(
        id: widget.existing?.id,
        clientId: widget.clientId,
        type: widget.type,
        amount: v,
        note: note.isEmpty ? null : note,
        date: _date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final title = _isPurchase
        ? (editing ? "Modifier l'achat" : 'Nouvel achat à crédit')
        : (editing ? 'Modifier le paiement' : 'Nouveau paiement');

    // Pour "Tout payer", on ignore le montant de la transaction modifiée
    var remaining = widget.balance;
    if (editing && !_isPurchase) remaining += widget.existing!.amount;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: _color.withOpacity(0.14),
                child: Icon(
                  _isPurchase ? Icons.add_shopping_cart : Icons.payments_outlined,
                  color: _color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              ),
            ]),
            if (widget.balance >= 1)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 52),
                child: Text('Dette actuelle : ${money(widget.balance)}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            const SizedBox(height: 18),
            TextField(
              controller: _amount,
              autofocus: !editing,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w800, color: _color),
              decoration: InputDecoration(
                hintText: '0',
                suffixText: kCurrency,
                errorText: _error,
                suffixIcon: _amount.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.backspace_outlined),
                        onPressed: () => setState(() => _amount.clear()),
                      ),
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final q in _quick)
                  ActionChip(
                    label: Text('+${moneyShort(q)}'),
                    onPressed: () => _addQuick(q),
                  ),
                if (!_isPurchase && remaining >= 1)
                  ActionChip(
                    avatar: const Icon(Icons.done_all, size: 18, color: AppColors.paid),
                    label: Text('Tout payer (${moneyShort(remaining)})'),
                    onPressed: () => _setAmount(remaining),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _isPurchase
                    ? 'Articles (ex : 2 kg de riz, 1 L d’huile…)'
                    : 'Note (facultatif)',
                prefixIcon: Icon(
                    _isPurchase ? Icons.shopping_bag_outlined : Icons.notes),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(fullDate(_date)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _color,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: Text(
                  editing
                      ? 'Enregistrer'
                      : (_isPurchase ? 'Ajouter la dette' : 'Enregistrer le paiement'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
