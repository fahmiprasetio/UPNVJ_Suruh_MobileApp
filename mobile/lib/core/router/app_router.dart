import 'package:go_router/go_router.dart';

import '../../features/shared/fondasi_screen.dart';

/// Nama rute ditulis sebagai konstanta supaya tidak ada string jalur yang
/// tersebar di dalam layar.
class Rute {
  const Rute._();

  static const String beranda = '/';
}

final GoRouter appRouter = GoRouter(
  initialLocation: Rute.beranda,
  routes: [
    GoRoute(
      path: Rute.beranda,
      builder: (context, state) => const FondasiScreen(),
    ),
  ],
);
