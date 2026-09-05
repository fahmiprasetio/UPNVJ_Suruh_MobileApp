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
/// ## Satu hal yang sengaja tidak ada di sini
///
/// **Menandai order lunas.** Uang yang masuk adalah kejadian di luar aplikasi, jadi
/// yang boleh mengabarkannya adalah pihak yang menerima uangnya, bukan pihak yang
/// mengirimkannya. Di server itu webhook gateway, dan aplikasi tidak punya jalan ke
/// sana. Selama gateway sungguhan belum terpasang, tiruannya menyediakan tombol
/// simulasi yang hanya hidup di build debug.
///
/// ## Membuat penawaran memang bagian dari kontrak ini sekarang
///
/// Jalur B pindah dari "admin mengirim satu penawaran lewat dashboard" jadi
/// tawar-menawar ala aplikasi ojek daring: klien mengusulkan harga, dan setiap
/// runner yang tersedia boleh langsung menyanggupinya atau menawar balik lewat
/// [buatPenawaran]. Ini pekerjaan runner sungguhan, bukan alat penguji, jadi
/// harus ada di kontrak ini, bukan menyelinap lewat implementasi tiruan.
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

  /// Jalur B: harga sudah ada, order lahir sebagai permintaan dengan
  /// [hargaUsulan] sebagai titik awal tawar-menawar, lalu disiarkan ke seluruh
  /// runner yang tersedia.
  Future<Order> buatPermintaanJalurB({
    required ServiceType serviceType,
    required String deskripsi,
    required DateTime jadwalMulai,
    required int hargaUsulan,
    String? alamatTujuan,
    int jumlahRunnerDibutuhkan = 1,
  });

  /// Seorang runner mengajukan penawaran untuk satu permintaan Jalur B.
  ///
  /// Runner boleh mengirim harga persis sama dengan harga usulan klien kalau
  /// setuju apa adanya, atau angka lain kalau mau menawar balik. Beberapa
  /// runner boleh punya penawaran yang sama-sama menunggu jawaban pada order
  /// yang sama; klien yang memilih satu di antaranya lewat [setujuiPenawaran].
  Future<Order> buatPenawaran({
    required String orderId,
    required int harga,
    required Duration estimasiDurasi,
    required DateTime jadwalMulai,
    String? catatan,
  });

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

  /// Klien menyetujui satu penawaran tertentu.
  ///
  /// Di sinilah harga, estimasi durasi, dan jadwal penawaran itu pindah menjadi
  /// milik ordernya, lalu order lanjut ke menunggu pembayaran. Seluruh
  /// penawaran lain yang masih menunggu pada order yang sama otomatis
  /// [OfferStatus.ditutup].
  Future<Order> setujuiPenawaran({
    required String orderId,
    required String penawaranId,
  });

  /// Klien menolak satu penawaran tertentu.
  ///
  /// Menolak satu penawaran tidak mengakhiri ordernya, dan tidak menyentuh
  /// penawaran runner lain yang masih menunggu pada order yang sama. Klien
  /// yang mau membatalkan permintaannya sama sekali memakai [batalkanOrder].
  Future<Order> tolakPenawaran({
    required String orderId,
    required String penawaranId,
  });

  /// Klien meminta satu penawaran tertentu ditinjau ulang, disertai alasannya.
  ///
  /// [alasan] ditulis sebagai pesan di jalur obrolan pribadi klien dengan
  /// runner pengaju penawaran itu, karena tempat menjawabnya memang chat.
  /// Runner itu bebas mengirim penawaran baru sesudahnya.
  Future<Order> ajukanNego({
    required String orderId,
    required String penawaranId,
    required String alasan,
  });

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

  /// Runner melepas order yang sudah dipegangnya, dan order itu kembali dicari
  /// runner lain.
  ///
  /// Bukan pembatalan: uang klien tetap di tempatnya, ordernya cuma kembali
  /// disiarkan. Itu jalan keluar yang jauh lebih murah daripada dua yang tersedia
  /// sebelumnya, yaitu runner memaksa menandai selesai, atau admin membatalkan
  /// seluruhnya berikut pengembalian dana padahal yang dibutuhkan cuma runner lain.
  ///
  /// [alasan] wajib, dan tersimpan sebagai pesan dari runner ini di chat ordernya.
  /// Klien yang melihat ordernya mundur sendiri tanpa satu kalimat pun akan
  /// menyimpulkan sistemnya rusak.
  Future<Order> lepasOrder({required String orderId, required String alasan});

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
  ///
  /// [runnerId] cuma dipakai klien, dan cuma berarti selama order Jalur B
  /// masih menerima penawaran: menyebutkan runner mana yang sedang diajak
  /// bicara, karena tiap runner punya jalur obrolannya sendiri dengan klien.
  /// Runner sendiri tidak perlu mengisi ini; jalur obrolannya ditentukan dari
  /// hubungannya sendiri dengan order, bukan dari apa yang ia sebutkan.
  Future<Order> kirimPesan({
    required String orderId,
    required String isi,
    String? runnerId,
  });
}
