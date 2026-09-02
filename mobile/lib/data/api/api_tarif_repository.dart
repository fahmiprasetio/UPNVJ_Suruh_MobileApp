import '../../core/api/klien_api.dart';
import '../../domain/models/tarif.dart';
import '../../domain/repositories/tarif_repository.dart';
import 'pemeta_tarif.dart';

/// Tarif Jalur A lewat API .NET.
///
/// `GET /api/tarif` cuma dipanggil sekali per hidup aplikasi lewat
/// [tarifProvider], bukan diambil ulang berkala seperti daftar order.
/// Tarifnya jarang berubah, dan form isian harga menghitung ulang setiap
/// ketikan (lihat `FormAnterJemputScreen`); mengambilnya lewat jaringan pada
/// setiap ketikan itu akan membuat pratinjau harga tersendat menunggu
/// jawaban server, padahal angkanya nyaris tidak pernah berubah pada saat
/// yang sama dengan klien sedang mengisi form.
class ApiTarifRepository implements TarifRepository {
  ApiTarifRepository({required KlienApi klien}) : _klien = klien;

  final KlienApi _klien;

  @override
  Future<Tarif> ambilTarif() async {
    final jawaban = await _klien.get('/api/tarif');
    return PemetaTarif.tarif(jawaban);
  }
}
