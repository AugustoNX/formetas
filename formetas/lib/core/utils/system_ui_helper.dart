import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class SystemUiHelper {
  static Timer? _autoHideTimer;
  static const autoHideDelay = Duration(seconds: 3);

  static Future<void> hideNavigationBar() async {
    _autoHideTimer?.cancel();

    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
    );
  }

  static void scheduleHideNavigationBar() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(autoHideDelay, hideNavigationBar);
  }

  static void dispose() {
    _autoHideTimer?.cancel();
  }
}
