import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/data/fake/fake_auth_repository.dart';
import 'package:upnvj_suruh/data/fake/fake_pendapatan_repository.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/halaman.dart';
import 'package:upnvj_suruh/domain/models/pendapatan.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';
import '../../support/tiruan.dart';

/// Layar Pendapatan Saya.
///
/// Yang paling penting diuji di sini bukan bahwa angkanya tampil, melainkan
/// bahwa keadaan "bayarannya belum dihitung" tidak digambar sebagai Rp 0.
/// Runner yang menyelesaikan order lalu membaca nol akan mengira pekerjaannya
/// tidak dihitung, padahal yang belum ada cuma rumus bagi hasil yang harus
/// diisi admin, dan bedanya cuma bisa diketahui kalau layarnya mengatakannya.
void main() {
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

  BarisPendapatan baris({
    String penugasanId = 'tugas-1',
    String kodeOrder = 'SRH-0412',
    int? jumlah = 12000,
    DateTime? dibayarPada,
  }) => BarisPendapatan(
    penugasanId: penugasanId,
    orderId: 'order-$penugasanId',
    kodeOrder: kodeOrder,
    layanan: ServiceType.anterJemput,
    selesaiPada: DateTime.now().subtract(const Duration(days: 1)),
    jumlah: jumlah,
    dibayarPada: dibayarPada,
  );

  Pendapatan pendapatan({
    List<BarisPendapatan>? isi,
    int belum = 12000,
    int sudah = 0,
    int menungguRumus = 0,
  }) {
    final daftar = isi ?? [baris()];
    return Pendapatan(
      totalBelumDibayar: belum,
      totalSudahDibayar: sudah,
      menungguRumus: menungguRumus,
      rincian: Halaman(isi: daftar, total: daftar.length),
    );
  }

  /// Membuka aplikasi sebagai runner lalu berpindah ke tab Pendapatan.
  Future<void> bukaPendapatan(WidgetTester tester, Pendapatan isi) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sumberTiruan,
          pendapatanRepositoryProvider.overrideWith(
            (ref) => FakePendapatanRepository(isi: isi),
          ),
          authRepositoryProvider.overrideWith((ref) {
            final repo = FakeAuthRepository(userAwal: SeedData.runner);
            ref.onDispose(repo.dispose);
            return repo;
          }),
        ],
        child: const UpnvjSuruhApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Labelnya yang diketuk, bukan NavigationBar-nya. `widgetWithText` menemukan
    // bilahnya sendiri (yang memang memuat teks itu di dalamnya), dan mengetuk
    // bilah berarti mengetuk titik tengahnya, yaitu tab yang kebetulan ada di
    // tengah, bukan tab yang namanya disebut.
    await tester.tap(find.text('Pendapatan'));
    await tester.pumpAndSettle();
  }

  testWidgets('menampilkan berapa yang belum dibayarkan', (tester) async {
    await bukaPendapatan(tester, pendapatan(belum: 12000, sudah: 40000));

    expect(find.text('Belum dibayarkan'), findsOneWidget);
    expect(find.text('Rp 12.000'), findsWidgets);
    expect(find.text('Sudah diterima: Rp 40.000'), findsOneWidget);
  });

  testWidgets('memisahkan yang sudah dibayar dari yang belum', (tester) async {
    await bukaPendapatan(
      tester,
      pendapatan(
        isi: [
          baris(),
          baris(
            penugasanId: 'tugas-2',
            kodeOrder: 'SRH-0410',
            jumlah: 40000,
            dibayarPada: DateTime.now().subtract(const Duration(days: 3)),
          ),
        ],
        sudah: 40000,
      ),
    );

    expect(find.text('Belum dibayarkan (1)'), findsOneWidget);
    expect(find.text('Sudah dibayarkan (1)'), findsOneWidget);
  });

  testWidgets('bayaran yang belum dihitung tidak digambar sebagai Rp 0', (
    tester,
  ) async {
    await bukaPendapatan(
      tester,
      pendapatan(isi: [baris(jumlah: null)], belum: 0, menungguRumus: 1),
    );

    expect(find.text('Menunggu'), findsOneWidget);

    // Rp 0 tetap muncul sekali sebagai total yang belum dibayarkan, dan itu
    // memang benar: belum ada rupiah yang bisa dijumlahkan. Yang tidak boleh
    // adalah barisnya sendiri ikut menyebut Rp 0, seolah order itu memang tidak
    // dibayar.
    expect(find.text('Rp 0'), findsOneWidget);
  });

  testWidgets('menyebutkan kenapa bayarannya belum dihitung', (tester) async {
    await bukaPendapatan(
      tester,
      pendapatan(isi: [baris(jumlah: null)], belum: 0, menungguRumus: 3),
    );

    expect(
      find.textContaining('3 order sudah selesai tapi bayarannya belum dihitung'),
      findsOneWidget,
    );
  });

  testWidgets('tidak menyebut rumus saat semuanya sudah dihitung', (
    tester,
  ) async {
    await bukaPendapatan(tester, pendapatan());

    expect(find.textContaining('belum dihitung'), findsNothing);
  });

  testWidgets('runner yang belum menyelesaikan apa pun diberi kalimatnya', (
    tester,
  ) async {
    await bukaPendapatan(tester, FakePendapatanRepository.kosong);

    expect(find.text('Belum ada pendapatan'), findsOneWidget);
  });

  /// Menandai bayaran sudah diserahkan adalah pekerjaan admin di dashboard,
  /// karena penyerahannya terjadi di luar sistem. Tombolnya di sisi runner
  /// berarti catatan itu bisa ditulis oleh pihak yang diuntungkan olehnya.
  testWidgets('tidak menawarkan cara menandai bayarannya sendiri lunas', (
    tester,
  ) async {
    await bukaPendapatan(tester, pendapatan());

    expect(find.widgetWithText(ElevatedButton, 'Tandai'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });
}
