import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/core/theme/app_theme.dart';
import 'package:upnvj_suruh/features/pengaturan/kebijakan_privasi_screen.dart';
import 'package:upnvj_suruh/features/pengaturan/pusat_bantuan_screen.dart';
import 'package:upnvj_suruh/features/pengaturan/syarat_ketentuan_screen.dart';
import 'package:upnvj_suruh/features/pengaturan/tentang_aplikasi_screen.dart';

void main() {
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

  Widget bungkus(Widget child) {
    return MaterialApp(
      theme: AppTheme.terang(),
      home: child,
    );
  }

  group('PusatBantuanScreen', () {
    testWidgets('menampilkan header bantuan dan butir FAQ yang bisa diperluas', (
      tester,
    ) async {
      await tester.pumpWidget(bungkus(const PusatBantuanScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Pusat Bantuan'), findsOneWidget);
      expect(find.text('Butuh Bantuan Mendesak?'), findsOneWidget);
      expect(find.text('Hubungi Admin via WhatsApp'), findsOneWidget);

      final faqTitle = find.text('Apa perbedaan Jalur A dan Jalur B?');
      expect(faqTitle, findsOneWidget);

      await tester.tap(faqTitle);
      await tester.pumpAndSettle();

      expect(find.textContaining('Jalur A (Anter Jemput'), findsOneWidget);
    });
  });

  group('SyaratKetentuanScreen', () {
    testWidgets('menampilkan seluruh pasal syarat dan ketentuan', (tester) async {
      await tester.pumpWidget(bungkus(const SyaratKetentuanScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Syarat & Ketentuan'), findsOneWidget);
      expect(find.text('1. Ketentuan Umum'), findsOneWidget);
      expect(find.text('2. Pemesanan dan Pembayaran'), findsOneWidget);
      expect(find.text('3. Larangan dan Batasan Jasa'), findsOneWidget);
      expect(find.text('4. Pelaksanaan dan Bukti Selesai'), findsOneWidget);
      expect(find.text('5. Pembatalan dan Pengembalian Dana'), findsOneWidget);
    });
  });

  group('KebijakanPrivasiScreen', () {
    testWidgets('menampilkan komitmen privasi dan butir perlindungan data', (
      tester,
    ) async {
      await tester.pumpWidget(bungkus(const KebijakanPrivasiScreen()));
      await tester.pumpAndSettle();

      // Judul muncul di AppBar dan judul konten utama
      expect(find.text('Kebijakan Privasi'), findsNWidgets(2));
      expect(find.text('Penggunaan Nomor Telepon'), findsOneWidget);
      expect(find.text('Privasi Lokasi dan Alamat Kos'), findsOneWidget);
      expect(find.text('Pembersihan Metadata Foto (EXIF)'), findsOneWidget);
      expect(find.text('Keamanan Autentikasi dan Kata Sandi'), findsOneWidget);
      expect(find.text('Hak Pembaruan Data Pengguna'), findsOneWidget);
    });
  });

  group('TentangAplikasiScreen', () {
    testWidgets('menampilkan logo, versi, profil mitra, dan tim founder', (
      tester,
    ) async {
      await tester.pumpWidget(bungkus(const TentangAplikasiScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Tentang Aplikasi'), findsOneWidget);
      expect(find.text('UPNVJ Suruh'), findsOneWidget);
      expect(find.text('Versi 1.0.0 (Build Capstone)'), findsOneWidget);
      expect(find.text('Profil Mitra Inisiatif'), findsOneWidget);
      expect(find.text('Founder & Tim Mitra'), findsOneWidget);
      expect(find.text('Tugas Akhir / Capstone Project'), findsOneWidget);
      expect(find.textContaining('Jiro Rizayanto'), findsOneWidget);
    });
  });
}
