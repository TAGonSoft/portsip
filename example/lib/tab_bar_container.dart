import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class TabBarContainer extends StatefulWidget {
  const TabBarContainer({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<TabBarContainer> createState() => _TabBarContainerState();
}

class _TabBarContainerState extends State<TabBarContainer> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Request microphone permission (required for both platforms)
    await Permission.microphone.request();

    // Request Android-specific permissions for ConnectionService
    if (Platform.isAndroid) {
      await [
        Permission.phone, // READ_PHONE_STATE, CALL_PHONE
        Permission.bluetoothConnect, // BLUETOOTH_CONNECT for audio routing
      ].request();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.router_outlined),
            label: 'Connection',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined),
            label: 'Call',
          ),
        ],
      ),
    );
  }
}
