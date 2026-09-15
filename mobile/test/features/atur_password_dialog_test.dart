import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/data/fake/fake_auth_repository.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';

import '../support/tiruan.dart';

/// Mengatur password sendiri lewat Pengaturan: minta kode ke nomor sendiri,
/// lalu isi password.
///
/// Diuji lewat aplikasi utuh dari layar Pengaturan, bukan `AturPasswordDialog`
/// sendirian, mengikuti alasan yang sama dengan
/// `ganti_nomor_hp_dialog_test.dart`: yang paling mungkin salah adalah
/// sambungannya ke `authRepositoryProvider` yang sama dengan yang menonton
/// `userAktifProvider`, bukan isi dialognya sendiri.
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

  Future<FakeAuthRepository> bukaDialog(WidgetTester tester) async {
    final authRepo = FakeAuthRepository(userAwal: SeedData.klien);
    addTearDown(authRepo.dispose);
    final orderRepo = FakeOrderRepository(pemanggil: () => SeedData.klien.id);
    addTearDown(orderRepo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sumberTiruan,
          authRepositoryProvider.overrideWith((ref) => authRepo),
          orderRepositoryProvider.overrideWith((ref) => orderRepo),
        ],
        child: const UpnvjSuruhApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Pengaturan'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Password'));
    await tester.pumpAndSettle();

    return authRepo;
  }

  const passwordBaru = 'sandiAmanBaru123';

  testWidgets('alur lengkap sampai PunyaPassword benar di akun aktif', (
    tester,
  ) async {
    final authRepo = await bukaDialog(tester);
    expect(find.text('Atur password'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Kirim kode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final kode = authRepo.kodeUntuk(SeedData.klien.noHp);
    expect(kode, isNotNull);

    await tester.enterText(find.widgetWithText(TextFormField, 'Kode'), kode!);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password baru'),
      passwordBaru,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(authRepo.userAktif?.punyaPassword, isTrue);

    // Kembali ke Pengaturan lewat tumpukan navigasi, judul dialog berikutnya
    // sudah berubah jadi "Ganti password" -- bukti kartunya sungguhan
    // membaca `punyaPassword`, bukan menampilkan teks tetap.
    await tester.tap(find.widgetWithText(ListTile, 'Password'));
    await tester.pumpAndSettle();
    expect(find.text('Ganti password'), findsOneWidget);
  });

  testWidgets('kode yang salah menampilkan galat, dialog tidak tertutup', (
    tester,
  ) async {
    final authRepo = await bukaDialog(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Kirim kode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kode'),
      '000000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password baru'),
      passwordBaru,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Kode salah'), findsOneWidget);
    expect(authRepo.userAktif?.punyaPassword, isFalse);
  });

  testWidgets('password yang terlalu pendek ditolak sebelum ke server', (
    tester,
  ) async {
    final authRepo = await bukaDialog(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Kirim kode'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final kode = authRepo.kodeUntuk(SeedData.klien.noHp);
    await tester.enterText(find.widgetWithText(TextFormField, 'Kode'), kode!);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password baru'),
      'pendek',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pump();

    // Ditolak validator lokal: tidak ada jeda jaringan yang harus ditunggu.
    expect(find.textContaining('Minimal'), findsOneWidget);
  });

  testWidgets('batal di langkah awal tidak mengirim kode apa pun', (
    tester,
  ) async {
    final authRepo = await bukaDialog(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Batal'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(authRepo.kodeUntuk(SeedData.klien.noHp), isNull);
    expect(authRepo.userAktif?.punyaPassword, isFalse);
  });
}
