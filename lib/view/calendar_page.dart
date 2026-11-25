import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/catch_model.dart';
import '../repositories/fishing_repository.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import 'catch_form_page.dart';

class CalendarPage extends StatefulWidget {
  /// Cria o calendário associado ao repositório de capturas.
  const CalendarPage({required this.repository, super.key});

  final FishingRepository repository;

  /// Cria o estado que controla os dias e capturas do calendário.
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _userId = FirebaseAuth.instance.currentUser!.uid;
  final _locationService = LocationService();
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _openingForm = false;

  /// Verifica se duas datas correspondem ao mesmo dia.
  bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  /// Abre o formulário para registrar uma captura no dia selecionado.
  Future<void> _addCapture() async {
    if (_openingForm) return;
    setState(() => _openingForm = true);
    try {
      final position = await _locationService.currentPosition();
      if (!mounted) return;
      final result = await Navigator.push<SaveResult>(
        context,
        MaterialPageRoute(
          builder: (_) => CatchFormPage(
            location: LatLng(position.latitude, position.longitude),
            repository: widget.repository,
            initialDate: _selectedDay,
          ),
        ),
      );
      if (result != null && mounted) {
        _message(
          result.message ?? 'Pescaria salva e sincronizada com o Firebase.',
        );
      }
    } on Exception catch (error) {
      if (mounted) _message('Não foi possível iniciar o registro: $error');
    } finally {
      if (mounted) setState(() => _openingForm = false);
    }
  }

  /// Exibe uma mensagem temporária na tela.
  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Mostra o calendário e as capturas da data selecionada.
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CatchModel>>(
      stream: widget.repository.watchUserCatches(_userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Falha ao carregar o calendário: ${snapshot.error}'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final captures = snapshot.data!;
        final selectedCaptures = captures
            .where((capture) => _sameDay(capture.capturedAt, _selectedDay))
            .toList();

        return Column(
          children: [
            TableCalendar<CatchModel>(
              firstDay: DateTime.utc(2000, 1, 1),
              lastDay: DateTime.utc(2100, 12, 31),
              locale: 'pt_BR',
              focusedDay: _focusedDay,
              calendarFormat: CalendarFormat.month,
              selectedDayPredicate: (day) => _sameDay(day, _selectedDay),
              eventLoader: (day) => captures
                  .where((capture) => _sameDay(capture.capturedAt, day))
                  .toList(),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                selectedDecoration: const BoxDecoration(
                  color: AppTheme.accent,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.32),
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: Color(0xFFE0A03A),
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
              ),
              headerStyle: const HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                leftChevronIcon: Icon(Icons.chevron_left),
                rightChevronIcon: Icon(Icons.chevron_right),
              ),
              calendarBuilders: CalendarBuilders<CatchModel>(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;
                  return Positioned(
                    bottom: 3,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('EEEE, d MMMM', 'pt_BR').format(_selectedDay),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _openingForm ? null : _addCapture,
                    icon: _openingForm
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: const Text('Captura'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: selectedCaptures.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma captura nesta data.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: selectedCaptures.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final capture = selectedCaptures[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.set_meal,
                              color: AppTheme.accent,
                            ),
                            title: Text(capture.species),
                            subtitle: Text(
                              '${DateFormat('HH:mm').format(capture.capturedAt)} · '
                              '${capture.weightKg?.toStringAsFixed(2) ?? '—'} kg'
                              '${capture.isPendingSync ? ' · aguardando sincronização' : ''}',
                            ),
                            onTap: () => showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(capture.species),
                                content: Text(
                                  '${DateFormat('dd/MM/yyyy HH:mm').format(capture.capturedAt)}\n'
                                  'Isca: ${capture.bait}\n'
                                  'Equipamento: ${capture.equipment}\n'
                                  'Localização: ${capture.latitude.toStringAsFixed(5)}, '
                                  '${capture.longitude.toStringAsFixed(5)}',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Fechar'),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
