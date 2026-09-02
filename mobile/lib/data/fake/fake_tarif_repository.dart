import '../../domain/models/tarif.dart';
import '../../domain/repositories/tarif_repository.dart';

/// Tiruan tarif, buat tes dan demo tanpa server.
///
/// Selalu menjawab [Tarif.bawaan]. Tidak ada jalan mengubahnya lewat tiruan
/// ini karena aplikasi memang tidak punya layar untuk itu; mengubah tarif
/// hanya bisa dilakukan admin lewat dashboard web.
class FakeTarifRepository implements TarifRepository {
  @override
  Future<Tarif> ambilTarif() async => Tarif.bawaan;
}
