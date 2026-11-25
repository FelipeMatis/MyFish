import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../models/catch_model.dart';
import '../repositories/fishing_repository.dart';
import '../theme/app_theme.dart';
import 'catch_form_page.dart';

class DiaryPage extends StatefulWidget {
  /// Cria o diário para um usuário e repositório específicos.
  const DiaryPage({required this.repository, required this.userId, super.key});

  final FishingRepository repository;
  final String userId;

  /// Cria o estado que mantém a busca e filtros do diário.
  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  final _searchController = TextEditingController();
  DateTimeRange? _dateRange;
  bool _withWeatherOnly = false;

  /// Libera o controlador da busca ao fechar o diário.
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Abre o seletor para filtrar capturas por período.
  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (range != null) setState(() => _dateRange = range);
  }

  /// Mostra a lista de capturas e aplica os filtros selecionados.
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CatchModel>>(
      stream: widget.repository.watchUserCatches(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Não foi possível carregar o diário: ${snapshot.error}',
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final query = _searchController.text.trim().toLowerCase();
        final captures = snapshot.data!.where((capture) {
          final matchesText =
              query.isEmpty ||
              capture.species.toLowerCase().contains(query) ||
              capture.bait.toLowerCase().contains(query);
          final matchesDate =
              _dateRange == null ||
              (!capture.capturedAt.isBefore(_dateRange!.start) &&
                  !capture.capturedAt.isAfter(
                    _dateRange!.end.add(const Duration(days: 1)),
                  ));
          final matchesWeather = !_withWeatherOnly || capture.weather != null;
          return matchesText && matchesDate && matchesWeather;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar espécie ou isca',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar busca',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  FilterChip(
                    selected: _dateRange != null,
                    label: Text(
                      _dateRange == null
                          ? 'Data'
                          : '${DateFormat('dd/MM').format(_dateRange!.start)}'
                                '–${DateFormat('dd/MM').format(_dateRange!.end)}',
                    ),
                    onSelected: (_) => _selectDateRange(),
                    onDeleted: _dateRange == null
                        ? null
                        : () => setState(() => _dateRange = null),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    selected: _withWeatherOnly,
                    label: const Text('Com clima registrado'),
                    onSelected: (selected) {
                      setState(() => _withWeatherOnly = selected);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: captures.isEmpty
                  ? const _EmptyDiary()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      itemCount: captures.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final capture = captures[index];
                        return _CaptureTile(
                          capture: capture,
                          repository: widget.repository,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _CaptureTile extends StatefulWidget {
  /// Cria um item do diário com captura e acesso ao repositório.
  const _CaptureTile({required this.capture, required this.repository});

  final CatchModel capture;
  final FishingRepository repository;

  /// Cria o estado que carrega a foto e controla ações da captura.
  @override
  State<_CaptureTile> createState() => _CaptureTileState();
}

class _CaptureTileState extends State<_CaptureTile> {
  late final Future<String?> _photoFuture;

  /// Inicia o carregamento da foto da captura.
  @override
  void initState() {
    super.initState();
    _photoFuture = widget.repository.loadCatchPhoto(widget.capture.id);
  }

  /// Exibe os dados da captura e suas ações de edição ou exclusão.
  @override
  Widget build(BuildContext context) {
    final capture = widget.capture;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: FutureBuilder<String?>(
          future: _photoFuture,
          builder: (context, snapshot) {
            final photo = snapshot.data ?? capture.photoBase64;
            if (photo == null) {
              return const CircleAvatar(
                backgroundColor: AppTheme.card,
                child: Icon(Icons.set_meal_outlined, color: AppTheme.accent),
              );
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                base64Decode(photo),
                width: 58,
                height: 58,
                fit: BoxFit.cover,
              ),
            );
          },
        ),
        title: Text(
          capture.species,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat('dd/MM/yyyy HH:mm').format(capture.capturedAt)} · '
              '${capture.weightKg?.toStringAsFixed(2) ?? '—'} kg · ${capture.bait}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (capture.isPendingSync)
              const Text(
                'Aguardando sincronização',
                style: TextStyle(color: Color(0xFFE0A03A), fontSize: 12),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            if (action == 'edit') {
              final photoBase64 = await widget.repository.loadCatchPhoto(
                capture.id,
              );
              if (!context.mounted) return;
              await Navigator.push<SaveResult>(
                context,
                MaterialPageRoute(
                  builder: (_) => CatchFormPage(
                    location: LatLng(capture.latitude, capture.longitude),
                    repository: widget.repository,
                    capture: capture,
                    initialPhotoBase64: photoBase64,
                  ),
                ),
              );
            } else {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Excluir captura?'),
                  content: const Text('Esta ação não pode ser desfeita.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Excluir'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                try {
                  final result = await widget.repository.deleteCatch(
                    capture.id,
                    capture.userId,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result.message ?? 'Captura excluída e sincronizada.',
                        ),
                      ),
                    );
                  }
                } on Exception catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Falha ao excluir: $error')),
                    );
                  }
                }
              }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(value: 'delete', child: Text('Excluir')),
          ],
        ),
      ),
    );
  }
}

class _EmptyDiary extends StatelessWidget {
  /// Cria a mensagem exibida quando não há capturas.
  const _EmptyDiary();

  /// Mostra uma orientação para registrar a primeira captura.
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 54,
              color: AppTheme.accent,
            ),
            const SizedBox(height: 14),
            Text(
              'Nenhuma captura encontrada',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Mude os filtros ou registre sua primeira pescaria pelo mapa.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
