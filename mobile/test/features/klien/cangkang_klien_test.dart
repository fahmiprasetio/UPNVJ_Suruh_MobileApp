import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';

import '../../support/tiruan.dart';

/// Permukaan klien punya dua tempat, dan keduanya dijangkau dari bilah bawah.
///
/// Sebelum ini Order Saya cuma ikon di pojok bilah atas: tempat yang dipakai
/// untuk hal yang jarang, padahal memesan dan memantau sama seringnya.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  setUp(() {
    final view = TestWidgetsFlutterBinding
        .ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1000, 2400);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding
        .ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> buka(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: [sumberTiruan], child: const UpnvjSuruhApp()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('terbuka di beranda, dengan bilah bawah dua tujuan', (
    tester,
  ) async {
    await buka(tester);

    expect(find.text('Mau disuruh apa hari ini?'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
  });

  testWidgets('tab Order Saya membuka riwayat', (tester) async {
    await buka(tester);

    await tester.tap(find.byTooltip('Order Saya'));
    await tester.pumpAndSettle();

    expect(find.textContaining('SRH-'), findsWidgets);
  });

  testWidgets('beranda tidak dibuang saat berpindah tab', (tester) async {
    // Dipasang di IndexedStack, bukan ditukar. Berpindah tab yang membuang layar
    // berarti daftar dimuat ulang dari awal dan posisi gulungnya lompat ke atas
    // setiap kali pengguna mengintip sebelah.
    await buka(tester);

    await tester.tap(find.byTooltip('Order Saya'));
    await tester.pumpAndSettle();

    expect(find.text('Mau disuruh apa hari ini?', skipOffstage: false),
        findsOneWidget);
  });

  testWidgets('order yang masih berjalan terhitung di tab Order Saya', (
    tester,
  ) async {
    // Yang paling sering terlupakan justru yang paling mendesak: order yang
    // menunggu dibayar berhenti di situ sampai ada yang membukanya lagi.
    await buka(tester);

    expect(find.byType(Badge), findsWidgets);
  });
}
