import '../enums.dart';
import '../../core/config/batas_halaman.dart';
import '../models/halaman.dart';
import '../models/order.dart';

/// Kontrak akses data order.
///
/// Bentuknya mengikuti API .NET yang sudah ada, dan perbedaan terbesarnya dari
/// versi sebelumnya adalah apa yang **tidak** lagi diterima sebagai parameter.
///
/// ## Identitas pemanggil tidak pernah jadi parameter
///
/// Dulu method di sini menerima `klienId` atau `runnerId`. Itu bekerja selama
/// pemanggilnya kode di proses yang sama, dan berhenti bekerja begitu jadi
/// permintaan HTTP: apa pun yang dikirim klien bisa diganti klien, jadi otorisasi
/// yang bersandar padanya tidak menjaga apa-apa. Cukup kirim id orang lain.
///
/// Sekarang siapa pemanggilnya datang dari sesinya, dan kontraknya sengaja tidak
/// punya tempat untuk menyebutkannya. Aturan yang tidak bisa diucapkan tidak bisa
/// dilanggar.
///
/// ## Dua hal yang sengaja tidak ada di sini
///
/// **Menandai order lunas.** Uang yang masuk adalah kejadian di luar aplikasi, jadi
/// yang boleh mengabarkannya adalah pihak yang menerima uangnya, bukan pihak yang
/// mengirimkannya. Di server itu webhook gateway, dan aplikasi tidak punya jalan ke
/// sana. Selama gateway sungguhan belum terpasang, tiruannya menyediakan tombol
/// simulasi yang hanya hidup di build debug.
///
/// **Membuat penawaran.** Itu pekerjaan admin, dan admin bekerja lewat dashboard
/// web (rencana capstone bagian 14.2). Aplikasi ini tidak punya permukaan admin,
/// jadi tidak punya alasan bisa menawar. Panel alat penguji yang berdiri di tempat
/// dashboard itu memanggil tiruannya langsung, bukan lewat kontrak ini.
///
/// Keduanya bukan kelupaan. Menambahkannya kembali ke sini, walau cuma "supaya
/// gampang dites", membuka lagi persis lubang yang ditutup.
abstract interface class OrderRepository {
  /// Order milik klien yang sedang masuk, terbaru di atas.
  Stream<Halaman<Order>> watchOrderKlien({required int ukuran});

  /// Order yang sedang disiarkan, dilihat dari sudut pandang runner yang masuk.
  ///
  /// Order yang ia pesan sendiri dan yang sudah ia pegang tidak pernah ikut. Yang
  /// menyaring adalah sisi data, bukan tampilan: daftar yang cuma dipangkas layar
  /// tetap terkirim utuh ke perangkatnya, dan isinya nama serta alamat orang.
  Stream<Halaman<Order>> watchOrderTersiar({required int ukuran});

  /// Order yang sedang dan pernah dipegang runner yang masuk.
  Stream<Halaman<Order>> watchOrderRunner({required int ukuran});

  /// Satu order, atau `null` kalau tidak ada.
  ///
  /// "Tidak ada" dan "ada tapi bukan urusanmu" sengaja tidak dibedakan, mengikuti
  /// server yang menjawab keduanya sama. Membedakannya di sini akan membocorkan
  /// lagi apa yang sudah ditutup di sana.
  Stream<Order?> watchOrder(
    String orderId, {
    int ukuranPesan = BatasHalaman.bawaan,
  });

  /// [ukuranPesan] membatasi percakapan yang ikut terbawa, terbaru yang
  /// dipertahankan. Punya nilai bawaan yang berbatas, bukan wajib disebut:
  /// pemanggil yang cuma butuh ordernya, misalnya untuk membaca harganya, tidak
  /// perlu memikirkan percakapan sama sekali, dan yang lupa menyebutnya tetap
  /// tidak menarik seluruh isi chat.
  Future<Order?> getOrder(String orderId, {int ukuranPesan = BatasHalaman.bawaan});

  /// Jalur A: harga dihitung server dari jenis layanan dan jarak.
  ///
  /// [jarakKm] adalah perkiraan yang diisi klien, konsekuensi dari memakai alamat
  /// teks bebas alih-alih pin peta (bagian 14.8). Yang dikirim jarak, bukan harga:
  /// endpoint yang menerima harga jadi membuat siapa pun bisa memesan seharga satu
  /// rupiah, dan itu tidak ketahuan sampai uangnya dihitung. Aplikasi tetap punya
  /// kalkulator sendiri supaya klien melihat rinciannya sebelum memesan, tapi angka
  /// yang mengikat adalah hitungan server.
  Future<Order> buatOrderJalurA({
    required ServiceType serviceType,
    double? jarakKm,
    String? deskripsi,
    String? alamatJemput,
    String? alamatTujuan,
  });

  /// Jalur B: harga belum ada, order lahir sebagai permintaan dan menunggu
  /// penawaran admin.
  Future<Order> buatPermintaanJalurB({
    required ServiceType serviceType,
    required String deskripsi,
    required DateTime jadwalMulai,
    String? alamatTujuan,
    int jumlahRunnerDibutuhkan = 1,
  });

  /// Klien menyetujui penawaran yang sedang menunggu.
  ///
  /// Di sinilah harga, estimasi durasi, dan jadwal penawaran pindah menjadi milik
  /// ordernya, lalu order lanjut ke menunggu pembayaran.
  Future<Order> setujuiPenawaran(String orderId);

  /// Klien menolak penawaran.
  ///
  /// Penolakan mengakhiri ordernya, bukan mengembalikannya ke antrean admin. Klien
  /// yang masih berminat dengan harga lain memakai [ajukanNego]; yang menekan tolak
  /// memang sudah tidak berminat.
  Future<Order> tolakPenawaran(String orderId);

  /// Klien meminta penawaran ditinjau ulang, disertai alasannya.
  ///
  /// Ordernya kembali ke antrean admin, dan [alasan] ditulis sebagai pesan di chat
  /// ordernya, karena tempat menjawabnya memang chat.
  Future<Order> ajukanNego({required String orderId, required String alasan});

  /// Runner menekan TERIMA.
  ///
  /// Mengembalikan `true` kalau ia berhasil mendapat slot, `false` kalau kuotanya
  /// keburu penuh diambil runner lain. Kalah cepat bukan galat, jadi bukan lemparan.
  ///
  /// Melanggar aturan tetap melempar, dan satu-satunya aturan di sini: pemesan tidak
  /// boleh menjadi runner ordernya sendiri.
  Future<bool> terimaOrder({required String orderId});

  /// Runner menandai pekerjaannya selesai.
  ///
  /// Yang berhak menutup order hanya runner yang memegangnya, dan foto bukti wajib
  /// ada. Itu yang membedakan pekerjaan selesai dari pengakuan selesai.
  Future<Order> selesaikanOrder({
    required String orderId,
    required String fotoBuktiUrl,
    String? catatanSerahTerima,
  });

  /// Membatalkan order.
  ///
  /// Hanya pemesannya, dan hanya selama belum dibayar. Pembatalan setelah pembayaran
  /// menyangkut pengembalian uang, dan itu tidak boleh terjadi sebagai efek samping
  /// satu tombol.
  Future<Order> batalkanOrder(String orderId);

  /// Mengirim satu pesan ke ruang chat sebuah order.
  ///
  /// Tidak ada chat yang berdiri sendiri: setiap pesan menempel pada satu order.
  /// Tanpa aturan itu, ruang chatnya pelan-pelan berubah jadi WhatsApp versi lebih
  /// jelek, persis masalah yang mau ditinggalkan mitra.
  ///
  /// Peran penulisnya tidak disebutkan di sini. Dulu iya, dan akibatnya rute yang
  /// dibuka menentukan atas nama siapa pesan itu tertulis. Sekarang perannya
  /// diturunkan dari hubungan pengirim dengan ordernya.
  Future<Order> kirimPesan({required String orderId, required String isi});
}
