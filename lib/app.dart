import 'dart:async';

import 'package:flutter/material.dart';
import 'core/domain/orva_calculations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database/orva_repository.dart';
import 'core/theme/orva_theme.dart';
import 'features/checklists/checklists_page.dart';
import 'features/goals/goals_page.dart';
import 'features/home/home_page.dart';
import 'features/more/more_page.dart';
import 'features/security/lock_screen.dart';

class OrvaApp extends ConsumerStatefulWidget {
  const OrvaApp({super.key});

  @override
  ConsumerState<OrvaApp> createState() => _OrvaAppState();
}

class _OrvaAppState extends ConsumerState<OrvaApp> with WidgetsBindingObserver {
  Timer? _clock;
  DateTime _now = DateTime.now();
  // Estado de desbloqueio da sessão atual. Começa travado; é liberado pela
  // LockScreen (via PIN/biometria). Reaberturas e retomadas do segundo plano
  // voltam a travar quando o bloqueio está ativo (ver didChangeAppLifecycleState).
  bool _unlockedThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _now = DateTime.now());
    }
    if (state == AppLifecycleState.paused && mounted) {
      // Ao voltar do segundo plano, a tela de bloqueio reaparece se o
      // bloqueio estiver ativo (checado de novo no build via lockEnabledProvider).
      setState(() => _unlockedThisSession = false);
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(databaseReadyProvider);
    final themeName = ref.watch(themeNameProvider).asData?.value ?? 'light';
    final themeMode = switch (themeName) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      'dayNight' => isNightTheme(_now) ? ThemeMode.dark : ThemeMode.light,
      _ => ThemeMode.light,
    };
    return MaterialApp(
      title: 'Orva',
      debugShowCheckedModeBanner: false,
      theme: buildOrvaLightTheme(),
      darkTheme: buildOrvaDarkTheme(),
      themeMode: themeMode,
      home: ready.when(
        data: (_) => _unlockedThisSession
            ? const MainShell()
            : ref.watch(lockEnabledProvider).when(
                  data: (lockEnabled) => lockEnabled
                      ? LockScreen(onUnlocked: () => setState(() => _unlockedThisSession = true))
                      : const MainShell(),
                  loading: () => const _LoadingScreen(),
                  error: (error, stack) => const MainShell(), // Falha ao ler a preferência de bloqueio não deve trancar o usuário fora do app.
                ),
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
    return PopScope<Object?>(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        // Nas abas secundárias, voltar primeiro leva à Home. Na raiz, o Android
        // mantém o comportamento nativo de saída do aplicativo.
        if (didPop || _selectedIndex == 0 || !mounted) return;
        setState(() {
          _selectedIndex = 0;
          _navigationRevision++;
        });
      },
      child: Scaffold(
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
      ),
    );
  }
}
