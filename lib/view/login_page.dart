import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../components/my_button.dart';
import '../components/my_textfield.dart';
import '../components/social_button.dart';
import '../theme/app_theme.dart';
import 'register_page.dart';

Future<void>? _googleSignInInitialization;

class LoginPage extends StatefulWidget {
  /// Cria a tela de autenticação.
  const LoginPage({super.key});

  /// Cria o estado que mantém os campos e ações de autenticação.
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isBusy = false;

  /// Libera os controladores dos campos ao fechar a tela.
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// Exibe uma mensagem de autenticação em uma caixa de diálogo.
  void showAlert(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Envia ao usuário o link para redefinir a senha.
  Future<void> forgotPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      showAlert('Digite seu email primeiro.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      showAlert('Enviamos um link para seu email!');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showAlert(switch (e.code) {
        'invalid-email' => 'Digite um email válido.',
        'user-not-found' => 'Não encontramos uma conta com esse email.',
        _ => 'Não foi possível enviar o link. Tente novamente.',
      });
    }
  }

  /// Autentica o usuário com e-mail e senha.
  Future<void> signIn() async {
    await _runSignIn(() async {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
    });
  }

  /// Autentica o usuário usando a conta Google.
  Future<void> signInWithGoogle() async {
    await _runSignIn(() async {
      final googleSignIn = GoogleSignIn.instance;
      await (_googleSignInInitialization ??= googleSignIn.initialize());
      final account = await googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'missing-google-id-token',
          message: 'O Google não retornou um token de autenticação.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
    });
  }

  /// Autentica o usuário usando o provedor Apple.
  Future<void> signInWithApple() async {
    await _runSignIn(() async {
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      await FirebaseAuth.instance.signInWithProvider(provider);
    });
  }

  /// Executa uma autenticação controlando carregamento e erros.
  Future<void> _runSignIn(Future<void> Function() action) async {
    if (isBusy) return;
    setState(() => isBusy = true);

    try {
      await action();
    } on FirebaseAuthException catch (e) {
      if (mounted) showAlert(_authErrorMessage(e.code));
    } on GoogleSignInException catch (e) {
      if (mounted && e.code != GoogleSignInExceptionCode.canceled) {
        showAlert(
          e.code == GoogleSignInExceptionCode.clientConfigurationError
              ? 'O login Google não está configurado. Ative o provedor no Firebase, adicione o SHA-1 do app e baixe novamente o google-services.json.'
              : 'Não foi possível entrar com Google. Verifique a configuração e tente novamente.',
        );
      }
    } on PlatformException {
      if (mounted) {
        showAlert(
          'Não foi possível abrir o login social. Verifique a configuração do provedor.',
        );
      }
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  /// Converte códigos do Firebase em mensagens para o usuário.
  String _authErrorMessage(String code) {
    return switch (code) {
      'invalid-credential' => 'Email ou senha incorretos.',
      'operation-not-allowed' =>
        'Este método de login ainda não foi ativado no Firebase.',
      'account-exists-with-different-credential' =>
        'Já existe uma conta com este email usando outro método de login.',
      'network-request-failed' =>
        'Sem conexão com a internet. Verifique sua rede e tente novamente.',
      'missing-google-id-token' => 'Não foi possível obter a credencial do Google. Verifique a configuração.',
      _ => 'Não foi possível entrar. Tente novamente.',
    };
  }

  /// Monta a tela de login e suas opções de autenticação.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Container(
                  width: 156,
                  height: 156,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.16),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: Image.asset(
                      'assets/icon/myfish_launcher.png',
                      fit: BoxFit.cover,
                      semanticLabel: 'Logo MyFish',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Seu diário de pescarias começa aqui',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                ),
                const SizedBox(height: 30),
                MyTextField(
                  controller: emailController,
                  hintText: 'Email',
                  icon: Icons.email_outlined,
                ),
                const SizedBox(height: 15),
                MyTextField(
                  controller: passwordController,
                  hintText: 'Senha',
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isBusy ? null : forgotPassword,
                    child: const Text(
                      'Esqueceu a senha?',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                MyButton(
                  onTap: isBusy ? null : signIn,
                  text: isBusy ? 'Conectando...' : 'Entrar',
                  icon: isBusy ? Icons.hourglass_top : Icons.login,
                ),
                if (isBusy) ...[
                  const SizedBox(height: 12),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accent,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Row(
                    children: const [
                      Expanded(child: Divider(color: AppTheme.cardSoft)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'ou continue com',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                      Expanded(child: Divider(color: AppTheme.cardSoft)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Row(
                    children: [
                      SocialButton(
                        icon: Icons.g_mobiledata,
                        label: 'Google',
                        onTap: isBusy ? null : signInWithGoogle,
                      ),
                      const SizedBox(width: 12),
                      SocialButton(
                        icon: Icons.apple,
                        label: 'Apple',
                        onTap: isBusy ? null : signInWithApple,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Ainda não tem conta? ',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    TextButton(
                      onPressed: isBusy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterPage(),
                              ),
                            ),
                      child: const Text(
                        'Cadastre-se',
                        style: TextStyle(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
