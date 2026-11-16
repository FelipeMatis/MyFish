import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  void openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Início', 'Buscar', 'Perfil'];
    final pages = [
      _HomeTab(
        onOpenProfile: () => setState(() => selectedIndex = 2),
        onOpenSettings: openSettings,
      ),
      _SearchTab(
        onOpenProfile: () => setState(() => selectedIndex = 2),
        onOpenSettings: openSettings,
      ),
      const _ProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[selectedIndex]),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF07111F), Color(0xFF111B2E)],
          ),
        ),
        child: IndexedStack(index: selectedIndex, children: pages),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => setState(() => selectedIndex = index),
        backgroundColor: const Color(0xFF0D1728),
        selectedItemColor: Colors.white,
        unselectedItemColor: const Color(0xFF9FB3D9),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.onOpenProfile, required this.onOpenSettings});

  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Olá,',
            style: TextStyle(color: Color(0xFF9FB3D9), fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            email ?? 'Usuário',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 26),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Você está logado com sucesso!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Ações rápidas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              onTap: onOpenProfile,
              leading: const Icon(Icons.person_outline, color: Colors.white),
              title: const Text('Meu perfil'),
              subtitle: const Text('Veja os dados da sua conta'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              onTap: onOpenSettings,
              leading: const Icon(Icons.settings_outlined, color: Colors.white),
              title: const Text('Configurações'),
              subtitle: const Text('Preferências e segurança da conta'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchTab extends StatefulWidget {
  const _SearchTab({required this.onOpenProfile, required this.onOpenSettings});

  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        title: 'Meu perfil',
        subtitle: 'Veja os dados da sua conta',
        icon: Icons.person_outline,
        onTap: widget.onOpenProfile,
      ),
      (
        title: 'Configurações',
        subtitle: 'Preferências e segurança da conta',
        icon: Icons.settings_outlined,
        onTap: widget.onOpenSettings,
      ),
    ].where((action) => action.title.toLowerCase().contains(query)).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            onChanged: (value) =>
                setState(() => query = value.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Buscar ações',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      onPressed: () => setState(() => query = ''),
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (actions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Nenhuma ação encontrada.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9FB3D9)),
              ),
            )
          else
            ...actions.map(
              (action) => Card(
                child: ListTile(
                  onTap: action.onTap,
                  leading: Icon(action.icon, color: Colors.white),
                  title: Text(action.title),
                  subtitle: Text(action.subtitle),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 42,
              backgroundColor: const Color(0xFF7C3AED),
              backgroundImage: user?.photoURL == null
                  ? null
                  : NetworkImage(user!.photoURL!),
              child: user?.photoURL != null
                  ? null
                  : const Icon(Icons.person, size: 42, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              user?.displayName ?? 'Minha conta',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              subtitle: Text(user?.email ?? 'Não informado'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Método de login'),
              subtitle: Text(
                user?.providerData.map((item) => item.providerId).join(', ') ??
                    'Não informado',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _sendPasswordReset(BuildContext context) async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A conta não possui um email cadastrado.'),
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Link de redefinição enviado para $email.')),
      );
    } on FirebaseAuthException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível enviar o link. Tente novamente.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.dark_mode_outlined),
              title: Text('Aparência'),
              subtitle: Text('Tema escuro'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.password_outlined),
              title: const Text('Redefinir senha'),
              subtitle: const Text('Enviaremos um link para seu email'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () => _sendPasswordReset(context),
            ),
          ),
        ],
      ),
    );
  }
}
