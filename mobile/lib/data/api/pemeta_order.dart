import '../../domain/enums.dart';
import '../../domain/models/order.dart';
import '../../domain/models/order_message.dart';
import '../../domain/models/order_offer.dart';
import '../../core/api/konfigurasi_api.dart';
import 'pemeta_dasar.dart';

/// Menerjemahkan jawaban API jadi model domain.
///
/// Dipisahkan dari repositorynya supaya bisa diuji sendiri terhadap contoh jawaban
/// yang benar-benar diambil dari server, bukan yang dikarang. Bentuk JSON adalah
/// hal yang paling gampang salah diasumsikan dan paling sunyi kalau salah: field
/// yang keliru namanya cuma jadi `null`, dan layar menampilkan kolom kosong tanpa
/// ada yang tampak rusak.
class PemetaOrder {
  const PemetaOrder._();

  static Order order(Map<String, dynamic> isi, {List<OrderMessage>? pesan}) {
    return Order(
      id: _teks(isi, 'id'),
      kodeOrder: _teks(isi, 'kodeOrder'),
      klienId: _teks(isi, 'klienId'),
      namaKlien: _teks(isi, 'namaKlien'),
      serviceType: _enum(ServiceType.values, isi['serviceType'], 'serviceType'),
      status: _enum(OrderStatus.values, isi['status'], 'status'),
      dibuatPada: _waktu(isi, 'dibuatPada')!,
      deskripsi: isi['deskripsi'] as String?,
      alamatJemput: isi['alamatJemput'] as String?,
      alamatTujuan: isi['alamatTujuan'] as String?,
      harga: _rupiah(isi['harga']),
      estimasiDurasi: _menit(isi['estimasiDurasiMenit']),
      jadwalMulai: _waktu(isi, 'jadwalMulai'),
      jumlahRunnerDibutuhkan: (isi['jumlahRunnerDibutuhkan'] as num?)?.toInt() ?? 1,
      runnerIds: [
        for (final id in (isi['runnerIds'] as List? ?? const [])) id.toString(),
      ],
      // Dilengkapi di sini, satu tempat, bukan di tiap layar yang menggambarnya.
      // Layar yang harus merangkai alamatnya sendiri adalah layar yang bisa lupa.
      fotoBuktiUrl: _alamatFoto(isi['fotoBuktiUrl']),
      catatanSerahTerima: isi['catatanSerahTerima'] as String?,
      dibayarPada: _waktu(isi, 'dibayarPada'),
      selesaiPada: _waktu(isi, 'selesaiPada'),
      offers: [
        for (final p in (isi['penawaran'] as List? ?? const []))
          penawaran(p as Map<String, dynamic>),
      ],
      // Daftar order tidak membawa isi percakapannya, jadi pesannya hanya terisi
      // kalau pemanggil memang sudah mengambilnya. Jumlahnya tetap benar karena
      // datang terpisah dari server.
      messages: pesan ?? const [],
      jumlahPesan: (isi['jumlahPesan'] as num?)?.toInt() ?? 0,
    );
  }

  static OrderOffer penawaran(Map<String, dynamic> isi) => OrderOffer(
    id: _teks(isi, 'id'),
    orderId: _teks(isi, 'orderId'),
    harga: _rupiah(isi['harga']) ?? 0,
    estimasiDurasi: _menit(isi['estimasiDurasiMenit']) ?? Duration.zero,
    jadwalMulai: _waktu(isi, 'jadwalMulai')!,
    dibuatPada: _waktu(isi, 'dibuatPada')!,
    status: _enum(OfferStatus.values, isi['status'], 'status penawaran'),
    catatan: isi['catatan'] as String?,
  );

  static OrderMessage pesanChat(Map<String, dynamic> isi) => OrderMessage(
    id: _teks(isi, 'id'),
    orderId: _teks(isi, 'orderId'),
    pengirim: _enum(MessageSender.values, isi['peranPengirim'], 'peran pengirim'),
    isi: (isi['isi'] as String?) ?? '',
    dikirimPada: _waktu(isi, 'dikirimPada')!,
  );

  // Pembacaan dasarnya ada di PemetaDasar, dipakai bersama pemeta transaksi
  // pembayaran. Yang tinggal di sini cuma yang khas order.

  static String _teks(Map<String, dynamic> isi, String kunci) =>
      PemetaDasar.teks(isi, kunci);

  static int? _rupiah(dynamic nilai) => PemetaDasar.rupiah(nilai);

  static String? _alamatFoto(dynamic nilai) =>
      nilai is String && nilai.isNotEmpty
      ? KonfigurasiApi.lengkapi(nilai)
      : null;

  static DateTime? _waktu(Map<String, dynamic> isi, String kunci) =>
      PemetaDasar.waktu(isi, kunci);

  static T _enum<T extends Enum>(
    List<T> pilihan,
    dynamic nilai,
    String namaKolom,
  ) => PemetaDasar.pilihan(pilihan, nilai, namaKolom);

  static Duration? _menit(dynamic nilai) =>
      nilai == null ? null : Duration(minutes: (nilai as num).toInt());
}
