import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SocialButton extends StatelessWidget {
  /// Cria um botão reutilizável para autenticação social.
  const SocialButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Exibe o botão social com estilo consistente com o app.
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppTheme.card,
          foregroundColor: AppTheme.accent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: AppTheme.accent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
