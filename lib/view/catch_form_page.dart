import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../models/catch_model.dart';
import '../models/weather_model.dart';
import '../repositories/fishing_repository.dart';
import '../services/photo_encoder.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';

class CatchFormPage extends StatefulWidget {
  /// Cria o formulário de captura com local e dados opcionais.
  const CatchFormPage({
    required this.location,
    required this.repository,
    this.initialDate,
    this.capture,
    this.initialPhotoBase64,
    super.key,
  });

  final LatLng location;
  final FishingRepository repository;
  final DateTime? initialDate;
  final CatchModel? capture;
  final String? initialPhotoBase64;

  /// Cria o estado que controla os campos e o envio da captura.
  @override
  State<CatchFormPage> createState() => _CatchFormPageState();
}

class _CatchFormPageState extends State<CatchFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _speciesController = TextEditingController();
  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _baitController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _notesController = TextEditingController();
  final _picker = ImagePicker();
  final _photoEncoder = PhotoEncoder();
  final _weatherService = WeatherService();

  Uint8List? _photoBytes;
  WeatherModel? _weather;
  CatchModality _modality = CatchModality.catchAndRelease;
  late DateTime _capturedAt;
  bool _isPublic = false;
  bool _loadingWeather = false;
  bool _saving = false;
  String? _weatherError;

  /// Preenche o formulário ao editar e inicia a consulta do clima ao criar.
  @override
  void initState() {
    super.initState();
    final capture = widget.capture;
    _capturedAt = capture?.capturedAt ?? widget.initialDate ?? DateTime.now();
    if (capture != null) {
      _speciesController.text = capture.species;
      _weightController.text = capture.weightKg?.toString() ?? '';
      _lengthController.text = capture.lengthCm?.toString() ?? '';
      _baitController.text = capture.bait;
      _equipmentController.text = capture.equipment;
      _notesController.text = capture.observations ?? '';
      _modality = capture.modality;
      _isPublic = capture.isPublic;
      _weather = capture.weather;
      final photoBase64 = capture.photoBase64 ?? widget.initialPhotoBase64;
      if (photoBase64 != null) {
        _photoBytes = base64Decode(photoBase64);
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadWeather());
    }
  }

  /// Libera os controladores dos campos ao fechar a tela.
  @override
  void dispose() {
    _speciesController.dispose();
    _weightController.dispose();
    _lengthController.dispose();
    _baitController.dispose();
    _equipmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Permite tirar uma foto ou escolher uma imagem da galeria.
  Future<void> _selectPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _photoBytes = bytes);
    } on Exception catch (error) {
      if (mounted) _showMessage('Não foi possível abrir a imagem: $error');
    }
  }

  /// Consulta o clima atual para a localização da captura.
  Future<void> _loadWeather() async {
    setState(() {
      _loadingWeather = true;
      _weatherError = null;
    });
    try {
      final weather = await _weatherService.currentAt(
        widget.location.latitude,
        widget.location.longitude,
      );
      if (mounted) setState(() => _weather = weather);
    } on Exception catch (error) {
      if (mounted) setState(() => _weatherError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingWeather = false);
    }
  }

  /// Permite escolher a data e o horário da captura.
  Future<void> _selectCapturedAt() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _capturedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_capturedAt),
    );
    if (selectedTime == null || !mounted) return;

    setState(() {
      _capturedAt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    });
  }

  /// Valida os dados e salva ou atualiza a captura.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _showMessage('Sua sessão expirou. Entre novamente para salvar.');
      return;
    }

    setState(() => _saving = true);
    try {
      final photoBase64 = _photoBytes == null
          ? widget.initialPhotoBase64
          : _photoEncoder.toBase64(_photoBytes!);
      final capture = CatchModel(
        id: widget.capture?.id ?? '',
        userId: userId,
        species: _speciesController.text.trim(),
        capturedAt: _capturedAt,
        weightKg: _optionalNumber(_weightController.text),
        lengthCm: _optionalNumber(_lengthController.text),
        bait: _baitController.text.trim().isEmpty
            ? 'Não informado'
            : _baitController.text.trim(),
        equipment: _equipmentController.text.trim().isEmpty
            ? 'Não informado'
            : _equipmentController.text.trim(),
        modality: _modality,
        observations: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        photoBase64: photoBase64,
        latitude: widget.location.latitude,
        longitude: widget.location.longitude,
        weather: _weather,
        isPublic: _isPublic,
      );
      final result = widget.capture == null
          ? await widget.repository.createCatch(capture)
          : await widget.repository.updateCatch(capture);

      if (!mounted) return;
      if (_weather == null && _weatherError != null) {
        _showMessage('Captura salva sem dados do clima: $_weatherError');
      }
      Navigator.pop(context, result);
    } on Exception catch (error) {
      if (mounted) {
        _showMessage('Não foi possível salvar a captura: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Converte um valor opcional digitado em número decimal.
  double? _optionalNumber(String value) {
    if (value.trim().isEmpty) return null;
    return double.parse(value.trim().replaceAll(',', '.'));
  }

  /// Exibe uma mensagem temporária para o usuário.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Monta o formulário para registrar ou editar uma captura.
  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.capture == null ? 'Nova captura' : 'Editar captura'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _PhotoPicker(bytes: _photoBytes, onTap: _selectPhoto),
            const SizedBox(height: 20),
            TextFormField(
              controller: _speciesController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Espécie *',
                prefixIcon: Icon(Icons.set_meal_outlined),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Informe a espécie.'
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Peso (kg)',
                      prefixIcon: Icon(Icons.scale_outlined),
                    ),
                    validator: _validateOptionalNumber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lengthController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Comprimento (cm)',
                      prefixIcon: Icon(Icons.straighten),
                    ),
                    validator: _validateOptionalNumber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.calendar_month,
                  color: AppTheme.accent,
                ),
                title: const Text('Data e horário da captura'),
                subtitle: Text(
                  DateFormat('dd/MM/yyyy · HH:mm').format(_capturedAt),
                ),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _selectCapturedAt,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _baitController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Isca',
                prefixIcon: Icon(Icons.sports),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _equipmentController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Equipamento',
                prefixIcon: Icon(Icons.phishing),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CatchModality>(
              initialValue: _modality,
              decoration: const InputDecoration(labelText: 'Modalidade'),
              items: const [
                DropdownMenuItem(
                  value: CatchModality.catchAndRelease,
                  child: Text('Pesque e solte'),
                ),
                DropdownMenuItem(
                  value: CatchModality.harvest,
                  child: Text('Abate'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _modality = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Observações',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Compartilhar publicamente'),
              subtitle: const Text(
                'Se desligado, só você poderá ver esta captura.',
              ),
              value: _isPublic,
              onChanged: (value) => setState(() => _isPublic = value),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.location_on_outlined,
                  color: AppTheme.accent,
                ),
                title: const Text('Localização'),
                subtitle: Text(
                  '${location.latitude.toStringAsFixed(5)}, '
                  '${location.longitude.toStringAsFixed(5)}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.cloud_outlined,
                      color: AppTheme.accent,
                    ),
                    title: Text(
                      _weather == null ? 'Clima' : _weather!.description,
                    ),
                    subtitle: Text(
                      _weather == null
                          ? _weatherError ?? 'Buscando condições atuais...'
                          : '${_weather!.temperatureC.toStringAsFixed(1)} °C · '
                                '${_weather!.pressureHpa.toStringAsFixed(0)} hPa · '
                                'vento ${_weather!.windSpeedMps.toStringAsFixed(1)} m/s',
                    ),
                    trailing: _loadingWeather
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            tooltip: 'Atualizar clima',
                            onPressed: _loadWeather,
                            icon: const Icon(Icons.refresh),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Salvando...' : 'Salvar captura'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Valida números opcionais e rejeita valores inválidos ou não positivos.
  String? _validateOptionalNumber(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final number = double.tryParse(value.trim().replaceAll(',', '.'));
    if (number == null || !number.isFinite || number <= 0) {
      return 'Informe um valor maior que zero.';
    }
    return null;
  }
}

class _PhotoPicker extends StatelessWidget {
  /// Cria o seletor de foto para uma imagem existente ou nova.
  const _PhotoPicker({required this.bytes, required this.onTap});

  final Uint8List? bytes;
  final VoidCallback onTap;

  /// Mostra a imagem escolhida ou o botão para adicionar uma foto.
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          color: AppTheme.cardSoft,
          borderRadius: BorderRadius.circular(20),
          image: bytes == null
              ? null
              : DecorationImage(image: MemoryImage(bytes!), fit: BoxFit.cover),
        ),
        child: bytes == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 36),
                  SizedBox(height: 8),
                  Text('Adicionar foto (opcional)'),
                ],
              )
            : Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: IconButton.filled(
                    onPressed: onTap,
                    icon: const Icon(Icons.edit),
                  ),
                ),
              ),
      ),
    );
  }
}
