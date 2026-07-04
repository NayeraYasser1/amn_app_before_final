import 'package:flutter/material.dart';

/// Shows a simple floating snackbar. Centralizes the identical helper that was
/// copy-pasted (as _showMessage / _showSnack) across several screens. Callers
/// are still responsible for a `mounted` check when used after an await.
void showAppSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
