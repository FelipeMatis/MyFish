import 'package:flutter/material.dart';

class MyTextField extends StatefulWidget {
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

  @override
  State<MyTextField> createState() => _MyTextFieldState();
}

class _MyTextFieldState extends State<MyTextField> {
  bool hide = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: TextField(
        controller: widget.controller,
        obscureText: widget.isPassword && hide,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(widget.icon, color: const Color(0xFF9FB3D9)),
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    hide ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFF9FB3D9),
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
