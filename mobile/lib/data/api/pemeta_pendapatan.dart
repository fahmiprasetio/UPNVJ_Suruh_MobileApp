import '../../core/api/galat_api.dart';
import '../../domain/enums.dart';
import '../../domain/models/pendapatan.dart';
import 'pemeta_dasar.dart';

/// Menerjemahkan jawaban pendapatan dari API.
///
/// Terpisah dari repositorynya dengan alasan yang sama seperti [PemetaTarif]:
/// bentuk JSON adalah hal yang paling gampang salah diasumsikan dan paling
/// sunyi kalau salah, jadi ia diuji sendiri terhadap contoh jawaban yang
/// bentuknya diambil dari `PendapatanResponse` di server.
class PemetaPendapatan {
  const PemetaPendapatan._();

  static Pendapatan pendapatan(Map<String, dynamic> isi) {
    final rincian = isi['rincian'];
    if (rincian is! Map<String, dynamic>) {
      throw const GalatServer('Jawaban server tidak memuat rincian pendapatan.');
    }

    return Pendapatan(
      totalBelumDibayar: PemetaDasar.rupiah(isi['totalBelumDibayar']) ?? 0,
      totalSudahDibayar: PemetaDasar.rupiah(isi['totalSudahDibayar']) ?? 0,
      menungguRumus: _cacah(isi['menungguRumus']),
      rincian: PemetaDasar.halaman(rincian, baris),
    );
  }

  static BarisPendapatan baris(Map<String, dynamic> isi) {
    return BarisPendapatan(
      penugasanId: PemetaDasar.teks(isi, 'penugasanId'),
      orderId: PemetaDasar.teks(isi, 'orderId'),
      kodeOrder: PemetaDasar.teks(isi, 'kodeOrder'),
      layanan: PemetaDasar.pilihan(
        ServiceType.values,
        isi['layanan'],
        'layanan',
      ),
      selesaiPada: PemetaDasar.waktu(isi, 'selesaiPada'),
      // Sengaja dibiarkan null kalau server mengirim null, tidak dijadikan nol.
      // Nol berarti "runner memang tidak dapat apa-apa", sedangkan null berarti
      // "belum bisa dihitung karena rumus bagi hasilnya belum diatur admin", dan
      // layar pendapatan menampilkan keduanya dengan kalimat yang berbeda.
      jumlah: PemetaDasar.rupiah(isi['jumlah']),
      dibayarPada: PemetaDasar.waktu(isi, 'dibayarPada'),
    );
  }

  static int _cacah(dynamic nilai) => nilai is num ? nilai.toInt() : 0;
}
