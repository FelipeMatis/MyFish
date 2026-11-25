import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../components/my_button.dart';
import '../components/my_textfield.dart';
import '../theme/app_theme.dart';

class RegisterPage extends StatefulWidget {
  /// Cria a tela de cadastro de pescador.
  const RegisterPage({super.key});

  /// Cria o estado que controla o formulário de cadastro.
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  /// Libera os controladores dos campos ao fechar a tela.
  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  /// Exibe uma mensagem de cadastro em uma caixa de diálogo.
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

  /// Valida os campos e cria a conta no Firebase Authentication.
  Future<void> register() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirm = confirmController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      showAlert('Preencha nome, email e senha.');
      return;
    }

    if (password != confirm) {
      showAlert('As senhas não conferem!');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-created',
          message: 'A conta foi criada sem retornar o usuário.',
        );
      }
      await user.updateDisplayName(name);

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showAlert(switch (e.code) {
        'email-already-in-use' => 'Já existe um usuário com esse email!',
        'weak-password' => 'Escolha uma senha mais forte.',
        'user-not-created' =>
          'A conta foi criada, mas o perfil não retornou corretamente.',
        _ => 'Não foi possível cadastrar. Tente novamente.',
      });
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      showAlert('Não foi possível cadastrar. Tente novamente.');
    }
  }

  /// Monta o formulário para criar uma conta.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Crie sua conta'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Container(
                  width: 94,
                  height: 94,
                  decoration: BoxDecoration(
                    color: AppTheme.cardSoft,
                    border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 46,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Crie sua conta',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Comece agora com sua conta pessoal',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                ),
                const SizedBox(height: 30),
                MyTextField(
                  controller: nameController,
                  hintText: 'Nome completo',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 15),
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
                const SizedBox(height: 15),
                MyTextField(
                  controller: confirmController,
                  hintText: 'Confirmar senha',
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 28),
                MyButton(
                  onTap: register,
                  text: 'Registrar',
                  icon: Icons.person_add,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
