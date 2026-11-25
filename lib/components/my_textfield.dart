import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MyTextField extends StatefulWidget {
  /// Cria um campo de texto com ícone e opção de senha.
  const MyTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.isPassword = false,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool isPassword;

  /// Cria o estado que controla a visibilidade do campo de senha.
  @override
  State<MyTextField> createState() => _MyTextFieldState();
}

class _MyTextFieldState extends State<MyTextField> {
  bool hide = true;

  /// Monta o campo e controla a visibilidade da senha.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: TextField(
        controller: widget.controller,
        obscureText: widget.isPassword && hide,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          prefixIcon: Icon(widget.icon, color: AppTheme.accent),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    hide ? Icons.visibility_off : Icons.visibility,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () => setState(() => hide = !hide),
                )
              : null,
          hintText: widget.hintText,
        ),
      ),
    );
  }
}
