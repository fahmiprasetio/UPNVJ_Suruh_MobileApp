import '../enums.dart';
import '../models/order.dart';

/// Kontrak akses data order.
///
/// Seluruh UI bicara ke antarmuka ini, tidak pernah langsung ke server. Selama
/// pilihan stack backend belum dikunci (rencana capstone bagian 14.4),
/// implementasinya adalah data palsu di memori. Ketika stack dipilih, cukup
/// tulis satu implementasi baru, `ApiOrderRepository` untuk .NET atau
/// `SupabaseOrderRepository`, dan tukar di provider. Tidak ada layar yang
/// perlu diubah.
abstract interface class OrderRepository {
  /// Order milik satu klien, terbaru di atas.
  Stream<List<Order>> watchOrderKlien(String klienId);

  /// Order yang sedang disiarkan dan masih punya sisa kuota runner, dilihat
  /// dari sudut pandang satu runner.
  ///
  /// [runnerId] wajib karena siaran bukan daftar yang sama untuk semua orang.
  /// Order yang sudah dipegang runner ini, dan order yang ia pesan sendiri,
  /// tidak pernah ikut disiarkan kepadanya. Penyaringan itu tempatnya di sini,
  /// bukan di layar: daftar yang dipangkas tampilan tetap terkirim utuh ke
  /// perangkatnya, dan yang bocor lewat siaran adalah nama serta alamat orang.
  Stream<List<Order>> watchOrderTersiar(String runnerId);

  /// Order yang sedang dipegang satu runner.
  Stream<List<Order>> watchOrderRunner(String runnerId);

  Stream<Order?> watchOrder(String orderId);

  Future<Order?> getOrder(String orderId);

  /// Jalur A: harga sudah diketahui saat order dibuat, jadi order langsung
  /// masuk status [OrderStatus.menungguPembayaran].
  Future<Order> buatOrderJalurA({
    required String klienId,
    required ServiceType serviceType,
    required int harga,
    String? deskripsi,
    String? alamatJemput,
    String? alamatTujuan,
  });

  /// Jalur B: harga belum ada. Order lahir sebagai [OrderStatus.permintaan]
  /// dan menunggu admin membuat penawaran.
  Future<Order> buatPermintaanJalurB({
    required String klienId,
    required ServiceType serviceType,
    required String deskripsi,
    required DateTime jadwalMulai,
    String? alamatTujuan,
    int jumlahRunnerDibutuhkan = 1,
  });

  /// Admin mengirim penawaran harga untuk satu permintaan Jalur B.
  ///
  /// Hanya Jalur B yang punya penawaran. Harga Jalur A dihitung dari isian
  /// form sejak awal, jadi tidak ada yang perlu ditawarkan di sana, dan
  /// mengizinkannya berarti membuka jalan mengubah harga yang sudah tertulis
  /// di layar klien.
  ///
  /// Penawaran yang baru dibuat tidak mengisi harga ordernya. Harga baru
  /// pindah ke order ketika klien menyetujuinya, karena sebelum itu angka
  /// tersebut cuma usulan, dan order yang memajang harga yang belum disepakati
  /// akan terbaca sebagai tagihan.
  Future<Order> buatPenawaran({
    required String orderId,
    required int harga,
    required Duration estimasiDurasi,
    required DateTime jadwalMulai,
    String? catatan,
  });

  /// Klien menyetujui penawaran yang sedang menunggu.
  ///
  /// Di sinilah harga, estimasi durasi, dan jadwal penawaran pindah menjadi
  /// milik ordernya, lalu order lanjut ke [OrderStatus.menungguPembayaran].
  Future<Order> setujuiPenawaran(String orderId);

  /// Klien menolak penawaran.
  ///
  /// Penolakan mengakhiri ordernya, bukan mengembalikannya ke antrean admin.
  /// Klien yang masih berminat dengan harga lain memakai [ajukanNego]; yang
  /// menekan tolak memang sudah tidak berminat.
  Future<Order> tolakPenawaran(String orderId);

  /// Klien meminta penawaran ditinjau ulang, disertai alasannya.
  ///
  /// Ordernya kembali ke [OrderStatus.permintaan] supaya masuk lagi ke antrean
  /// admin, dan [alasan] ditulis sebagai pesan di chat ordernya. Alasan itu
  /// tidak disimpan di dalam penawaran karena tempat menjawabnya memang chat:
  /// admin membaca, bertanya kalau perlu, lalu mengirim penawaran baru.
  Future<Order> ajukanNego({required String orderId, required String alasan});

  /// Menandai pembayaran berhasil dan menyiarkan order ke runner.
  Future<Order> tandaiSudahDibayar(String orderId);

  /// Runner menekan TERIMA.
  ///
  /// Mengembalikan `true` kalau runner ini berhasil mendapat slot, `false`
  /// kalau kuota sudah keburu penuh diambil runner lain. Inti teknis proyek,
  /// implementasi sesungguhnya harus atomik di level basis data, bukan cuma di
  /// tampilan (bagian 14.5).
  ///
  /// Kalah cepat mengembalikan `false` karena itu hasil yang wajar, bukan
  /// kesalahan. Melanggar aturan melempar galat, dan satu-satunya aturan di
  /// sini: pemesan tidak boleh menjadi runner ordernya sendiri. Akun yang
  /// memegang peran klien sekaligus runner (bagian 14.3) membuat itu mungkin
  /// secara teknis, dan membiarkannya berarti membuka jalan memesan lalu
  /// menerima sendiri, menagih upah atas pekerjaan yang tidak pernah berpindah
  /// tangan.
  Future<bool> terimaOrder({required String orderId, required String runnerId});

  /// Runner menandai pekerjaannya selesai.
  ///
  /// [runnerId] wajib karena yang berhak menutup order hanya runner yang
  /// memegangnya. Pemeriksaan itu tempatnya di sini, bukan di layar: tombol
  /// yang disembunyikan tidak menghentikan siapa pun yang memanggil langsung.
  ///
  /// Foto bukti wajib ada, itu yang membedakan pekerjaan selesai dari
  /// pengakuan selesai.
  Future<Order> selesaikanOrder({
    required String orderId,
    required String runnerId,
    required String fotoBuktiUrl,
    String? catatanSerahTerima,
  });

  Future<Order> batalkanOrder(String orderId);

  /// Mengirim satu pesan ke ruang chat sebuah order.
  ///
  /// Tidak ada chat yang berdiri sendiri: setiap pesan wajib menempel pada
  /// satu order (bagian 4, "Prinsip inti"). Karena itu kontraknya menuntut
  /// [orderId], bukan lawan bicara. Tanpa aturan ini, ruang chat pelan-pelan
  /// berubah jadi WhatsApp versi lebih jelek, persis masalah yang mau
  /// ditinggalkan mitra.
  ///
  /// [pengirim] menentukan peran penulisnya, bukan identitas orangnya, karena
  /// satu order bisa dibaca beberapa runner sekaligus.
  Future<Order> kirimPesan({
    required String orderId,
    required MessageSender pengirim,
    required String isi,
  });
}
