import 'package:flutter/material.dart';
import 'package:portsip_example/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PortSIP Example',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      routerConfig: AppRouter.router,
    );
  }
}
