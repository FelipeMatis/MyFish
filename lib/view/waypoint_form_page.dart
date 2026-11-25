import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/waypoint_model.dart';
import '../repositories/fishing_repository.dart';
import '../theme/app_theme.dart';

class WaypointFormPage extends StatefulWidget {
  /// Cria o formulário de ponto com localização e repositório.
  const WaypointFormPage({
    required this.location,
    required this.repository,
    super.key,
  });

  final LatLng location;
  final FishingRepository repository;

  /// Cria o estado que controla os campos e o salvamento do ponto.
  @override
  State<WaypointFormPage> createState() => _WaypointFormPageState();
}

class _WaypointFormPageState extends State<WaypointFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  WaypointType _type = WaypointType.fishingSpot;
  bool _isPublic = false;
  bool _saving = false;
  String? _statusMessage;

  /// Libera os controladores ao fechar o formulário.
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Valida os dados e salva o ponto para sincronização.
  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) {
      setState(() => _statusMessage = 'Informe um nome para o ponto.');
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(
        () =>
            _statusMessage = 'Sua sessão expirou. Entre novamente para salvar.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _statusMessage = null;
    });
    final now = DateTime.now();
    try {
      final result = await widget.repository.createWaypoint(
        WaypointModel(
          id: '',
          userId: userId,
          name: _nameController.text.trim(),
          type: _type,
          latitude: widget.location.latitude,
          longitude: widget.location.longitude,
          isPublic: _isPublic,
          createdAt: now,
          updatedAt: now,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, result);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Não foi possível salvar o ponto de pesca.',
        name: 'WaypointFormPage',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(
          () => _statusMessage = 'Não foi possível salvar o ponto: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Monta o formulário para salvar um ponto de pesca.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Salvar ponto de pesca')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome do ponto *',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Informe um nome para o ponto.'
                  : null,
              onChanged: (_) {
                if (_statusMessage != null) {
                  setState(() => _statusMessage = null);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<WaypointType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo de ponto'),
              items: const [
                DropdownMenuItem(
                  value: WaypointType.fishingSpot,
                  child: Text('Ponto de pesca'),
                ),
                DropdownMenuItem(
                  value: WaypointType.structure,
                  child: Text('Estrutura'),
                ),
                DropdownMenuItem(
                  value: WaypointType.boatRamp,
                  child: Text('Rampa de barco'),
                ),
                DropdownMenuItem(
                  value: WaypointType.fishery,
                  child: Text('Pesqueiro'),
                ),
                DropdownMenuItem(
                  value: WaypointType.other,
                  child: Text('Outro'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.location_on_outlined,
                  color: AppTheme.accent,
                ),
                title: const Text('Coordenadas selecionadas'),
                subtitle: Text(
                  '${widget.location.latitude.toStringAsFixed(5)}, '
                  '${widget.location.longitude.toStringAsFixed(5)}',
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ponto público'),
              subtitle: const Text(
                'Compartilhe o ponto com outros pescadores.',
              ),
              value: _isPublic,
              onChanged: (value) => setState(() => _isPublic = value),
            ),
            const SizedBox(height: 16),
            if (_statusMessage != null) ...[
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Salvando...' : 'Salvar ponto'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
