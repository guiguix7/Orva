import 'dart:async';

import 'package:flutter/material.dart';

import 'core/domain/orva_calculations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database/orva_repository.dart';
import 'core/logging/orva_diagnostics.dart';
import 'core/platform/widget_bridge.dart';
import 'core/platform/widget_sync.dart';
import 'core/theme/orva_theme.dart';
import 'features/calendar/calendar_page.dart';
import 'features/checklists/checklists_page.dart';
import 'features/comparison/comparison_page.dart';
import 'features/goals/goals_page.dart';
import 'features/habits/habits_page.dart';
import 'features/home/home_page.dart';
import 'features/more/more_page.dart';
import 'features/security/lock_screen.dart';
import 'features/studies/study_page.dart';

class OrvaApp extends ConsumerStatefulWidget {
  const OrvaApp({super.key});

  @override
  ConsumerState<OrvaApp> createState() => _OrvaAppState();
}

class _OrvaAppState extends ConsumerState<OrvaApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  Timer? _clock;
  Timer? _widgetRefresh;
  StreamSubscription<String>? _widgetRoutes;
  late final WidgetSyncService _widgetSync;
  String? _pendingWidgetRoute;
  bool _routeScheduled = false;
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
    _widgetSync = WidgetSyncService(ref);
    OrvaWidgetBridge.initialize();
    _widgetRoutes = OrvaWidgetBridge.routes.listen(_handleWidgetRoute);
    // Widgets are refreshed on launch, when returning to the app and on a slow
    // foreground timer. They always display their last snapshot time.
    _widgetRefresh = Timer.periodic(const Duration(minutes: 10), (_) {
      unawaited(_widgetSync.refresh());
    });
    unawaited(_bootstrapWidgets());
  }

  Future<void> _bootstrapWidgets() async {
    try {
      await ref.read(databaseReadyProvider.future);
      await _widgetSync.refresh();
      final route = await OrvaWidgetBridge.consumeInitialRoute();
      if (route != null && mounted) _handleWidgetRoute(route);
    } catch (error, stackTrace) {
      OrvaDiagnostics.instance.recordException(
        error,
        stackTrace,
        category: 'widget-bootstrap',
        module: 'home-widgets',
        severity: DiagnosticSeverity.warning,
      );
    }
  }

  void _handleWidgetRoute(String route) {
    _pendingWidgetRoute = route;
    _schedulePendingRoute();
  }

  bool get _routesAllowed {
    final lock = ref.read(lockEnabledProvider);
    final enabled = lock.asData?.value;
    if (enabled == null) return false;
    return !enabled || _unlockedThisSession;
  }

  void _schedulePendingRoute() {
    if (_pendingWidgetRoute == null || _routeScheduled) return;
    if (!_routesAllowed) return;
    _routeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeScheduled = false;
      _openPendingRoute();
    });
  }

  void _openPendingRoute() {
    if (!mounted || _pendingWidgetRoute == null) return;
    if (!_routesAllowed) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    final route = _pendingWidgetRoute!;
    _pendingWidgetRoute = null;
    final page = switch (route) {
      'tasks' => const ChecklistsPage(),
      'goals' => const GoalsPage(),
      'comparison' => const ComparisonPage(),
      'habits' => const HabitsPage(),
      'study' => const StudyPage(),
      'agenda' => const CalendarPage(),
      // today/progress open the app on Home; there is no separate destination.
      _ => null,
    };
    if (page == null) return;
    navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _now = DateTime.now());
      unawaited(_widgetSync.refresh());
      _schedulePendingRoute();
    }
    if (state == AppLifecycleState.paused && mounted) {
      // Ao voltar do segundo plano, a tela de bloqueio reaparece se o
      // bloqueio estiver ativo (checado de novo no build via lockEnabledProvider).
      setState(() => _unlockedThisSession = false);
      unawaited(_widgetSync.refresh());
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _widgetRefresh?.cancel();
    _widgetRoutes?.cancel();
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
    if (_pendingWidgetRoute != null && _routesAllowed) {
      _schedulePendingRoute();
    }
    return MaterialApp(
      title: 'Orva',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildOrvaLightTheme(),
      darkTheme: buildOrvaDarkTheme(),
      themeMode: themeMode,
      home: ready.when(
        data: (_) => _unlockedThisSession
            ? const MainShell()
            : ref
                  .watch(lockEnabledProvider)
                  .when(
                    data: (lockEnabled) => lockEnabled
                        ? LockScreen(
                            onUnlocked: () {
                              setState(() => _unlockedThisSession = true);
                              _schedulePendingRoute();
                            },
                          )
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
      // At the root, Android may exit normally. From another main tab, the
      // first Back returns to Home instead of closing the app accidentally.
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIndex != 0) _goTo(0);
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
