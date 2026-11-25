import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../repositories/fishing_repository.dart';
import '../theme/app_theme.dart';
import 'calendar_page.dart';
import 'diary_page.dart';
import 'map_page.dart';

class HomePage extends StatefulWidget {
  /// Cria a página principal com mapa, diário, calendário e perfil.
  const HomePage({super.key});

  /// Cria o estado que mantém as abas e a sincronização offline.
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _repository = FishingRepository();
  int _selectedIndex = 0;
  Timer? _syncRetryTimer;
  bool _syncInProgress = false;
  String? _lastSyncMessage;
  late final StreamSubscription<List<ConnectivityResult>>
  _connectivitySubscription;

  /// Registra observadores e inicia as tentativas de sincronização.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (results) {
        if (results.any((result) => result != ConnectivityResult.none)) {
          _syncPendingRecords();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (mounted) _showSyncMessage('Não foi possível verificar a conexão.');
      },
    );
    _syncRetryTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _syncPendingRecords(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPendingRecords());
  }

  /// Tenta sincronizar registros quando o aplicativo volta ao primeiro plano.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncPendingRecords();
  }

  /// Cancela temporizadores, observadores e inscrição de conectividade.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncRetryTimer?.cancel();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  /// Envia ao Firebase os registros pendentes e informa eventuais erros.
  Future<void> _syncPendingRecords() async {
    if (_syncInProgress) return;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    _syncInProgress = true;
    try {
      final message = await _repository.syncPendingForUser(userId);
      if (message == null) {
        _lastSyncMessage = null;
      } else if (mounted && message != _lastSyncMessage) {
        _lastSyncMessage = message;
        _showSyncMessage(message);
      }
    } on Object catch (error, stackTrace) {
      developer.log(
        'Falha ao sincronizar registros pendentes.',
        name: 'HomePage',
        error: error,
        stackTrace: stackTrace,
      );
      final message = 'Falha ao sincronizar: $error';
      if (mounted && message != _lastSyncMessage) {
        _lastSyncMessage = message;
        _showSyncMessage(message);
      }
    } finally {
      _syncInProgress = false;
    }
  }

  /// Exibe uma mensagem temporária relacionada à sincronização.
  void _showSyncMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Monta as abas principais e a navegação inferior.
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final pages = [
      MapPage(repository: _repository),
      DiaryPage(repository: _repository, userId: user.uid),
      CalendarPage(repository: _repository),
      _ProfilePage(user: user, repository: _repository),
    ];
    const titles = ['Mapa de pesca', 'Meu diário', 'Calendário', 'Meu perfil'];

    return Scaffold(
      appBar: _selectedIndex == 0
          ? null
          : AppBar(
              title: Text(titles[_selectedIndex]),
              actions: [
                if (_selectedIndex == 3)
                  IconButton(
                    tooltip: 'Sair',
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout),
                  ),
              ],
            ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Diário',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendário',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  /// Cria o perfil para o usuário e repositório informados.
  const _ProfilePage({required this.user, required this.repository});

  final User user;
  final FishingRepository repository;

  /// Mostra as estatísticas calculadas a partir das capturas do usuário.
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: repository.watchUserCatches(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Não foi possível carregar o perfil: ${snapshot.error}',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final catches = snapshot.data!;
        final heaviest = catches
            .where((capture) => capture.weightKg != null)
            .fold<double?>(
              null,
              (largest, capture) =>
                  largest == null || capture.weightKg! > largest
                  ? capture.weightKg
                  : largest,
            );
        final speciesCounts = <String, int>{};
        for (final capture in catches) {
          speciesCounts.update(
            capture.species,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
        final favoriteSpecies = speciesCounts.entries.isEmpty
            ? null
            : speciesCounts.entries.reduce(
                (a, b) => a.value >= b.value ? a : b,
              );

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),
            Center(
              child: CircleAvatar(
                radius: 42,
                backgroundColor: AppTheme.cardSoft,
                backgroundImage: user.photoURL == null
                    ? null
                    : NetworkImage(user.photoURL!),
                child: user.photoURL != null
                    ? null
                    : const Icon(
                        Icons.person_outline,
                        size: 42,
                        color: AppTheme.accent,
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                user.displayName?.trim().isNotEmpty == true
                    ? user.displayName!
                    : user.email ?? 'Pescador MyFish',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                user.email ?? 'Email não informado',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            _ProfileStat(
              icon: Icons.set_meal,
              title: 'Capturas',
              value: '${catches.length}',
            ),
            _ProfileStat(
              icon: Icons.scale_outlined,
              title: 'Maior peso',
              value: heaviest == null
                  ? 'Ainda sem registros'
                  : '${heaviest.toStringAsFixed(2)} kg',
            ),
            _ProfileStat(
              icon: Icons.set_meal_outlined,
              title: 'Espécie mais pescada',
              value: favoriteSpecies?.key ?? 'Ainda sem registros',
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Sair da conta'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileStat extends StatelessWidget {
  /// Cria um cartão para exibir uma estatística do perfil.
  const _ProfileStat({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  /// Desenha o título e o valor da estatística.
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.accent),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }
}
