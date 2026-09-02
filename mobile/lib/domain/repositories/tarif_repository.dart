import '../models/tarif.dart';

/// Tarif Jalur A yang sedang berlaku.
///
/// Cuma satu method, dan cuma membaca. Mengubahnya adalah pekerjaan dashboard
/// admin di web (rencana capstone bagian 14.3), bukan aplikasi ini; kontrak
/// ini tidak punya `perbarui` dengan sengaja, sama seperti [AuthRepository]
/// tidak punya cara mengubah peran sendiri.
abstract class TarifRepository {
  Future<Tarif> ambilTarif();
}
