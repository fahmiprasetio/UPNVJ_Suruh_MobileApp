import 'package:flutter/foundation.dart';

import '../../core/config/tarif_config.dart';

/// Tarif Jalur A yang sedang berlaku, dibaca dari server.
///
/// Dulu angka-angka ini langsung dibaca dari [TarifConfig] di mana pun harga
/// dihitung. Sekarang admin bisa mengubahnya lewat dashboard web, jadi
/// [KalkulatorTarif] cuma menghitung dengan nilai [Tarif] yang diberikan
/// kepadanya, tidak pernah membaca [TarifConfig] langsung lagi.
@immutable
class Tarif {
  const Tarif({
    required this.anjemTarifDasar,
    required this.anjemTarifPerKm,
    required this.anjemJarakMinimalKm,
    required this.anjemJarakMaksimalKm,
    required this.jastipMakananFee,
    required this.jastipBarangFee,
    required this.jastipBarangTarifPerKm,
  });

  final int anjemTarifDasar;
  final int anjemTarifPerKm;
  final double anjemJarakMinimalKm;
  final double anjemJarakMaksimalKm;
  final int jastipMakananFee;
  final int jastipBarangFee;
  final int jastipBarangTarifPerKm;

  /// Nilai bawaan sebelum tarif sungguhan sempat diambil dari server, dan
  /// nilai yang dipakai [FakeTarifRepository] untuk tiruan.
  ///
  /// Angkanya persis [TarifConfig], yang keberadaannya sekarang murni sebagai
  /// nilai awal ini: dijaga tetap sama dengan `TarifConfig.cs` di server oleh
  /// `TarifSelarasDenganMobileTests`, sama seperti sebelum tarif bisa diubah
  /// admin. Baris awal di basis data server pun disemai dari angka yang sama.
  static const bawaan = Tarif(
    anjemTarifDasar: TarifConfig.anjemTarifDasar,
    anjemTarifPerKm: TarifConfig.anjemTarifPerKm,
    anjemJarakMinimalKm: TarifConfig.anjemJarakMinimalKm,
    anjemJarakMaksimalKm: TarifConfig.anjemJarakMaksimalKm,
    jastipMakananFee: TarifConfig.jastipMakananFee,
    jastipBarangFee: TarifConfig.jastipBarangFee,
    jastipBarangTarifPerKm: TarifConfig.jastipBarangTarifPerKm,
  );
}
