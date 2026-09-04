import '../../domain/enums.dart';
import '../../domain/models/halaman.dart';
import '../../domain/models/pendapatan.dart';
import '../../domain/repositories/pendapatan_repository.dart';

/// Tiruan pendapatan, buat tes dan demo tanpa server.
///
/// Isinya bisa ditentukan pemanggil, tidak seperti [FakeTarifRepository] yang
/// selalu menjawab satu nilai tetap. Yang perlu dicoba di layar pendapatan bukan
/// satu keadaan melainkan empat, dan tiga di antaranya justru yang paling mudah
/// terlewat: belum pernah menyelesaikan order sama sekali, sudah menyelesaikan
/// tapi bayarannya masih menunggu rumus bagi hasil dari admin, dan sebagian
/// sudah dibayar sementara sebagian belum.
class FakePendapatanRepository implements PendapatanRepository {
  FakePendapatanRepository({Pendapatan? isi}) : _isi = isi ?? contoh();

  static const Duration _jedaJaringan = Duration(milliseconds: 350);

  final Pendapatan _isi;

  @override
  Future<Pendapatan> ambilPendapatan({int halaman = 1, int ukuran = 20}) async {
    await Future<void>.delayed(_jedaJaringan);
    return _isi;
  }

  /// Pendapatan yang isinya campur: satu belum dibayar, satu sudah.
  static Pendapatan contoh() {
    final baris = [
      BarisPendapatan(
        penugasanId: 'tugas-1',
        orderId: 'order-1',
        kodeOrder: 'SRH-0412',
        layanan: ServiceType.anterJemput,
        selesaiPada: DateTime.now().subtract(const Duration(days: 1)),
        jumlah: 12000,
        dibayarPada: null,
      ),
      BarisPendapatan(
        penugasanId: 'tugas-2',
        orderId: 'order-2',
        kodeOrder: 'SRH-0410',
        layanan: ServiceType.bersihKos,
        selesaiPada: DateTime.now().subtract(const Duration(days: 6)),
        jumlah: 40000,
        dibayarPada: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];

    return Pendapatan(
      totalBelumDibayar: 12000,
      totalSudahDibayar: 40000,
      menungguRumus: 0,
      rincian: Halaman(isi: baris, total: baris.length),
    );
  }

  /// Belum ada satu pun order yang diselesaikan.
  static const kosong = Pendapatan(
    totalBelumDibayar: 0,
    totalSudahDibayar: 0,
    menungguRumus: 0,
    rincian: Halaman(isi: [], total: 0),
  );
}
