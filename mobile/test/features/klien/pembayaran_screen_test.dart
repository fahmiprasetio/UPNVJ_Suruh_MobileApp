import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:upnvj_suruh/app.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/transaksi_pembayaran.dart';
import 'package:upnvj_suruh/domain/repositories/payment_gateway.dart';
import 'package:upnvj_suruh/features/klien/pembayaran/pembayaran_screen.dart';
import 'package:upnvj_suruh/providers/payment_providers.dart';

import '../../support/tiruan.dart';

class _GatewayGagalSekali implements PaymentGateway {
  var _jumlahPercobaan = 0;

  static final _transaksi = TransaksiPembayaran(
    id: 'trx-uji',
    orderId: 'o-uji',
    jumlah: 11000,
    status: PaymentStatus.pending,
    qrisPayload: 'SIMULASI-QRIS|trx=trx-uji',
    dibuatPada: DateTime(2026, 1, 1, 12),
    kedaluwarsaPada: DateTime(2026, 1, 1, 12, 30),
  );

  @override
  Future<TransaksiPembayaran> buatTransaksi({required String orderId}) async {
    if (_jumlahPercobaan++ == 0) {
      throw StateError('detail rahasia dari server');
    }
    return _transaksi;
  }

  @override
  Stream<TransaksiPembayaran> watchTransaksi(String orderId) async* {
    yield _transaksi;
  }

  @override
  Future<void> batalkanTransaksi(String orderId) async {}
}

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

  /// Menempuh alur sungguhan sampai layar bayar: buat order anter jemput,
  /// mendarat di detailnya, lalu tekan Bayar Sekarang.
  Future<void> bukaPembayaran(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: [sumberTiruan], child: const UpnvjSuruhApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Anter Jemput'));
    await tester.pumpAndSettle();

    final kolom = find.byType(TextFormField);
    await tester.enterText(kolom.at(0), 'Kos Melati, Jl. Pondok Labu No. 12');
    await tester.enterText(kolom.at(1), 'Gedung FIK UPNVJ');
    await tester.enterText(kolom.at(2), '3');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buat Order'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bayar Sekarang'));
    await tester.pumpAndSettle();
  }

  testWidgets('galat pembayaran disamarkan dan bisa dicoba lagi', (
    tester,
  ) async {
    final gateway = _GatewayGagalSekali();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [paymentGatewayProvider.overrideWithValue(gateway)],
        child: const MaterialApp(home: PembayaranScreen(orderId: 'o-uji')),
      ),
    );
    await tester.pump();

    expect(find.text('Pembayaran tidak bisa dimulai'), findsOneWidget);
    expect(
      find.text('Sambungan ke server terputus. Coba lagi, ya.'),
      findsOneWidget,
    );
    expect(find.text('detail rahasia dari server'), findsNothing);
    expect(find.text('Coba lagi'), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Bayar dengan QRIS'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('menampilkan kode QR dan jumlah yang harus dibayar', (
    tester,
  ) async {
    await bukaPembayaran(tester);

    expect(find.text('Bayar dengan QRIS'), findsOneWidget);
    expect(find.text('Rp 11.000'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('klien tidak diberi cara menyatakan dirinya sudah membayar', (
    tester,
  ) async {
    await bukaPembayaran(tester);

    expect(
      find.text(
        'Status berubah sendiri begitu gateway mengabarkan uangnya masuk. '
        'Tidak perlu mengirim bukti transfer.',
      ),
      findsOneWidget,
    );
    // Satu-satunya tombol yang mengubah status ada di panel alat penguji,
    // dan panel itu menyebut dirinya apa adanya.
    expect(find.text('ALAT PENGUJI'), findsOneWidget);
  });

  testWidgets('kabar dari gateway memajukan order ke pencarian runner', (
    tester,
  ) async {
    await bukaPembayaran(tester);

    await tester.tap(find.text('Simulasikan pembayaran masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Pembayaran diterima'), findsOneWidget);

    await tester.tap(find.text('Lihat Order'));
    await tester.pumpAndSettle();

    // Order tidak lagi menunggu pembayaran, sudah disiarkan ke runner.
    expect(
      find.text('Ordermu sedang disiarkan ke runner yang tersedia.'),
      findsOneWidget,
    );
    expect(find.text('Bayar Sekarang'), findsNothing);
  });

  testWidgets('membuka ulang layar bayar tidak membuat QR baru', (
    tester,
  ) async {
    await bukaPembayaran(tester);

    // Key QR mengikuti id transaksi, jadi key yang sama berarti transaksi
    // yang sama, bukan QR baru.
    final qrPertama = tester.widget<QrImageView>(find.byType(QrImageView)).key;

    // pageBack() mencari tooltip berbahasa Inggris; aplikasi ini locale id_ID.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bayar Sekarang'));
    await tester.pumpAndSettle();

    final qrKedua = tester.widget<QrImageView>(find.byType(QrImageView)).key;
    expect(qrKedua, qrPertama);
  });
}
