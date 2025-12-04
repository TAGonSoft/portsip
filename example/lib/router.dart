import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:portsip_example/portsip/pages/call/call_cubit.dart';
import 'package:portsip_example/portsip/pages/call/call_page.dart';
import 'package:portsip_example/portsip/pages/connection/connection_cubit.dart';
import 'package:portsip_example/portsip/pages/connection/connection_page.dart';
import 'package:portsip_example/tab_bar_container.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/login',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return TabBarContainer(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/login',
                builder: (context, state) {
                  return BlocProvider(
                    create: (context) => ConnectionCubit(),
                    child: ConnectionPage(),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/call',
                builder: (context, state) {
                  return BlocProvider(
                    create: (context) => CallCubit(),
                    child: const CallPage(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
