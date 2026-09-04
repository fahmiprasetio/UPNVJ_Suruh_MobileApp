import '../../core/api/klien_api.dart';
import '../../domain/models/pendapatan.dart';
import '../../domain/repositories/pendapatan_repository.dart';
import 'pemeta_pendapatan.dart';

/// Pendapatan runner lewat API .NET.
///
/// Tidak diambil ulang berkala seperti daftar order. Yang mengubah angka di
/// layar ini cuma dua kejadian, dan keduanya jarang: runner menutup satu order
/// (yang berarti ia sedang berada di layar lain), dan admin menandai bayaran
/// sudah diserahkan (yang terjadi sekali seminggu, bukan sepanjang hari).
/// Menyegarkannya tiap lima belas detik berarti menghabiskan kuota runner untuk
/// jawaban yang nyaris selalu sama persis.
class ApiPendapatanRepository implements PendapatanRepository {
  ApiPendapatanRepository({required KlienApi klien}) : _klien = klien;

  final KlienApi _klien;

  @override
  Future<Pendapatan> ambilPendapatan({int halaman = 1, int ukuran = 20}) async {
    final jawaban = await _klien.get(
      '/api/runner/pendapatan',
      kueri: {'halaman': '$halaman', 'ukuran': '$ukuran'},
    );
    return PemetaPendapatan.pendapatan(jawaban);
  }
}
