import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/core/config/kontak_bantuan.dart';
import 'package:upnvj_suruh/core/theme/app_theme.dart';
import 'package:upnvj_suruh/features/pengaturan/kebijakan_privasi_screen.dart';
import 'package:upnvj_suruh/features/pengaturan/pusat_bantuan_screen.dart';
import 'package:upnvj_suruh/features/pengaturan/syarat_ketentuan_screen.dart';

/// Isi legal di aplikasi, dan kontak bantuan yang tidak lagi tertanam di kode.
///
/// Isi kebijakan privasi ditulis di tiga tempat yang harus berkata sama: layar ini, halaman
/// publik `/kebijakan-privasi` di API, dan formulir Data Safety. Tes ini menjaga sisi
/// aplikasinya dengan daftar kata yang sama dengan `HalamanPublikTests` di backend; kalau
/// salah satu daftar diubah, ubah keduanya.
void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1000, 6000);
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

  Widget bungkus(Widget child) =>
      MaterialApp(theme: AppTheme.terang(), home: child);

  /// Seluruh teks yang tampil di layar, dalam satu string.
  String semuaTeks(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .join('\n');

  group('KebijakanPrivasiScreen', () {
    testWidgets('menyebut setiap jenis data yang dikumpulkan', (tester) async {
      await tester.pumpWidget(bungkus(const KebijakanPrivasiScreen()));
      final teks = semuaTeks(tester).toLowerCase();

      for (final kata in [
        'nomor hp',
        'alamat',
        'foto',
        'percakapan',
        'pembayaran',
        'lokasi',
        'token notifikasi',
        'exif',
      ]) {
        expect(
          teks,
          contains(kata),
          reason: 'kebijakan harus menyebut "$kata"',
        );
      }
    });

    /// Aplikasi belum bisa merekam atau melampirkan pesan suara, dan klien belum bisa
    /// melampirkan foto ke pesanan atau chat. Kebijakan tidak boleh menyebut data yang
    /// tidak pernah dikumpulkan.
    testWidgets('tidak mengklaim data yang belum dikumpulkan aplikasi', (
      tester,
    ) async {
      await tester.pumpWidget(bungkus(const KebijakanPrivasiScreen()));
      final teks = semuaTeks(tester).toLowerCase();

      expect(teks, isNot(contains('pesan suara')));
      expect(teks, isNot(contains('foto atau pesan')));
    });

    testWidgets('menyebut setiap pihak yang menerima data', (tester) async {
      await tester.pumpWidget(bungkus(const KebijakanPrivasiScreen()));
      final teks = semuaTeks(tester).toLowerCase();

      for (final pihak in [
        'midtrans',
        'firebase',
        'openstreetmap',
        'runner',
        'admin',
      ]) {
        expect(
          teks,
          contains(pihak),
          reason: 'kebijakan harus menyebut "$pihak"',
        );
      }
    });

    /// Penyedia pengirim OTP belum diputuskan mitra dan belum aktif. Menyebut namanya
    /// adalah klaim yang belum benar.
    testWidgets('tidak mengklaim penyedia OTP yang belum aktif', (
      tester,
    ) async {
      await tester.pumpWidget(bungkus(const KebijakanPrivasiScreen()));
      final teks = semuaTeks(tester);

      expect(teks.toLowerCase(), isNot(contains('whatsapp')));
      expect(teks.toLowerCase(), isNot(contains('twilio')));
      expect(teks, isNot(contains('Meta ')));
    });

    testWidgets('menjelaskan apa yang dihapus dan apa yang dipertahankan', (
      tester,
    ) async {
      await tester.pumpWidget(bungkus(const KebijakanPrivasiScreen()));

      expect(find.text('5. Menghapus akun dan data'), findsOneWidget);
      final teks = semuaTeks(tester);
      expect(teks, contains('Yang dihapus'));
      expect(teks, contains('Yang dipertahankan'));
      expect(teks, contains('Akun dihapus'));
      expect(teks, contains('pesanan yang berjalan'));
      expect(teks, contains('bayaran yang belum dicairkan'));

      // Tidak ada angka lama penyimpanan: belum ada yang menegakkannya di kode.
      expect(RegExp(r'\d+\s*(tahun|bulan)').hasMatch(teks), isFalse);
    });

    testWidgets('memuat tanggal pembaruan yang sama dengan halaman publik', (
      tester,
    ) async {
      await tester.pumpWidget(bungkus(const KebijakanPrivasiScreen()));

      expect(
        find.textContaining(
          'Terakhir diperbarui: ${KebijakanPrivasiScreen.diperbaruiPada}',
        ),
        findsOneWidget,
      );
    });

    /// Daftar yang sama dengan `HalamanPublikTests.KebijakanPrivasiMemuatBagianYangSamaDenganAplikasi`
    /// di backend. Kalau salah satu daftar diubah, ubah keduanya.
    testWidgets('judul bagian sama dengan halaman publik, urutannya juga', (
      tester,
    ) async {
      const judulDiWeb = [
        '1. Data yang kami kumpulkan',
        '2. Untuk apa data dipakai',
        '3. Dengan siapa data dibagikan',
        '4. Keamanan',
        '5. Menghapus akun dan data',
        '6. Hakmu',
        '7. Anak-anak',
        '8. Perubahan dan kontak',
      ];
      expect(KebijakanPrivasiScreen.judulBagian, judulDiWeb);

      await tester.pumpWidget(bungkus(const KebijakanPrivasiScreen()));
      for (final judul in judulDiWeb) {
        expect(
          find.text(judul),
          findsOneWidget,
          reason: 'bagian "$judul" harus tampil',
        );
      }
    });
  });

  group('SyaratKetentuanScreen', () {
    testWidgets('memuat pasal akun dan penghapusan akun', (tester) async {
      await tester.pumpWidget(bungkus(const SyaratKetentuanScreen()));

      expect(find.text('6. Akun'), findsOneWidget);
      expect(find.textContaining('menghapus akunnya sendiri'), findsOneWidget);
    });

    /// Daftar yang sama dengan `HalamanPublikTests.SyaratMemuatPasalYangSamaDenganAplikasi`
    /// di backend. Kalau salah satu daftar diubah, ubah keduanya.
    testWidgets('judul pasal sama dengan halaman publik, urutannya juga', (
      tester,
    ) async {
      const judulDiWeb = [
        '1. Ketentuan umum',
        '2. Pemesanan dan pembayaran',
        '3. Larangan dan batasan jasa',
        '4. Pelaksanaan dan bukti selesai',
        '5. Pembatalan dan pengembalian dana',
        '6. Akun',
        '7. Kontak',
      ];
      expect(SyaratKetentuanScreen.judulPasal, judulDiWeb);

      await tester.pumpWidget(bungkus(const SyaratKetentuanScreen()));
      for (final judul in judulDiWeb) {
        expect(
          find.text(judul),
          findsOneWidget,
          reason: 'pasal "$judul" harus tampil',
        );
      }
    });

    testWidgets('memuat tanggal pembaruan yang sama dengan halaman publik', (
      tester,
    ) async {
      await tester.pumpWidget(bungkus(const SyaratKetentuanScreen()));

      expect(
        find.textContaining(
          'Terakhir diperbarui: ${SyaratKetentuanScreen.diperbaruiPada}',
        ),
        findsOneWidget,
      );
      expect(
        SyaratKetentuanScreen.diperbaruiPada,
        KebijakanPrivasiScreen.diperbaruiPada,
      );
    });
  });

  group('KontakBantuan', () {
    test(
      'rilis tanpa nomor menyatakan kanal tidak tersedia, tidak mengarang nilai',
      () {
        final kontak = KontakBantuan.baca(modeDebug: false, noHp: '', jam: '');

        expect(kontak.tersedia, isFalse);
        expect(kontak.noHpWhatsapp, isEmpty);
        expect(kontak.punyaJamLayanan, isFalse);
      },
    );

    test(
      'rilis dengan nomor memakai nomor itu dan tidak mengarang jam layanan',
      () {
        final kontak = KontakBantuan.baca(
          modeDebug: false,
          noHp: ' 6281200000000 ',
          jam: '',
        );

        expect(kontak.tersedia, isTrue);
        expect(kontak.noHpWhatsapp, '6281200000000');
        expect(kontak.punyaJamLayanan, isFalse);
      },
    );

    test('nomor dan jam dari konfigurasi menang atas nilai pengembangan', () {
      final kontak = KontakBantuan.baca(
        modeDebug: true,
        noHp: '6281211112222',
        jam: 'Senin-Jumat pukul 09.00 - 17.00 WIB',
      );

      expect(kontak.noHpWhatsapp, '6281211112222');
      expect(kontak.jamLayanan, 'Senin-Jumat pukul 09.00 - 17.00 WIB');
    });

    test('mode debug tanpa konfigurasi memakai nilai pengembangan', () {
      final kontak = KontakBantuan.baca(modeDebug: true, noHp: '', jam: '');

      expect(kontak.tersedia, isTrue);
      expect(kontak.punyaJamLayanan, isTrue);
    });
  });

  group('PusatBantuanScreen', () {
    testWidgets(
      'tanpa kontak: tidak ada tombol WhatsApp dan layar menyatakannya',
      (tester) async {
        await tester.pumpWidget(
          bungkus(
            const PusatBantuanScreen(kontak: KontakBantuan.tidakTersedia),
          ),
        );

        expect(find.text('Hubungi Admin via WhatsApp'), findsNothing);
        expect(
          find.textContaining('Kontak admin belum tersedia'),
          findsOneWidget,
        );
      },
    );

    testWidgets('kontak dengan jam layanan menampilkan jam dari konfigurasi', (
      tester,
    ) async {
      await tester.pumpWidget(
        bungkus(
          const PusatBantuanScreen(
            kontak: KontakBantuan(
              noHpWhatsapp: '6281211112222',
              jamLayanan: 'Senin-Jumat pukul 09.00 - 17.00 WIB',
            ),
          ),
        ),
      );

      expect(find.text('Hubungi Admin via WhatsApp'), findsOneWidget);
      expect(
        find.textContaining('Senin-Jumat pukul 09.00 - 17.00 WIB'),
        findsOneWidget,
      );
      // Jam yang dulu tertanam tidak boleh ikut tampil.
      expect(find.textContaining('08.00 - 20.00'), findsNothing);
    });

    testWidgets('kontak tanpa jam layanan tidak mengarang jam', (tester) async {
      await tester.pumpWidget(
        bungkus(
          const PusatBantuanScreen(
            kontak: KontakBantuan(noHpWhatsapp: '6281211112222'),
          ),
        ),
      );

      expect(find.text('Hubungi Admin via WhatsApp'), findsOneWidget);
      expect(find.textContaining('pukul'), findsNothing);
    });

    testWidgets('FAQ menjelaskan cara menghapus akun', (tester) async {
      await tester.pumpWidget(
        bungkus(const PusatBantuanScreen(kontak: KontakBantuan.tidakTersedia)),
      );

      final tanya = find.text('Bagaimana cara menghapus akun saya?');
      await tester.scrollUntilVisible(tanya, 200);
      expect(tanya, findsOneWidget);

      await tester.tap(tanya);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Pengaturan lalu pilih Hapus Akun'),
        findsOneWidget,
      );
    });
  });
}
