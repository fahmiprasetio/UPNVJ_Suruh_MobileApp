import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/core/api/galat_api.dart';
import 'package:upnvj_suruh/data/api/pemeta_pendapatan.dart';
import 'package:upnvj_suruh/domain/enums.dart';

/// Bentuk jawaban `PendapatanResponse` dari server, dibaca ulang di sini.
///
/// Yang paling penting dijaga: `jumlah: null` harus tetap null, bukan jadi nol.
/// Nol berarti "order ini memang tidak dibayar", null berarti "belum bisa
/// dihitung karena admin belum menetapkan bagi hasilnya", dan layar pendapatan
/// menuliskan keduanya dengan kalimat yang berbeda. Kalau pemeta ini
/// menyamakannya, layar itu ikut berbohong tanpa satu baris pun di sana yang
/// terlihat salah.
void main() {
  Map<String, dynamic> baris({dynamic jumlah = 12000, dynamic dibayarPada}) => {
    'penugasanId': 'tugas-1',
    'orderId': 'order-1',
    'kodeOrder': 'SRH-0412',
    'layanan': 'AnterJemput',
    'selesaiPada': '2026-09-03T10:00:00Z',
    'jumlah': jumlah,
    'dibayarPada': dibayarPada,
  };

  Map<String, dynamic> jawaban({
    List<Map<String, dynamic>>? isi,
    int menungguRumus = 0,
    num belum = 12000,
    num sudah = 0,
  }) => {
    'totalBelumDibayar': belum,
    'totalSudahDibayar': sudah,
    'menungguRumus': menungguRumus,
    'rincian': {
      'isi': isi ?? [baris()],
      'total': (isi ?? [baris()]).length,
      'halaman': 1,
      'ukuranHalaman': 20,
      'totalHalaman': 1,
    },
  };

  test('membaca kedua total beserta rinciannya', () {
    final hasil = PemetaPendapatan.pendapatan(jawaban(belum: 12000, sudah: 40000));

    expect(hasil.totalBelumDibayar, 12000);
    expect(hasil.totalSudahDibayar, 40000);
    expect(hasil.rincian.isi, hasLength(1));
    expect(hasil.rincian.isi.first.kodeOrder, 'SRH-0412');
    expect(hasil.rincian.isi.first.layanan, ServiceType.anterJemput);
  });

  test('bayaran yang belum dihitung tetap null, bukan nol', () {
    final hasil = PemetaPendapatan.pendapatan(
      jawaban(isi: [baris(jumlah: null)], menungguRumus: 1),
    );

    final satu = hasil.rincian.isi.first;
    expect(satu.jumlah, isNull);
    expect(satu.menungguRumus, isTrue);
    expect(hasil.menungguRumus, 1);
  });

  test('bayaran yang sudah diserahkan membawa tanggalnya', () {
    final hasil = PemetaPendapatan.pendapatan(
      jawaban(isi: [baris(dibayarPada: '2026-09-04T03:00:00Z')]),
    );

    final satu = hasil.rincian.isi.first;
    expect(satu.sudahDibayar, isTrue);
    expect(satu.dibayarPada, isNotNull);
  });

  test('yang belum diserahkan tidak punya tanggal bayar', () {
    final hasil = PemetaPendapatan.pendapatan(jawaban());

    expect(hasil.rincian.isi.first.sudahDibayar, isFalse);
  });

  /// Jawaban yang bentuknya berubah harus melempar, bukan jadi daftar kosong.
  /// Pendapatan yang diam-diam kosong terbaca sebagai "belum pernah kerja", dan
  /// itu jenis kegagalan yang tidak pernah dilaporkan siapa pun.
  test('jawaban tanpa rincian melempar, bukan jadi kosong', () {
    expect(
      () => PemetaPendapatan.pendapatan({
        'totalBelumDibayar': 0,
        'totalSudahDibayar': 0,
        'menungguRumus': 0,
      }),
      throwsA(isA<GalatServer>()),
    );
  });

  test('layanan yang tidak dikenal melempar', () {
    final rusak = jawaban();
    (rusak['rincian'] as Map<String, dynamic>)['isi'] = [
      {...baris(), 'layanan': 'LayananKarangan'},
    ];

    expect(
      () => PemetaPendapatan.pendapatan(rusak),
      throwsA(isA<GalatServer>()),
    );
  });
}
