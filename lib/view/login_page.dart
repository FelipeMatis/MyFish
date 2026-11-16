import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../components/my_button.dart';
import '../components/my_textfield.dart';
import '../components/social_button.dart';
import 'register_page.dart';

Future<void>? _googleSignInInitialization;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isBusy = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

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

  Future<void> signIn() async {
    await _runSignIn(() async {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
    });
  }

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

  Future<void> signInWithApple() async {
    await _runSignIn(() async {
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      await FirebaseAuth.instance.signInWithProvider(provider);
    });
  }

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
          'Não foi possível entrar com Google. Verifique a configuração e tente novamente.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF07111F), Color(0xFF111B2E)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Container(
                    width: 94,
                    height: 94,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED)
                              .withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 46,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Bem-vindo de volta!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Acesse sua conta para continuar',
                    style: TextStyle(color: Color(0xFF9FB3D9), fontSize: 15),
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
                        style: TextStyle(color: Color(0xFF9FB3D9)),
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Row(
                      children: const [
                        Expanded(child: Divider(color: Color(0xFF24354F))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'ou continue com',
                            style: TextStyle(color: Color(0xFF9FB3D9)),
                          ),
                        ),
                        Expanded(child: Divider(color: Color(0xFF24354F))),
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
                        style: TextStyle(color: Color(0xFF9FB3D9)),
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
                            color: Colors.white,
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
      ),
    );
  }
}
