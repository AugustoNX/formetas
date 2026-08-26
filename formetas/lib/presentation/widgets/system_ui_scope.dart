import 'package:flutter/material.dart';

import '../../core/utils/system_ui_helper.dart';

class SystemUiScope extends StatefulWidget {
  const SystemUiScope({super.key, required this.child});

  final Widget child;

  @override
  State<SystemUiScope> createState() => _SystemUiScopeState();
}

class _SystemUiScopeState extends State<SystemUiScope> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemUiHelper.hideNavigationBar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemUiHelper.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemUiHelper.hideNavigationBar();
    }
  }

  @override
  void didChangeMetrics() {
    SystemUiHelper.scheduleHideNavigationBar();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
