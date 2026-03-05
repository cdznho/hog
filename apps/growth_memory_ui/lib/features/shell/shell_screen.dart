import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.child});

  final Widget child;

  int _locationToIndex(String location) {
    if (location.startsWith('/orgs')) return 1;
    if (location.startsWith('/runs')) return 2;
    if (location.startsWith('/reports')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  void _onSelect(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/orgs');
      case 2:
        context.go('/runs');
      case 3:
        context.go('/reports');
      case 4:
        context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _locationToIndex(location);
    final isWide = MediaQuery.sizeOf(context).width >= 980;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: isWide,
            selectedIndex: selectedIndex,
            groupAlignment: -0.85,
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary,
                          scheme.tertiary.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                    child: Icon(Icons.auto_graph_rounded, color: scheme.onPrimary),
                  ),
                  if (isWide) ...[
                    const SizedBox(width: 10),
                    Text('Growth Memory', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: Text('Overview'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.apartment_outlined),
                selectedIcon: Icon(Icons.apartment_rounded),
                label: Text('Orgs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.play_circle_outline),
                selectedIcon: Icon(Icons.play_circle_rounded),
                label: Text('Runs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.article_outlined),
                selectedIcon: Icon(Icons.article_rounded),
                label: Text('Reports'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: Text('Settings'),
              ),
            ],
            onDestinationSelected: (index) => _onSelect(context, index),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

