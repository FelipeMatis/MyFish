import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_page.dart';
import 'login_page.dart';

class AuthPage extends StatelessWidget {
  /// Cria a página que decide entre login e conteúdo autenticado.
  const AuthPage({super.key});

  /// Observa a sessão do Firebase e abre a tela correspondente.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) return const HomePage();
          return const LoginPage();
        },
      ),
    );
  }
}
