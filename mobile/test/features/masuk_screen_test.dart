import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/core/config/batas_masukan.dart';
import 'package:upnvj_suruh/data/fake/fake_auth_repository.dart';
import 'package:upnvj_suruh/data/fake/fake_order_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/core/providers/repository_providers.dart';
import '../support/tiruan.dart';

/// Alur masuk diuji lewat aplikasi utuh, bukan layarnya sendirian, karena yang
/// paling mungkin salah bukan isi layarnya melainkan sambungannya: apakah
/// pengguna yang belum masuk benar-benar diantar ke sini, dan apakah ia benar-benar
/// pergi dari sini begitu sesinya ada.
void main() {
  const passwordUji = 'sandiAman123';

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1000, 2400);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<FakeAuthRepository> bukaBelumMasuk(WidgetTester tester) async {
    final authRepo = FakeAuthRepository.belumMasuk();
    addTearDown(authRepo.dispose);
    final orderRepo = FakeOrderRepository();
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
    return authRepo;
  }

  Future<void> isi(WidgetTester tester, String label, String nilai) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), nilai);
    await tester.pump();
  }

  Future<void> isiKode(WidgetTester tester, String nilai) async {
    await tester.enterText(find.byType(TextField), nilai);
    await tester.pump();
    if (nilai.length == 6) {
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }
  }

  /// Menekan tombol lewat tulisannya.
  ///
  /// Sengaja bukan `widgetWithText(ButtonStyleButton, ...)`: `byType` mencocokkan
  /// tipe persis, sementara `ButtonStyleButton` abstrak, jadi `FilledButton` tidak
  /// pernah cocok dan finder-nya diam-diam kosong.
  Future<void> tekan(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> mulaiMasuk(
    WidgetTester tester,
    String noHp, {
    String password = passwordUji,
  }) async {
    await isi(tester, 'Nomor WhatsApp / HP', noHp);
    await isi(tester, 'Password', password);
    await tekan(tester, 'Lanjut & Kirim OTP');
  }

  testWidgets('layar masuk memperkenalkan aplikasinya, bukan cuma memintanya', (
    tester,
  ) async {
    await bukaBelumMasuk(tester);

    // Ini layar pertama yang dilihat orang baru. Kalau isinya cuma kolom nomor
    // HP dan tombol, yang dimintanya adalah kepercayaan tanpa memberi satu pun
    // alasan untuk itu. Lencana, nama, dan satu kalimat tentang apa yang
    // dikerjakan aplikasi ini adalah alasan yang paling murah.
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('UPNVJ Suruh'), findsOneWidget);
    expect(
      find.text('Apa pun yang kamu suruh, kami usahakan.'),
      findsOneWidget,
    );
  });

  testWidgets('kolom nama tidak memajang penghitung hurufnya', (tester) async {
    await bukaBelumMasuk(tester);
    await tekan(tester, 'Daftar Sekarang');

    // Batasnya tetap ditegakkan validator, cuma angkanya yang tidak dipajang.
    // "0/100" di bawah kolom nama mengabarkan batas yang tidak akan pernah
    // didekati siapa pun yang sedang mengetik namanya sendiri.
    expect(find.text('0/${BatasMasukan.nama}'), findsNothing);
  });

  testWidgets('yang belum masuk diantar ke layar masuk', (tester) async {
    await bukaBelumMasuk(tester);

    expect(find.text('UPNVJ Suruh'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Nomor WhatsApp / HP'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.text('Lanjut & Kirim OTP'), findsOneWidget);
  });

  testWidgets('nomor yang bentuknya salah ditolak sebelum menyentuh server', (
    tester,
  ) async {
    final repo = await bukaBelumMasuk(tester);

    await isi(tester, 'Nomor WhatsApp / HP', '12345');
    await isi(tester, 'Password', passwordUji);
    await tekan(tester, 'Lanjut & Kirim OTP');

    expect(find.textContaining('diawali 08'), findsOneWidget);
    // Tidak ada kode yang diminta, jadi tidak ada permintaan yang terkirim.
    expect(repo.kodeUntuk('12345'), isNull);
    expect(find.text('Lanjut & Kirim OTP'), findsOneWidget);
  });

  testWidgets('nomor kosong ditolak', (tester) async {
    await bukaBelumMasuk(tester);

    await tekan(tester, 'Lanjut & Kirim OTP');

    expect(find.text('Nomor HP belum diisi'), findsOneWidget);
  });

  testWidgets('nomor yang benar membawa ke langkah kode', (tester) async {
    final repo = await bukaBelumMasuk(tester);

    await mulaiMasuk(tester, SeedData.klien.noHp);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining(SeedData.klien.noHp), findsOneWidget);
    expect(repo.kodeUntuk(SeedData.klien.noHp), isNotNull);
  });

  testWidgets(
    'kode yang benar memasukkan pengguna dan layar masuk ditinggalkan',
    (tester) async {
      final repo = await bukaBelumMasuk(tester);

      await mulaiMasuk(tester, SeedData.klien.noHp);
      await isiKode(tester, repo.kodeUntuk(SeedData.klien.noHp)!);

      // Yang memindahkan layar adalah berubahnya sesi, bukan layar yang mendorong
      // dirinya sendiri.
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Lanjut & Kirim OTP'), findsNothing);
      expect(repo.userAktif?.id, SeedData.klien.id);
    },
  );

  testWidgets('kode yang salah menampilkan galat dan tetap di langkah kode', (
    tester,
  ) async {
    final repo = await bukaBelumMasuk(tester);

    await mulaiMasuk(tester, SeedData.klien.noHp);
    final benar = repo.kodeUntuk(SeedData.klien.noHp)!;
    await isiKode(tester, benar == '000000' ? '111111' : '000000');

    expect(find.text('Nomor, password, atau kode tidak cocok'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(repo.userAktif, isNull);
  });

  testWidgets('kode yang bentuknya salah ditolak sebelum dikirim', (
    tester,
  ) async {
    final repo = await bukaBelumMasuk(tester);

    await mulaiMasuk(tester, SeedData.klien.noHp);
    await isiKode(tester, '123');
    await tekan(tester, 'Verifikasi & Masuk');

    expect(find.text('Kode terdiri dari 6 angka'), findsOneWidget);
    expect(repo.userAktif, isNull);
  });

  testWidgets('ganti nomor mengembalikan ke langkah nomor', (tester) async {
    await bukaBelumMasuk(tester);

    await mulaiMasuk(tester, SeedData.klien.noHp);
    await tekan(tester, 'Ubah Nomor');

    expect(find.text('Lanjut & Kirim OTP'), findsOneWidget);
    expect(find.text('Verifikasi & Masuk'), findsNothing);
  });

  testWidgets('password yang salah tidak mengirim OTP atau membuka sesi', (
    tester,
  ) async {
    final repo = await bukaBelumMasuk(tester);

    await tester.runAsync(() async {
      repo.pakaiAkunUji(SeedData.klien);
      await repo.mintaKode(noHp: SeedData.klien.noHp);
      await repo.aturPassword(
        kode: repo.kodeUntuk(SeedData.klien.noHp)!,
        password: passwordUji,
      );
      await repo.keluar();
    });
    await tester.pump();

    await mulaiMasuk(tester, SeedData.klien.noHp, password: 'salahTotal99');

    // Jawaban langkah pertama tetap generik agar keberadaan akun tidak bocor,
    // tetapi tidak ada OTP yang dikirim dan sesi tetap kosong.
    expect(find.text('Verifikasi Kode OTP'), findsOneWidget);
    expect(repo.kodeUntuk(SeedData.klien.noHp), isNull);
    expect(repo.userAktif, isNull);
  });

  testWidgets('langkah kode menawarkan jalan keluar bagi yang belum punya akun', (
    tester,
  ) async {
    // Minta kode berakhir sama saja untuk nomor yang tidak terdaftar, jadi orang
    // yang belum punya akun baru tahu di langkah ini. Di sini pula ia harus diberi
    // jalan keluar, kalau tidak ia terjebak menunggu kode yang tidak akan datang.
    await bukaBelumMasuk(tester);

    await mulaiMasuk(tester, '089999999999');

    expect(find.text('Verifikasi & Masuk'), findsOneWidget);
    expect(find.textContaining('Daftar Akun Baru'), findsOneWidget);
  });

  group('daftar', () {
    testWidgets('mendaftar lalu langsung diantar ke langkah kode', (
      tester,
    ) async {
      final repo = await bukaBelumMasuk(tester);

      await tester.tap(find.text('Daftar Sekarang'));
      await tester.pumpAndSettle();
      await isi(tester, 'Nama Lengkap', 'Sari Utami');
      await isi(tester, 'Nomor WhatsApp / HP', '081200000001');
      await isi(tester, 'Buat Password', passwordUji);
      await isi(tester, 'Ulangi Password', passwordUji);
      await tekan(tester, 'Daftar & Kirim OTP');

      // Nomornya tidak perlu diketik ulang untuk minta kode.
      expect(find.text('Verifikasi & Masuk'), findsOneWidget);
      expect(repo.kodeUntuk('081200000001'), isNotNull);
    });

    testWidgets('akun hasil pendaftaran bisa langsung masuk sebagai klien', (
      tester,
    ) async {
      final repo = await bukaBelumMasuk(tester);

      await tester.tap(find.text('Daftar Sekarang'));
      await tester.pumpAndSettle();
      await isi(tester, 'Nama Lengkap', 'Sari Utami');
      await isi(tester, 'Nomor WhatsApp / HP', '081200000001');
      await isi(tester, 'Buat Password', passwordUji);
      await isi(tester, 'Ulangi Password', passwordUji);
      await tekan(tester, 'Daftar & Kirim OTP');
      await isiKode(tester, repo.kodeUntuk('081200000001')!);

      expect(repo.userAktif!.nama, 'Sari Utami');
      expect(repo.userAktif!.isRunner, isFalse);
      expect(repo.userAktif!.isAdmin, isFalse);
    });

    testWidgets('nama kosong ditolak', (tester) async {
      await bukaBelumMasuk(tester);

      await tester.tap(find.text('Daftar Sekarang'));
      await tester.pumpAndSettle();
      await isi(tester, 'Nomor WhatsApp / HP', '081200000001');
      await isi(tester, 'Buat Password', passwordUji);
      await isi(tester, 'Ulangi Password', passwordUji);
      await tekan(tester, 'Daftar & Kirim OTP');

      expect(find.text('Nama lengkap belum diisi'), findsOneWidget);
    });

    testWidgets('nomor yang sudah terdaftar tidak dibedakan di layar', (
      tester,
    ) async {
      // Dulu layar ini memunculkan "sudah terdaftar", dan kalimat itu adalah cara
      // memeriksa siapa saja yang punya akun: ketik nomor seseorang, dan layarnya
      // menyebutkan jawabannya. Sekarang jalannya sama persis dengan nomor baru,
      // yaitu lanjut ke langkah kode, jadi tidak ada yang bisa disimpulkan dari sini.
      final repo = await bukaBelumMasuk(tester);

      await tester.tap(find.text('Daftar Sekarang'));
      await tester.pumpAndSettle();
      await isi(tester, 'Nama Lengkap', 'Kembar');
      await isi(tester, 'Nomor WhatsApp / HP', SeedData.klien.noHp);
      await isi(tester, 'Buat Password', passwordUji);
      await isi(tester, 'Ulangi Password', passwordUji);
      await tekan(tester, 'Daftar & Kirim OTP');

      expect(find.textContaining('sudah terdaftar'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      // Sampai di sini ia belum masuk: kodenya masih harus dibuktikan, dan kode itu
      // dikirim ke nomornya, bukan ke orang yang mengetiknya.
      expect(repo.userAktif, isNull);
    });

    testWidgets('yang nomornya sudah terdaftar masuk ke akunnya sendiri', (
      tester,
    ) async {
      // Sisi lain dari aturan yang sama, dan yang membuatnya tidak sekadar menutup
      // mulut layar: orang yang lupa bahwa ia sudah punya akun tetap sampai ke
      // akunnya, dengan nama lamanya, bukan nama yang baru saja ia ketik.
      final repo = await bukaBelumMasuk(tester);

      await tester.tap(find.text('Daftar Sekarang'));
      await tester.pumpAndSettle();
      await isi(tester, 'Nama Lengkap', 'Kembar');
      await isi(tester, 'Nomor WhatsApp / HP', SeedData.klien.noHp);
      await isi(tester, 'Buat Password', passwordUji);
      await isi(tester, 'Ulangi Password', passwordUji);
      await tekan(tester, 'Daftar & Kirim OTP');

      await isiKode(tester, repo.kodeUntuk(SeedData.klien.noHp)!);

      expect(repo.userAktif?.nama, SeedData.klien.nama);
    });

    testWidgets('sudah punya akun mengembalikan ke langkah nomor', (
      tester,
    ) async {
      await bukaBelumMasuk(tester);

      await tester.tap(find.text('Daftar Sekarang'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Masuk di sini'));
      await tester.pumpAndSettle();

      expect(find.text('Lanjut & Kirim OTP'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Nama Lengkap'), findsNothing);
    });
  });

  testWidgets('keluar mengembalikan pengguna ke layar masuk', (tester) async {
    // Sisi lain dari pengalihan yang sama. Tanpa router yang menyimak sesi, layar
    // dalam tetap terbuka setelah pengguna keluar.
    final authRepo = FakeAuthRepository();
    addTearDown(authRepo.dispose);
    final orderRepo = FakeOrderRepository();
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
    expect(find.text('Lanjut & Kirim OTP'), findsNothing);

    // Tidak di-await di sini. Timer di dalamnya baru berjalan saat pengujinya
    // memompa frame, jadi menunggunya lebih dulu akan menggantung selamanya.
    unawaited(authRepo.keluar());
    // Jamnya dimajukan sendiri. `pumpAndSettle` berhenti begitu tidak ada frame
    // terjadwal, dan layar yang diam tidak menjadwalkan apa pun, jadi jeda di
    // dalam `keluar` tidak akan pernah lewat kalau cuma mengandalkan itu.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Lanjut & Kirim OTP'), findsOneWidget);
  });

  /// Kalimat yang menjelaskan kenapa orangnya tiba-tiba ada di layar masuk.
  ///
  /// Sesi yang berakhir sendiri tanpa keterangan terbaca sebagai aplikasi yang rusak,
  /// dan orang yang mengira aplikasinya rusak tidak mencoba masuk lagi. Yang dijaga di
  /// sini dua-duanya: kalimatnya muncul saat memang sesinya ditolak, dan TIDAK muncul
  /// untuk orang yang menekan keluar sendiri — kesalahan yang sama merugikannya, cuma
  /// ke arah sebaliknya.
  testWidgets('menjelaskan sesi yang berakhir sendiri', (tester) async {
    final authRepo = FakeAuthRepository.belumMasuk();
    addTearDown(authRepo.dispose);
    final orderRepo = FakeOrderRepository();
    addTearDown(orderRepo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sumberTiruan,
          authRepositoryProvider.overrideWith((ref) => authRepo),
          orderRepositoryProvider.overrideWith((ref) => orderRepo),
          sesiDitolakProvider.overrideWith(SesiDitolakYangSudahMenyala.new),
        ],
        child: const UpnvjSuruhApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Sesimu telah berakhir'), findsOneWidget);
  });

  testWidgets(
    'tidak menuduh sesi berakhir sendiri saat orangnya keluar sendiri',
    (tester) async {
      await bukaBelumMasuk(tester);

      expect(find.textContaining('Sesimu telah berakhir'), findsNothing);
    },
  );
}

/// Keadaan "sesi terakhir ditolak server", dipasang tes tanpa perlu server yang
/// sungguh menolak apa pun. Rangkaian dari 401 sampai ke keadaan ini diuji terpisah
/// di `test/providers/sesi_ditolak_test.dart`.
class SesiDitolakYangSudahMenyala extends SesiDitolak {
  @override
  bool build() => true;
}
