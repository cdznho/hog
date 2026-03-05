import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/shell/shell_screen.dart';
import '../../features/overview/overview_screen.dart';
import '../../features/orgs/orgs_screen.dart';
import '../../features/orgs/org_detail_screen.dart';
import '../../features/runs/runs_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/settings/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const OverviewScreen()),
          GoRoute(
            path: '/orgs',
            builder: (context, state) => const OrgsScreen(),
            routes: [
              GoRoute(
                path: ':orgId',
                builder: (context, state) => OrgDetailScreen(orgId: state.pathParameters['orgId']!),
              ),
            ],
          ),
          GoRoute(path: '/runs', builder: (context, state) => const RunsScreen()),
          GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
          GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text(state.error?.toString() ?? 'Unknown routing error')),
    ),
  );
});

