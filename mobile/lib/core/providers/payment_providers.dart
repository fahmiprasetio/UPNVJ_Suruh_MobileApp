import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/sumber_data.dart';
import '../../data/api/api_payment_gateway.dart';
import '../../domain/models/transaksi_pembayaran.dart';
import '../../domain/repositories/payment_gateway.dart';
import 'repository_providers.dart';

/// Titik tukar payment gateway.
///
/// Pembayaran hanya tersedia melalui API Midtrans Snap. Jalur data tiruan tidak pernah
/// mendapatkan gateway pembayaran agar tidak dapat menyatakan order lunas tanpa webhook.
final paymentGatewayProvider = Provider<PaymentGateway>((ref) {
  if (ref.watch(sumberDataProvider) == SumberData.tiruan) {
    throw StateError('Pembayaran hanya tersedia melalui Midtrans Snap.');
  }

  return ApiPaymentGateway(
    klien: ref.watch(klienApiProvider),
    hub: ref.watch(orderHubClientProvider),
  );
});

/// Transaksi pembayaran untuk satu order, diamati sampai statusnya final.
///
/// Perhatikan siapa yang memajukan order: bukan layar, bukan klien, tapi kabar
/// dari gateway. Di jalur API langkah itu tidak terjadi di sini sama sekali,
/// server yang menerima webhook dan memajukan ordernya; aplikasi cuma ikut
/// membaca hasilnya.
final transaksiOrderProvider =
    StreamProvider.family<TransaksiPembayaran, String>((ref, orderId) async* {
      final gateway = ref.watch(paymentGatewayProvider);
      final transaksi = await gateway.buatTransaksi(orderId: orderId);
      yield transaksi;

      await for (final terbaru in gateway.watchTransaksi(orderId)) {
        yield terbaru;
      }
    });
