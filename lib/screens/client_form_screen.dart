import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/db.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Création ou modification d'un client (nom, téléphone, photo, note).
class ClientFormScreen extends StatefulWidget {
  final Client? client;
  const ClientFormScreen({super.key, this.client});

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _note;
  String? _photo;
  bool _saving = false;

  bool get _isEdit => widget.client != null;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _name = TextEditingController(text: c?.name ?? '')
      ..addListener(() => setState(() {}));
    _phone = TextEditingController(text: c?.phone ?? '');
    _note = TextEditingController(text: c?.note ?? '');
    _photo = c?.photo;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (_photo != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.debt),
                title: const Text('Retirer la photo',
                    style: TextStyle(color: AppColors.debt)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'remove') {
      setState(() => _photo = null);
      return;
    }
    try {
      final picked = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 82,
      );
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final ext = p.extension(picked.path).isEmpty ? '.jpg' : p.extension(picked.path);
      final dest = p.join(dir.path, 'client_${DateTime.now().millisecondsSinceEpoch}$ext');
      await File(picked.path).copy(dest);
      if (mounted) setState(() => _photo = dest);
    } catch (e) {
      if (mounted) toast(context, "Impossible d'ajouter la photo");
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    String? clean(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    final old = widget.client;
    final client = Client(
      id: old?.id,
      name: _name.text.trim(),
      phone: clean(_phone),
      note: clean(_note),
      photo: _photo,
      createdAt: old?.createdAt ?? DateTime.now(),
    );

    int id;
    if (old == null) {
      id = await AppDb.instance.insertClient(client);
    } else {
      await AppDb.instance.updateClient(client);
      id = old.id!;
      // Supprime l'ancienne photo si elle a été remplacée
      if (old.photo != null && old.photo != _photo && photoExists(old.photo)) {
        try {
          await File(old.photo!).delete();
        } catch (_) {}
      }
    }
    if (mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final name = _name.text.trim().isEmpty ? '?' : _name.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier le client' : 'Nouveau client'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    ClientAvatar(name: name, photo: _photo, radius: 62),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 3,
                          ),
                        ),
                        child: const Icon(Icons.photo_camera,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _pickPhoto,
                child: Text(_photo == null ? 'Ajouter une photo' : 'Changer la photo'),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofocus: !_isEdit,
              decoration: const InputDecoration(
                labelText: 'Nom du client *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Le nom est obligatoire' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                hintText: 'ex : 06 123 45 67',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Note (quartier, adresse…)',
                prefixIcon: Icon(Icons.sticky_note_2_outlined),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(_isEdit ? 'Enregistrer' : 'Créer le client',
                  style: const TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }
}
