import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database/orva_repository.dart';
import 'core/theme/orva_theme.dart';
import 'features/checklists/checklists_page.dart';
import 'features/goals/goals_page.dart';
import 'features/home/home_page.dart';
import 'features/more/more_page.dart';

class OrvaApp extends ConsumerWidget {
  const OrvaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(databaseReadyProvider);
    final themeName = ref.watch(themeNameProvider).asData?.value ?? 'light';
    final themeMode = switch (themeName) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    return MaterialApp(
      title: 'Orva',
      debugShowCheckedModeBanner: false,
      theme: buildOrvaLightTheme(),
      darkTheme: buildOrvaDarkTheme(),
      themeMode: themeMode,
      home: ready.when(
        data: (_) => const MainShell(),
        loading: () => const _LoadingScreen(),
        error: (error, stack) => _StartupError(error: error),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: OrvaColors.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.spa_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          Text('orva', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 14),
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ),
    ),
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});
  final Object error;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: OrvaColors.error, size: 44),
            const SizedBox(height: 12),
            Text(
              'Não foi possível abrir o Orva',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('$error', textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;
  int _navigationRevision = 0;

  void _goTo(int index) => setState(() {
    _selectedIndex = index;
    _navigationRevision++;
  });

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onNavigate: _goTo, refreshSignal: _navigationRevision),
      const ChecklistsPage(),
      const GoalsPage(),
      const MorePage(),
    ];
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny),
            label: 'Hoje',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Checklists',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'Metas',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Mais',
          ),
        ],
      ),
    );
  }
}
