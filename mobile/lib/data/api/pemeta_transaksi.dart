import '../../domain/enums.dart';
import '../../domain/models/transaksi_pembayaran.dart';
import 'pemeta_dasar.dart';

/// Menerjemahkan jawaban transaksi pembayaran dari API.
///
/// Terpisah dari repositorynya dengan alasan yang sama seperti [PemetaOrder]:
/// bentuk JSON adalah hal yang paling gampang salah diasumsikan dan paling sunyi
/// kalau salah, jadi ia diuji sendiri terhadap contoh jawaban yang benar-benar
/// diambil dari server yang berjalan.
class PemetaTransaksi {
  const PemetaTransaksi._();

  static TransaksiPembayaran transaksi(Map<String, dynamic> isi) {
    return TransaksiPembayaran(
      id: PemetaDasar.teks(isi, 'id'),
      orderId: PemetaDasar.teks(isi, 'orderId'),
      jumlah: PemetaDasar.rupiah(isi['jumlah'])!,
      status: PemetaDasar.pilihan(
        PaymentStatus.values,
        isi['status'],
        'status pembayaran',
      ),
      qrisPayload: PemetaDasar.teks(isi, 'qrisPayload'),
      dibuatPada: PemetaDasar.waktu(isi, 'dibuatPada')!,
      kedaluwarsaPada: PemetaDasar.waktu(isi, 'kedaluwarsaPada')!,
      dibayarPada: PemetaDasar.waktu(isi, 'dibayarPada'),
    );
  }
}
