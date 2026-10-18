import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/core/providers/payment_providers.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/transaksi_pembayaran.dart';
import 'package:upnvj_suruh/domain/repositories/payment_gateway.dart';
import 'package:upnvj_suruh/features/klien/pembayaran/pembayaran_screen.dart';

class _GatewaySnap implements PaymentGateway {
  static final transaksi = TransaksiPembayaran(
    id: 'trx-uji',
    orderId: 'o-uji',
    jumlah: 11000,
    status: PaymentStatus.pending,
    checkoutUrl: 'https://app.sandbox.midtrans.com/snap/v2/vtweb/token-uji',
    dibuatPada: DateTime(2026, 1, 1, 12),
    kedaluwarsaPada: DateTime(2026, 1, 1, 12, 30),
  );

  @override
  Future<void> batalkanTransaksi(String orderId) async {}

  @override
  Future<TransaksiPembayaran> buatTransaksi({required String orderId}) async =>
      transaksi;

  @override
  Stream<TransaksiPembayaran> watchTransaksi(String orderId) async* {
    yield transaksi;
  }
}

void main() {
  testWidgets('hanya menampilkan checkout Midtrans Snap', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [paymentGatewayProvider.overrideWithValue(_GatewaySnap())],
        child: const MaterialApp(home: PembayaranScreen(orderId: 'o-uji')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bayar dengan Midtrans'), findsOneWidget);
    expect(find.text('Buka Midtrans'), findsOneWidget);
    expect(find.text('ALAT PENGUJI'), findsNothing);
    expect(find.textContaining('QRIS'), findsNothing);
  });
}
