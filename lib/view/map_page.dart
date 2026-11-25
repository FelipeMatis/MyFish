import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/catch_model.dart';
import '../models/waypoint_model.dart';
import '../models/weather_model.dart';
import '../repositories/fishing_repository.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';
import 'catch_form_page.dart';
import 'waypoint_form_page.dart';

class MapPage extends StatefulWidget {
  /// Cria o mapa usando o repositório de capturas e pontos.
  const MapPage({required this.repository, super.key});

  final FishingRepository repository;

  /// Cria o estado que controla o mapa interativo.
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const _fallbackCenter = LatLng(-15.7801, -47.9292);
  final _mapController = MapController();
  final _locationService = LocationService();
  final _weatherService = WeatherService();
  final _userId = FirebaseAuth.instance.currentUser!.uid;

  Position? _position;
  LatLng? _selectedLocation;
  LatLng _center = _fallbackCenter;
  WeatherModel? _weather;
  StreamSubscription<Position>? _positionSubscription;
  bool _mapReady = false;
  bool _locating = false;
  bool _loadingWeather = false;
  bool _followingLocation = true;
  String? _locationError;
  String? _weatherError;
  DateTime? _lastWeatherUpdate;
  late final Stream<List<CatchModel>> _userCatchesStream;
  late final Stream<List<CatchModel>> _publicCatchesStream;
  late final Stream<List<WaypointModel>> _userWaypointsStream;
  late final Stream<List<WaypointModel>> _publicWaypointsStream;

  /// Prepara os fluxos de dados e inicia a localização do dispositivo.
  @override
  void initState() {
    super.initState();
    _userCatchesStream = widget.repository.watchUserCatches(_userId);
    _publicCatchesStream = widget.repository.watchPublicCatches();
    _userWaypointsStream = widget.repository.watchUserWaypoints(_userId);
    _publicWaypointsStream = widget.repository.watchPublicWaypoints();
    _refreshLocation();
  }

  /// Encerra a escuta do GPS e libera o controlador do mapa.
  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Obtém a posição atual e inicia o acompanhamento pelo GPS.
  Future<void> _refreshLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
      _followingLocation = true;
    });

    try {
      final position = await _locationService.currentPosition();
      if (!mounted) return;
      _updatePosition(position, centerMap: true);
      await _positionSubscription?.cancel();
      _positionSubscription = _locationService.positionStream().listen(
        (position) => _updatePosition(position, centerMap: _followingLocation),
        onError: (Object error) {
          if (mounted) setState(() => _locationError = error.toString());
        },
      );
    } on Exception catch (error) {
      if (mounted) setState(() => _locationError = error.toString());
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Atualiza a posição do pescador e, quando necessário, recentraliza o mapa.
  void _updatePosition(Position position, {required bool centerMap}) {
    if (!mounted) return;
    final location = LatLng(position.latitude, position.longitude);
    setState(() {
      _position = position;
      _center = location;
    });
    if (_mapReady && centerMap) {
      _mapController.move(location, math.max(_mapController.camera.zoom, 15));
    }
    final lastUpdate = _lastWeatherUpdate;
    if (lastUpdate == null ||
        DateTime.now().difference(lastUpdate) > const Duration(minutes: 10)) {
      _loadWeather(location);
    }
  }

  /// Aplica uma mudança de zoom e desativa o acompanhamento automático.
  void _zoomBy(double amount) {
    if (!_mapReady) return;

    final camera = _mapController.camera;
    final zoom = (camera.zoom + amount).clamp(2, 19).toDouble();
    setState(() => _followingLocation = false);
    _mapController.move(camera.center, zoom);
  }

  /// Consulta as condições climáticas para as coordenadas informadas.
  Future<void> _loadWeather(LatLng location) async {
    if (_loadingWeather) return;
    setState(() {
      _loadingWeather = true;
      _weatherError = null;
    });
    try {
      final weather = await _weatherService.currentAt(
        location.latitude,
        location.longitude,
      );
      if (!mounted) return;
      setState(() {
        _weather = weather;
        _lastWeatherUpdate = DateTime.now();
      });
    } on Exception catch (error) {
      if (mounted) setState(() => _weatherError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingWeather = false);
    }
  }

  /// Abre o formulário para registrar uma captura no local selecionado.
  Future<void> _addCapture() async {
    final location =
        _selectedLocation ??
        (_position == null
            ? null
            : LatLng(_position!.latitude, _position!.longitude));
    if (location == null) {
      _message(
        'Aguardando o GPS. Toque no mapa para marcar o local manualmente.',
      );
      return;
    }

    final saved = await Navigator.push<SaveResult>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CatchFormPage(location: location, repository: widget.repository),
      ),
    );
    if (saved != null && mounted) {
      setState(() => _selectedLocation = null);
      _message(saved.message ?? 'Captura salva e sincronizada com o Firebase.');
    }
  }

  /// Abre o formulário para salvar um ponto de pesca.
  Future<void> _addWaypoint() async {
    final location =
        _selectedLocation ??
        (_position == null
            ? null
            : LatLng(_position!.latitude, _position!.longitude));
    if (location == null) {
      _message(
        'Aguardando o GPS. Toque no mapa para marcar o local manualmente.',
      );
      return;
    }

    final saved = await Navigator.push<SaveResult>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            WaypointFormPage(location: location, repository: widget.repository),
      ),
    );
    if (saved != null && mounted) {
      setState(() => _selectedLocation = null);
      _message(saved.message ?? 'Ponto salvo e sincronizado com o Firebase.');
    }
  }

  /// Exibe uma mensagem temporária na tela.
  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
      );
  }

  /// Monta o mapa com capturas, pontos e controles de localização.
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CatchModel>>(
      stream: _userCatchesStream,
      builder: (context, userCatchSnapshot) {
        return StreamBuilder<List<CatchModel>>(
          stream: _publicCatchesStream,
          builder: (context, publicCatchSnapshot) {
            return StreamBuilder<List<WaypointModel>>(
              stream: _userWaypointsStream,
              builder: (context, userWaypointSnapshot) {
                return StreamBuilder<List<WaypointModel>>(
                  stream: _publicWaypointsStream,
                  builder: (context, publicWaypointSnapshot) {
                    final streamErrors = <Object>[
                      if (userCatchSnapshot.hasError) userCatchSnapshot.error!,
                      if (publicCatchSnapshot.hasError)
                        publicCatchSnapshot.error!,
                      if (userWaypointSnapshot.hasError)
                        userWaypointSnapshot.error!,
                      if (publicWaypointSnapshot.hasError)
                        publicWaypointSnapshot.error!,
                    ].map((error) => error.toString()).toSet();
                    final catches = _uniqueById([
                      ...?publicCatchSnapshot.data,
                      ...?userCatchSnapshot.data,
                    ]);
                    final waypoints = _uniqueWaypointsById([
                      ...?publicWaypointSnapshot.data,
                      ...?userWaypointSnapshot.data,
                    ]);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _center,
                            initialZoom: 13,
                            onMapReady: () {
                              _mapReady = true;
                              if (_position != null) {
                                _mapController.move(_center, 15);
                              }
                            },
                            onTap: (_, point) {
                              setState(() {
                                _selectedLocation = point;
                                _followingLocation = false;
                              });
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.apk_auth',
                              maxNativeZoom: 19,
                            ),
                            MarkerLayer(
                              markers: [
                                ...catches.map(_catchMarker),
                                ...waypoints.map(_waypointMarker),
                                if (_position != null)
                                  Marker(
                                    point: LatLng(
                                      _position!.latitude,
                                      _position!.longitude,
                                    ),
                                    width: 30,
                                    height: 30,
                                    child: const _LocationDot(),
                                  ),
                                if (_selectedLocation != null)
                                  Marker(
                                    point: _selectedLocation!,
                                    width: 42,
                                    height: 42,
                                    child: const Icon(
                                      Icons.add_location_alt,
                                      color: Color(0xFFD84343),
                                      size: 38,
                                    ),
                                  ),
                              ],
                            ),
                            RichAttributionWidget(
                              alignment: AttributionAlignment.bottomLeft,
                              attributions: const [
                                TextSourceAttribution(
                                  '© OpenStreetMap contributors',
                                ),
                              ],
                            ),
                          ],
                        ),
                        SafeArea(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                              child: _TopHud(
                                position: _position,
                                locating: _locating,
                                locationError: _locationError,
                                onLocate: _refreshLocation,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 14,
                          top: MediaQuery.paddingOf(context).top + 132,
                          child: Column(
                            children: [
                              _MapControl(
                                icon: Icons.add,
                                label: 'Aumentar zoom',
                                onPressed: () => _zoomBy(1),
                              ),
                              const SizedBox(height: 8),
                              _MapControl(
                                icon: Icons.remove,
                                label: 'Diminuir zoom',
                                onPressed: () => _zoomBy(-1),
                              ),
                              const SizedBox(height: 8),
                              _MapControl(
                                icon: Icons.my_location,
                                label: 'Centralizar no GPS',
                                onPressed: _refreshLocation,
                                busy: _locating,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 14,
                          child: SafeArea(
                            top: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _WeatherCard(
                                  weather: _weather,
                                  error: _weatherError,
                                  loading: _loadingWeather,
                                  onRefresh: () {
                                    final current = _position;
                                    if (current != null) {
                                      _loadWeather(
                                        LatLng(
                                          current.latitude,
                                          current.longitude,
                                        ),
                                      );
                                    } else {
                                      _message('Aguardando a localização GPS.');
                                    }
                                  },
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: _addCapture,
                                        icon: const Icon(Icons.add_a_photo),
                                        label: const Text('Captura'),
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                          backgroundColor: AppTheme.accent,
                                          foregroundColor: AppTheme.bg,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        onPressed: _addWaypoint,
                                        icon: const Icon(
                                          Icons.add_location_alt,
                                        ),
                                        label: const Text('Salvar ponto'),
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '© OpenStreetMap contributors',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                                if (streamErrors.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'Falha ao carregar marcadores: '
                                      '${streamErrors.join(' | ')}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// Remove capturas duplicadas mantendo apenas uma por identificador.
  List<CatchModel> _uniqueById(List<CatchModel> catches) {
    final byId = <String, CatchModel>{};
    for (final capture in catches) {
      byId[capture.id] = capture;
    }
    return byId.values.toList();
  }

  /// Remove pontos duplicados mantendo apenas um por identificador.
  List<WaypointModel> _uniqueWaypointsById(List<WaypointModel> points) {
    final byId = <String, WaypointModel>{};
    for (final point in points) {
      byId[point.id] = point;
    }
    return byId.values.toList();
  }

  /// Cria o marcador do mapa para uma captura.
  Marker _catchMarker(CatchModel capture) {
    return Marker(
      point: LatLng(capture.latitude, capture.longitude),
      width: 42,
      height: 46,
      child: GestureDetector(
        onTap: () => _showCapture(capture),
        child: Icon(
          Icons.location_on,
          color: capture.isPendingSync
              ? const Color(0xFFE0A03A)
              : const Color(0xFF168A82),
          size: 40,
        ),
      ),
    );
  }

  /// Cria o marcador do mapa para um ponto salvo.
  Marker _waypointMarker(WaypointModel waypoint) {
    return Marker(
      point: LatLng(waypoint.latitude, waypoint.longitude),
      width: 42,
      height: 46,
      child: GestureDetector(
        onTap: () => _showWaypoint(waypoint),
        child: Icon(
          Icons.place,
          color: waypoint.isPendingSync
              ? const Color(0xFFE0A03A)
              : const Color(0xFF168A82),
          size: 38,
        ),
      ),
    );
  }

  /// Exibe os detalhes de uma captura em um painel inferior.
  Future<void> _showCapture(CatchModel capture) {
    final photoFuture = widget.repository.loadCatchPhoto(capture.id);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<String?>(
                future: photoFuture,
                builder: (context, photoSnapshot) {
                  final photo = photoSnapshot.data ?? capture.photoBase64;
                  if (photoSnapshot.hasError) {
                    return const Text('Não foi possível carregar a foto.');
                  }
                  if (photo == null) return const SizedBox.shrink();
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      base64Decode(photo),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                capture.species,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${capture.weightKg?.toStringAsFixed(2) ?? '—'} kg · '
                '${capture.lengthCm?.toStringAsFixed(1) ?? '—'} cm',
              ),
              const SizedBox(height: 8),
              Text('Isca: ${capture.bait} · Equipamento: ${capture.equipment}'),
              if (capture.weather != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Clima: ${capture.weather!.description}, '
                    '${capture.weather!.temperatureC.toStringAsFixed(1)} °C',
                  ),
                ),
              if (capture.isPendingSync)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Salva neste dispositivo; aguardando sincronização.',
                  ),
                ),
              if (capture.userId == _userId)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _editCapture(capture);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteCapture(capture);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Excluir'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Exibe os detalhes de um ponto salvo em um painel inferior.
  Future<void> _showWaypoint(WaypointModel waypoint) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListTile(
          contentPadding: const EdgeInsets.all(20),
          leading: const Icon(Icons.place, color: Color(0xFFE0A03A)),
          title: Text(waypoint.name),
          subtitle: Text(
            waypoint.description ??
                '${waypoint.latitude.toStringAsFixed(5)}, '
                    '${waypoint.longitude.toStringAsFixed(5)}',
          ),
          trailing: waypoint.userId == _userId
              ? IconButton(
                  tooltip: 'Excluir ponto',
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteWaypoint(waypoint);
                  },
                  icon: const Icon(Icons.delete_outline),
                )
              : null,
        ),
      ),
    );
  }

  /// Carrega a foto e abre a captura selecionada para edição.
  Future<void> _editCapture(CatchModel capture) async {
    try {
      final photoBase64 = await widget.repository.loadCatchPhoto(capture.id);
      if (!mounted) return;
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
    } on Exception catch (error) {
      if (mounted) _message('Não foi possível abrir a captura: $error');
    }
  }

  /// Confirma e exclui a captura selecionada.
  Future<void> _deleteCapture(CatchModel capture) async {
    final confirmed = await _confirmDelete('Excluir esta captura?');
    if (!confirmed) return;
    try {
      final result = await widget.repository.deleteCatch(capture.id, _userId);
      if (mounted) {
        _message(result.message ?? 'Captura excluída e sincronizada.');
      }
    } on Exception catch (error) {
      if (mounted) _message('Não foi possível excluir: $error');
    }
  }

  /// Confirma e exclui o ponto selecionado.
  Future<void> _deleteWaypoint(WaypointModel waypoint) async {
    final confirmed = await _confirmDelete('Excluir este ponto?');
    if (!confirmed) return;
    try {
      final result = await widget.repository.deleteWaypoint(
        waypoint.id,
        _userId,
      );
      if (mounted) {
        _message(result.message ?? 'Ponto excluído e sincronizado.');
      }
    } on Exception catch (error) {
      if (mounted) _message('Não foi possível excluir: $error');
    }
  }

  /// Solicita confirmação antes de excluir um registro.
  Future<bool> _confirmDelete(String title) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
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
        ) ??
        false;
  }
}

class _LocationDot extends StatelessWidget {
  /// Cria o indicador visual da posição atual.
  const _LocationDot();

  /// Desenha o ponto de localização no mapa.
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF168AFC),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 8, spreadRadius: 2),
        ],
      ),
    );
  }
}

class _TopHud extends StatelessWidget {
  /// Cria o painel superior com estado e dados do GPS.
  const _TopHud({
    required this.position,
    required this.locating,
    required this.locationError,
    required this.onLocate,
  });

  final Position? position;
  final bool locating;
  final String? locationError;
  final VoidCallback onLocate;

  /// Mostra a posição, velocidade, rumo e ação para atualizar o GPS.
  @override
  Widget build(BuildContext context) {
    final speed = position == null ? null : position!.speed * 3.6;
    final heading = position?.heading;
    return Card(
      color: AppTheme.bg.withValues(alpha: 0.94),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Row(
          children: [
            Icon(
              position == null ? Icons.gps_not_fixed : Icons.gps_fixed,
              color: position == null
                  ? AppTheme.textSecondary
                  : AppTheme.accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    locationError == null
                        ? position == null
                              ? 'Localizando pescador...'
                              : 'GPS ativo'
                        : 'GPS indisponível',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    locationError ??
                        (position == null
                            ? 'Ative a localização ou toque no mapa'
                            : '${position!.latitude.toStringAsFixed(5)}, '
                                  '${position!.longitude.toStringAsFixed(5)}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (speed != null)
              _HudValue(
                value: '${speed.toStringAsFixed(1)} km/h',
                label: 'VELOCIDADE',
              ),
            if (heading != null && heading >= 0)
              _HudValue(value: '${heading.toStringAsFixed(0)}°', label: 'RUMO'),
            IconButton(
              tooltip: 'Atualizar GPS',
              onPressed: onLocate,
              icon: locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ],
        ),
      ),
    );
  }
}

class _HudValue extends StatelessWidget {
  /// Cria um valor compacto para o painel de dados do GPS.
  const _HudValue({required this.value, required this.label});

  final String value;
  final String label;

  /// Exibe o valor acompanhado de seu rótulo.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  /// Cria um botão de ação para os controles do mapa.
  const _MapControl({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool busy;

  /// Mostra o botão ou um indicador enquanto a ação está ocupada.
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.bg.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(14),
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  /// Cria o cartão com clima, erro ou estado de carregamento.
  const _WeatherCard({
    required this.weather,
    required this.error,
    required this.loading,
    required this.onRefresh,
  });

  final WeatherModel? weather;
  final String? error;
  final bool loading;
  final VoidCallback onRefresh;

  /// Apresenta as condições climáticas e permite atualizar os dados.
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.bg.withValues(alpha: 0.94),
      child: ListTile(
        dense: true,
        leading: Icon(
          weather == null ? Icons.cloud_outlined : Icons.wb_cloudy_outlined,
          color: AppTheme.accent,
        ),
        title: Text(
          weather == null
              ? 'Clima local'
              : '${weather!.temperatureC.toStringAsFixed(1)} °C · '
                    '${weather!.description}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          weather == null
              ? error ?? (loading ? 'Consultando...' : 'Aguardando GPS')
              : '${weather!.pressureHpa.toStringAsFixed(0)} hPa · '
                    'vento ${weather!.windSpeedMps.toStringAsFixed(1)} m/s',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: 'Atualizar clima',
          onPressed: loading ? null : onRefresh,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
        ),
      ),
    );
  }
}
