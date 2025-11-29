import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget that prevents accidental app exit by requiring double back press
///
/// Usage:
/// ```dart
/// DoubleBackExit(
///   child: YourWidget(),
///   message: 'Press back again to exit',
/// )
/// ```
class DoubleBackExit extends StatefulWidget {
  const DoubleBackExit({
    super.key,
    required this.child,
    this.message = 'Press back again to exit',
    this.exitDuration = const Duration(seconds: 2),
  });

  final Widget child;
  final String message;
  final Duration exitDuration;

  @override
  State<DoubleBackExit> createState() => _DoubleBackExitState();
}

class _DoubleBackExitState extends State<DoubleBackExit> {
  DateTime? _lastBackPressTime;
  Timer? _snackbarTimer;

  @override
  void dispose() {
    _snackbarTimer?.cancel();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();

    // If this is the first press or enough time has passed, show message
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > widget.exitDuration) {
      _lastBackPressTime = now;
      _showExitMessage();
      return false; // Prevent exit
    }

    // Second press within time window - allow exit
    return true;
  }

  void _showExitMessage() {
    // Cancel any existing timer
    _snackbarTimer?.cancel();

    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black87,
        duration: widget.exitDuration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );

    // Reset timer after duration expires
    _snackbarTimer = Timer(widget.exitDuration, () {
      if (mounted) {
        _lastBackPressTime = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          // Exit the app
          SystemNavigator.pop();
        }
      },
      child: widget.child,
    );
  }
}
