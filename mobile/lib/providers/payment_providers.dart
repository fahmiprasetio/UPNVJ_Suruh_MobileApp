import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fake/fake_order_repository.dart';
import '../data/fake/fake_payment_gateway.dart';
import '../domain/models/transaksi_pembayaran.dart';
import '../domain/repositories/payment_gateway.dart';
import 'repository_providers.dart';

/// Titik tukar payment gateway.
///
/// Saat backend sudah diputuskan, di sinilah `MidtransPaymentGateway` (yang
/// bicara ke server, bukan langsung ke Midtrans) menggantikan tiruannya.
final paymentGatewayProvider = Provider<PaymentGateway>((ref) {
  final gateway = FakePaymentGateway();
  ref.onDispose(gateway.dispose);
  return gateway;
});

/// Tombol simulator, hanya ada selama gateway-nya masih tiruan.
///
/// Mengembalikan `null` begitu gateway sungguhan dipasang, sehingga panel
/// simulator di layar pembayaran hilang dengan sendirinya, tidak ada risiko
/// alat penguji ikut terbawa ke tangan pengguna.
final simulatorPembayaranProvider = Provider<void Function(String)?>((ref) {
  // Mode build ikut menjaga: selama gateway sungguhan belum dipasang, penjagaan
  // tipe saja tetap meloloskan tombol ini ke build rilis, dan tombol ini
  // menandai order mana pun lunas tanpa uang berpindah.
  if (!ref.watch(modeDebugProvider)) return null;
  final gateway = ref.watch(paymentGatewayProvider);
  return gateway is FakePaymentGateway
      ? gateway.simulasikanPembayaranMasuk
      : null;
});

/// Transaksi pembayaran untuk satu order, diamati sampai statusnya final.
///
/// Perhatikan siapa yang memajukan order: bukan layar, bukan klien, tapi kabar
/// dari gateway. Di produksi langkah ini pindah ke server yang menerima
/// webhook, aplikasi cuma ikut membaca hasilnya.
final transaksiOrderProvider =
    StreamProvider.family<TransaksiPembayaran, String>((ref, orderId) async* {
      final orderRepo = ref.watch(orderRepositoryProvider);
      final order = await orderRepo.getOrder(orderId);
      if (order == null) {
        throw StateError('Order $orderId tidak ditemukan');
      }
      final jumlah = order.harga;
      if (jumlah == null) {
        throw StateError(
          'Order ${order.kodeOrder} belum punya harga, belum bisa dibayar',
        );
      }

      final gateway = ref.watch(paymentGatewayProvider);
      final transaksi = await gateway.buatTransaksi(
        orderId: orderId,
        jumlah: jumlah,
      );
      yield transaksi;

      var sudahDiteruskan = false;
      await for (final terbaru in gateway.watchTransaksi(transaksi.id)) {
        // Yang memajukan order ke "mencari runner" bukan layar dan bukan klien,
        // melainkan kabar dari gateway. Di produksi langkah ini tidak terjadi di
        // sini sama sekali: server menerima webhook dan memajukan ordernya,
        // aplikasi cuma ikut membaca hasilnya. Karena itu jalannya lewat tiruan
        // repository langsung, bukan lewat kontrak, dan hilang sendiri begitu
        // backend sungguhan terpasang.
        if (terbaru.berhasil && !sudahDiteruskan && orderRepo is FakeOrderRepository) {
          sudahDiteruskan = true;
          await orderRepo.tandaiSudahDibayar(orderId);
        }
        yield terbaru;
      }
    });
