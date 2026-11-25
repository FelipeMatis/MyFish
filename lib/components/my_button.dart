import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MyButton extends StatelessWidget {
  /// Cria um botão reutilizável com texto, ícone opcional e ação.
  const MyButton({
    super.key,
    required this.onTap,
    required this.text,
    this.icon,
  });

  final VoidCallback? onTap;
  final String text;
  final IconData? icon;

  /// Monta o botão com as cores do tema MyFish.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: onTap == null
                  ? AppTheme.accent.withValues(alpha: 0.55)
                  : AppTheme.accent,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) Icon(icon, color: AppTheme.bg),
                if (icon != null) const SizedBox(width: 10),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppTheme.bg,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
