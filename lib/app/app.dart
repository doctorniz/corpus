import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'providers.dart';
import 'router.dart';
import 'theme.dart';

class CorpusApp extends ConsumerStatefulWidget {
  const CorpusApp({super.key});

  @override
  ConsumerState<CorpusApp> createState() => _CorpusAppState();
}

class _CorpusAppState extends ConsumerState<CorpusApp>
    with WidgetsBindingObserver {
  late final GoRouter _router = buildRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Pull new data from the phone's health store on launch, if enabled.
    Future.microtask(() => ref.read(healthSyncProvider).start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(healthSyncProvider).syncIfEnabled();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Corpus',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: _router,
    );
  }
}
