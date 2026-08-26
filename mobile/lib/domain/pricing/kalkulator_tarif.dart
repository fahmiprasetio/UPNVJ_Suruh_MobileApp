import 'package:flutter/foundation.dart';

import '../../core/config/tarif_config.dart';

/// Satu baris rincian pembentuk harga.
///
/// Harga Jalur A ditampilkan terurai, bukan sebagai satu angka gelap. Klien
/// yang bisa melihat "tarif dasar sekian, jarak sekian" tidak perlu bertanya
/// ke admin, dan itulah gunanya kalkulator harga otomatis.
@immutable
class RincianTarif {
  const RincianTarif({required this.label, required this.nominal});

  final String label;
  final int nominal;
}

@immutable
class HasilTarif {
  const HasilTarif({required this.rincian, required this.total});

  final List<RincianTarif> rincian;
  final int total;
}

/// Kalkulator harga Jalur A.
///
/// Fungsi murni tanpa ketergantungan ke Flutter maupun jaringan, supaya bisa
/// diuji langsung dan dipindahkan ke backend apa adanya nanti. Semua angkanya
/// datang dari [TarifConfig], jangan pernah menulis angka tarif di layar.
class KalkulatorTarif {
  const KalkulatorTarif._();

  /// Anter jemput: tarif dasar + ongkos jarak.
  ///
  /// [jarakKm] diisi sendiri oleh klien sebagai perkiraan. Ini konsekuensi dari
  /// keputusan memakai alamat teks bebas, bukan pin peta (rencana capstone
  /// bagian 14.8), tanpa peta, sistem tidak punya cara menghitung jarak
  /// sendiri. Selisih kecil diselesaikan runner dan klien di lapangan.
  static HasilTarif anterJemput({required double jarakKm}) {
    final jarakDipakai = jarakKm.clamp(
      TarifConfig.anjemJarakMinimalKm,
      TarifConfig.anjemJarakMaksimalKm,
    );
    final ongkosJarak = (jarakDipakai * TarifConfig.anjemTarifPerKm).round();

    return HasilTarif(
      rincian: [
        const RincianTarif(
          label: 'Tarif dasar',
          nominal: TarifConfig.anjemTarifDasar,
        ),
        RincianTarif(
          label: 'Jarak ${_formatJarak(jarakDipakai)} km',
          nominal: ongkosJarak,
        ),
      ],
      total: TarifConfig.anjemTarifDasar + ongkosJarak,
    );
  }

  /// Jastip Barang: ongkos jasa titip + ongkos jarak.
  ///
  /// Harga barangnya sendiri TIDAK dihitung di sini. Berapa harga barang baru
  /// diketahui setelah runner sampai di tempat, sementara sistem menuntut
  /// pembayaran di depan. Bentrokan itu belum diputuskan mitra (rencana
  /// capstone bagian 14.7a), jadi yang ditagih aplikasi untuk sekarang hanya
  /// jasanya. Begitu mitra menjawab, rumus ini yang berubah, bukan layarnya.
  ///
  /// Batas jarak untuk sementara memakai batas anter jemput, karena mitra
  /// belum memberi angka sendiri untuk jastip.
  static HasilTarif jastipBarang({required double jarakKm}) {
    final jarakDipakai = jarakKm.clamp(
      TarifConfig.anjemJarakMinimalKm,
      TarifConfig.anjemJarakMaksimalKm,
    );
    final ongkosJarak = (jarakDipakai * TarifConfig.jastipBarangTarifPerKm)
        .round();

    return HasilTarif(
      rincian: [
        const RincianTarif(
          label: 'Ongkos jasa titip',
          nominal: TarifConfig.jastipBarangFee,
        ),
        RincianTarif(
          label: 'Jarak ${_formatJarak(jarakDipakai)} km',
          nominal: ongkosJarak,
        ),
      ],
      total: TarifConfig.jastipBarangFee + ongkosJarak,
    );
  }

  static String _formatJarak(double jarak) =>
      jarak == jarak.roundToDouble()
      ? jarak.toStringAsFixed(0)
      : jarak.toStringAsFixed(1).replaceAll('.', ',');
}
