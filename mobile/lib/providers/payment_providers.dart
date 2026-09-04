import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/sumber_data.dart';
import '../data/api/api_payment_gateway.dart';
import '../data/fake/fake_order_repository.dart';
import '../data/fake/fake_payment_gateway.dart';
import '../domain/models/transaksi_pembayaran.dart';
import '../domain/repositories/payment_gateway.dart';
import 'repository_providers.dart';

/// Titik tukar payment gateway.
///
/// Cabang tiruannya perlu diberi tahu berapa harga ordernya, karena ia tidak
/// punya basis data untuk membacanya sendiri. Dibaca lewat kontrak order, bukan
/// disalin dari layar: jumlah tagihan tidak boleh datang dari sisi yang membayar.
///
/// Cabang API-nya diberi [orderHubClientProvider], `null` di jalur tiruan sama
/// seperti [orderRepositoryProvider]. Tanpa hub, `ApiPaymentGateway` tetap
/// jalan, cuma kembali murni mengintip berkala (bagian 41).
final paymentGatewayProvider = Provider<PaymentGateway>((ref) {
  if (ref.watch(sumberDataProvider) == SumberData.tiruan) {
    final gateway = FakePaymentGateway(
      hargaOrder: (orderId) async {
        final order = await ref.read(orderRepositoryProvider).getOrder(orderId);
        return order?.harga;
      },
    );
    ref.onDispose(gateway.dispose);
    return gateway;
  }

  return ApiPaymentGateway(
    klien: ref.watch(klienApiProvider),
    hub: ref.watch(orderHubClientProvider),
  );
});

/// Tombol simulator, alat penguji yang menggantikan bank klien.
///
/// Ada di kedua jalur, tapi artinya berbeda. Di jalur tiruan ia mengubah keadaan
/// di dalam aplikasi; di jalur API ia memanggil tiruan gateway di server, yang
/// hanya didaftarkan saat server berjalan di Development. Keduanya sama-sama
/// digerbangi mode build, karena tombol yang menandai order lunas tanpa uang
/// berpindah tidak boleh ada di tangan pengguna.
final simulatorPembayaranProvider = Provider<void Function(String)?>((ref) {
  if (!ref.watch(modeDebugProvider)) return null;

  final gateway = ref.watch(paymentGatewayProvider);
  return switch (gateway) {
    FakePaymentGateway() => gateway.simulasikanPembayaranMasuk,
    ApiPaymentGateway() => gateway.simulasikanPembayaranMasuk,
    _ => null,
  };
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

      final orderRepo = ref.watch(orderRepositoryProvider);
      var sudahDiteruskan = false;

      await for (final terbaru in gateway.watchTransaksi(orderId)) {
        // Hanya di jalur tiruan. Di jalur API, order sudah dimajukan server
        // sebelum jawaban ini sampai ke sini, dan kontrak order memang tidak
        // punya method untuk menyatakan sebuah order lunas.
        if (terbaru.berhasil &&
            !sudahDiteruskan &&
            orderRepo is FakeOrderRepository) {
          sudahDiteruskan = true;
          await orderRepo.tandaiSudahDibayar(orderId);
        }
        yield terbaru;
      }
    });
