import 'package:flutter/foundation.dart';

import '../enums.dart';
import '../models/tarif.dart';

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
/// diuji langsung dan dipindahkan ke backend apa adanya nanti. Kembaran
/// `KalkulatorTarif.Hitung` di server, dan bentuknya sengaja sama supaya
/// perbedaan hasil antara keduanya ketahuan sebagai perbedaan angka, bukan
/// sebagai perbedaan cara memanggil.
///
/// [Tarif] diterima sebagai parameter wajib di setiap fungsi, bukan dibaca
/// dari konstanta statis: angkanya sekarang datang dari server dan bisa
/// diubah admin. Tidak ada nilai bawaan untuk parameter ini dengan sengaja —
/// layar yang lupa mengambil tarif dari [tarifProvider] akan gagal saat
/// dikompilasi, bukan diam-diam menghitung dengan angka yang salah.
class KalkulatorTarif {
  const KalkulatorTarif._();

  /// Harga satu layanan Jalur A.
  ///
  /// Yang mengikat tetap hitungan server. Hitungan di sini gunanya menampilkan
  /// rincian sebelum klien memesan, supaya ia tidak perlu menekan tombol dulu
  /// untuk tahu berapa yang akan ditagih.
  static HasilTarif hitung(
    ServiceType serviceType,
    double? jarakKm,
    Tarif tarif, {
    int jumlahRunner = 1,
    MovingVehicleType? jenisKendaraan,
  }) {
    if (serviceType.track != OrderTrack.jalurA) {
      throw StateError(
        '${serviceType.name} adalah Jalur B, harganya ditentukan admin lewat '
        'penawaran',
      );
    }

    return switch (serviceType) {
      ServiceType.anterJemput => anterJemput(
        jarakKm: _wajibJarak(serviceType, jarakKm),
        tarif: tarif,
      ),
      ServiceType.jastipBarang => jastipBarang(
        jarakKm: _wajibJarak(serviceType, jarakKm),
        tarif: tarif,
      ),
      ServiceType.jastipMakanan => jastipMakanan(tarif: tarif),
      ServiceType.bantuPindahKos => pindahKos(
        jarakKm: _wajibJarak(serviceType, jarakKm),
        jumlahRunner: jumlahRunner,
        jenisKendaraan: jenisKendaraan,
        tarif: tarif,
      ),
      ServiceType.bersihKos => _tarifTetap(
        'Jasa bersih-bersih kos',
        tarif.bersihKosFee,
      ),
      ServiceType.bersihKamarMandi => _tarifTetap(
        'Jasa bersih kamar mandi',
        tarif.bersihKamarMandiFee,
      ),
      _ => throw StateError('${serviceType.name} belum punya rumus tarif'),
    };
  }

  static double _wajibJarak(ServiceType serviceType, double? jarakKm) {
    if (jarakKm == null) {
      throw StateError('${serviceType.name} butuh jarak untuk dihitung');
    }
    if (jarakKm.isNaN || jarakKm.isInfinite) {
      throw StateError('Jarak bukan angka yang sah');
    }
    return jarakKm;
  }

  /// Jastip Makanan: fee tetap, harga makanannya dibayar terpisah.
  ///
  /// Tidak bergantung jarak, jadi tidak menerima jarak sama sekali. Parameter yang
  /// diterima lalu diabaikan akan dibaca orang berikutnya sebagai sesuatu yang
  /// berpengaruh.
  static HasilTarif jastipMakanan({required Tarif tarif}) => HasilTarif(
    rincian: [
      RincianTarif(label: 'Ongkos jasa titip', nominal: tarif.jastipMakananFee),
    ],
    total: tarif.jastipMakananFee,
  );

  /// Anter jemput: tarif dasar + ongkos jarak.
  ///
  /// [jarakKm] diisi sendiri oleh klien sebagai perkiraan. Ini konsekuensi dari
  /// keputusan memakai alamat teks bebas, bukan pin peta (rencana capstone
  /// bagian 14.8), tanpa peta, sistem tidak punya cara menghitung jarak
  /// sendiri. Selisih kecil diselesaikan runner dan klien di lapangan.
  static HasilTarif anterJemput({
    required double jarakKm,
    required Tarif tarif,
  }) {
    final jarakDipakai = jarakKm.clamp(
      tarif.anjemJarakMinimalKm,
      tarif.anjemJarakMaksimalKm,
    );
    final ongkosJarak = (jarakDipakai * tarif.anjemTarifPerKm).round();

    return HasilTarif(
      rincian: [
        RincianTarif(label: 'Tarif dasar', nominal: tarif.anjemTarifDasar),
        RincianTarif(
          label: 'Jarak ${_formatJarak(jarakDipakai)} km',
          nominal: ongkosJarak,
        ),
      ],
      total: tarif.anjemTarifDasar + ongkosJarak,
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
  static HasilTarif jastipBarang({
    required double jarakKm,
    required Tarif tarif,
  }) {
    final jarakDipakai = jarakKm.clamp(
      tarif.anjemJarakMinimalKm,
      tarif.anjemJarakMaksimalKm,
    );
    final ongkosJarak = (jarakDipakai * tarif.jastipBarangTarifPerKm).round();

    return HasilTarif(
      rincian: [
        RincianTarif(
          label: 'Ongkos jasa titip',
          nominal: tarif.jastipBarangFee,
        ),
        RincianTarif(
          label: 'Jarak ${_formatJarak(jarakDipakai)} km',
          nominal: ongkosJarak,
        ),
      ],
      total: tarif.jastipBarangFee + ongkosJarak,
    );
  }

  static HasilTarif pindahKos({
    required double jarakKm,
    required int jumlahRunner,
    required MovingVehicleType? jenisKendaraan,
    required Tarif tarif,
  }) {
    if (jumlahRunner < 1 || jumlahRunner > 5) {
      throw StateError('Jumlah runner harus 1 sampai 5');
    }
    if (jenisKendaraan == null) {
      throw StateError('Pilih kendaraan untuk pindahan');
    }

    final jarakDipakai = jarakKm.clamp(
      tarif.anjemJarakMinimalKm,
      tarif.anjemJarakMaksimalKm,
    );
    final ongkosJarak = (jarakDipakai * tarif.pindahKosTarifPerKm).round();
    final tambahanRunner = (jumlahRunner - 1) * tarif.pindahKosTambahanRunner;
    final tambahanKendaraan = switch (jenisKendaraan) {
      MovingVehicleType.motor => 0,
      MovingVehicleType.mobil => tarif.pindahKosTambahanMobil,
      MovingVehicleType.pickup => tarif.pindahKosTambahanPickup,
    };
    final rincian = <RincianTarif>[
      RincianTarif(
        label: 'Jasa pindah kos',
        nominal: tarif.pindahKosTarifDasar,
      ),
      RincianTarif(
        label: 'Jarak ${_formatJarak(jarakDipakai)} km',
        nominal: ongkosJarak,
      ),
      if (tambahanRunner > 0)
        RincianTarif(
          label: 'Tambahan ${jumlahRunner - 1} runner',
          nominal: tambahanRunner,
        ),
      if (tambahanKendaraan > 0)
        RincianTarif(
          label: 'Kendaraan ${jenisKendaraan.label}',
          nominal: tambahanKendaraan,
        ),
    ];
    return HasilTarif(
      rincian: rincian,
      total: rincian.fold(0, (jumlah, baris) => jumlah + baris.nominal),
    );
  }

  static HasilTarif _tarifTetap(String label, int nominal) => HasilTarif(
    rincian: [RincianTarif(label: label, nominal: nominal)],
    total: nominal,
  );

  static String _formatJarak(double jarak) => jarak == jarak.roundToDouble()
      ? jarak.toStringAsFixed(0)
      : jarak.toStringAsFixed(1).replaceAll('.', ',');
}
