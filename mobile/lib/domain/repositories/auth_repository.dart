import '../models/app_user.dart';

/// Kontrak autentikasi.
///
/// Masuk memakai nomor HP dan kode sekali pakai yang dikirim ke nomor itu. Bentuk
/// ini menyusul API .NET yang sudah menerapkannya, dan menggantikan kontrak lama
/// yang menerima nomor HP saja tanpa bukti apa pun.
///
/// ## Aturan pemberian peran
///
/// Satu aturan yang tidak boleh dilanggar implementasi mana pun:
///
/// **Pendaftaran mandiri selalu menghasilkan `{UserRole.klien}` saja. Peran runner
/// dan admin hanya boleh diberikan admin lewat dashboard web, tidak pernah lewat
/// aplikasi ini, dan tidak pernah atas permintaan sendiri.**
///
/// Alasannya bukan kerapian, melainkan siapa runner itu: runner adalah pegawai
/// mitra yang dipercaya masuk ke kos orang dan memegang uang belanja, bukan peran
/// yang bisa diambil siapa saja yang mengunduh aplikasi. Klien adalah mahasiswa atau
/// pelanggan. Kalau pendaftaran bisa menentukan perannya sendiri, seluruh pemeriksaan
/// peran di aplikasi ini kehilangan artinya, karena penyerang tinggal meminta peran
/// yang ia mau di langkah pertama.
///
/// Kontrak ini menegakkannya lewat bentuk, bukan lewat imbauan:
///
///   - [daftar] tidak punya parameter peran, jadi pemanggil tidak punya cara
///     menyebutkan peran yang ia inginkan.
///   - Tidak ada satu pun method di sini yang mengubah [AppUser.roles]. Bukan
///     kelupaan, memang tidak boleh ada. Pemberian peran adalah pekerjaan dashboard
///     admin (bagian 14.2), bukan pekerjaan aplikasi mobile.
///
/// Aturan yang sama sudah berlaku di API: DTO pendaftarannya tidak punya field
/// `roles` sama sekali, dan ada tes yang mengirimkannya untuk membuktikan diabaikan.
abstract interface class AuthRepository {
  Stream<AppUser?> watchUserAktif();

  AppUser? get userAktif;

  /// Mendaftarkan akun baru. Selalu lahir sebagai klien, lihat aturan di atas.
  ///
  /// Tidak sekalian memasukkan penggunanya, karena masih ada verifikasi di antara
  /// keduanya. Yang memutuskan seseorang sudah masuk tetap [masuk].
  ///
  /// TIDAK MENGEMBALIKAN APA-APA, dan itu bukan penyederhanaan. Berakhir sama saja
  /// untuk nomor yang terdaftar maupun tidak, sama seperti [mintaKode]: hasil yang
  /// berbeda mengubah langkah ini jadi alat memeriksa siapa saja yang punya akun,
  /// cukup dengan mencoba nomor satu per satu. Jawaban yang harus sama untuk kedua
  /// keadaan karena itu tidak boleh memuat apa pun tentang akunnya, dan sudah pasti
  /// tidak boleh memuat data akun yang sudah ada: nama pemiliknya adalah hal
  /// terakhir yang boleh diserahkan kepada orang yang cuma menebak nomor.
  ///
  /// Akibatnya layar tidak boleh menyimpulkan apa pun dari sini, termasuk bahwa
  /// pendaftarannya berhasil. Yang nomornya ternyata sudah terdaftar tidak dibuatkan
  /// akun kedua dan tidak diubah apa-apa; ia menerima kode ke nomor itu juga, lalu
  /// masuk ke akun yang memang miliknya.
  Future<void> daftar({
    required String nama,
    required String noHp,
    required String password,
  });

  /// Meminta kode sekali pakai dikirim ke nomor tersebut.
  ///
  /// Berakhir sama saja untuk nomor yang terdaftar maupun tidak, dan itu bukan
  /// kelalaian: hasil yang berbeda mengubah langkah ini jadi alat memeriksa siapa
  /// saja yang punya akun, cukup dengan mencoba nomor satu per satu. Karena itu
  /// layar tidak boleh menyimpulkan apa pun tentang keberadaan akun dari sini.
  Future<void> mintaKode({required String noHp});

  /// Menukar kode yang benar dengan sesi.
  ///
  /// Kodenya sekali pakai dan berbatas waktu. Nomor yang tidak terdaftar dan kode
  /// yang salah gagal dengan cara yang sama persis, supaya tebakan yang meleset
  /// tidak memberi tahu bahwa setengah jawabannya sudah benar.
  Future<AppUser> masuk({
    required String noHp,
    required String kode,
    required String tantangan,
  });

  /// Memverifikasi password dan mengirim OTP untuk langkah kedua [masuk].
  ///
  /// Jawabannya adalah tantangan sekali pakai yang harus dikirim bersama OTP ke
  /// [masuk]. Tidak ada sesi yang diterbitkan pada langkah ini. Untuk akun lama
  /// tanpa password, nilai yang dimasukkan baru disimpan setelah OTP terbukti.
  Future<String> masukPassword({
    required String noHp,
    required String password,
  });

  /// Mengatur atau mengganti password sendiri, dibuktikan lewat kode OTP ke
  /// nomor akun yang sedang masuk -- diminta lewat [mintaKode] yang sama,
  /// bukan endpoint terpisah.
  ///
  /// Menuntut kode, bukan cuma sesi yang sedang berjalan: sesi yang dicuri
  /// sesaat berlaku cuma sampai kedaluwarsa, sedangkan password yang diatur
  /// lewatnya bertahan jauh lebih lama. Sama seperti [konfirmasiGantiNomor].
  Future<AppUser> aturPassword({
    required String kode,
    required String password,
  });

  /// Menyunting profil sendiri: nama, dan alamat bawaan.
  ///
  /// PERHATIKAN APA YANG TIDAK ADA DI SINI, dan keduanya disengaja.
  ///
  /// Tidak ada peran, karena aturan di atas: tidak satu pun method di kontrak ini
  /// boleh mengubah [AppUser.roles].
  ///
  /// Tidak ada nomor HP, karena nomor HP adalah identitas masuk — ia yang menerima
  /// kode. Menggantinya lewat satu kolom isian berarti siapa pun yang sempat
  /// memegang HP orang lain sebentar bisa memindahkan akunnya ke nomornya sendiri,
  /// dan pemilik aslinya terkunci di luar tanpa cara kembali. Menggantinya menuntut
  /// verifikasi kode ke nomor barunya, lewat [mintaKodeGantiNomor] dan
  /// [konfirmasiGantiNomor] di bawah, bukan lewat satu parameter tambahan di sini.
  ///
  /// [alamat] boleh null atau kosong, artinya "tidak ada alamat tersimpan". Ini
  /// bukan alamat order: order membawa alamatnya sendiri, karena satu orang memesan
  /// dari tempat yang berbeda-beda. Yang ini cuma jawaban yang paling sering ia
  /// ketik, disimpan supaya tidak diketik ulang setiap kali memesan.
  Future<AppUser> perbaruiProfil({required String nama, String? alamat});

  /// Langkah pertama mengganti nomor HP sendiri: minta kode dikirim ke nomor yang
  /// BARU, bukan nomor yang sedang dipakai.
  ///
  /// Kepemilikan nomor lama sudah terbukti lewat sesi yang sedang berjalan; yang
  /// belum terbukti justru nomor barunya, dan itulah yang harus dibuktikan sebelum
  /// ia menggantikan yang lama. Dua langkah, bukan satu langkah nomor+kode
  /// langsung, karena kodenya belum ada sampai langkah ini terkirim — sama seperti
  /// [mintaKode] dan [masuk] yang juga dua langkah untuk alasan yang sama persis.
  Future<void> mintaKodeGantiNomor({required String noHpBaru});

  /// Langkah kedua: menukar kode yang benar dengan nomor HP yang baru.
  ///
  /// Sesi yang sedang berjalan tidak berakhir dan tidak perlu diperbarui sesudah
  /// ini. Yang berubah cuma [AppUser.noHp] pada akun yang sedang masuk.
  Future<AppUser> konfirmasiGantiNomor({
    required String noHpBaru,
    required String kode,
  });

  /// Alasan akun yang sedang masuk belum boleh dihapus, satu kalimat per alasan,
  /// atau daftar kosong kalau boleh.
  ///
  /// Dipanggil SEBELUM meminta kode, supaya orang yang akunnya masih punya pesanan
  /// berjalan atau pengembalian dana yang belum selesai tahu itu sebelum menunggu
  /// OTP WhatsApp, bukan sesudahnya. Kalimatnya sudah ditulis server untuk dibaca pemiliknya
  /// apa adanya; layar menampilkannya tanpa mengubah.
  Future<List<String>> penghalangPenghapusanAkun();

  /// Menghapus akun sendiri, dibuktikan lewat kode OTP ke nomor akun yang sedang
  /// masuk -- diminta lewat [mintaKode] yang sama, bukan endpoint terpisah.
  ///
  /// Menuntut kode, bukan cuma sesi yang sedang berjalan, dengan alasan yang sama
  /// seperti [aturPassword] dan [konfirmasiGantiNomor]: penghapusan tidak bisa
  /// ditarik, dan sesi yang dicuri sesaat tidak boleh cukup untuk melakukannya.
  ///
  /// Kalau berhasil, sesi ikut berakhir seperti [keluar]: tokennya dibuang dan
  /// [watchUserAktif] mengumumkan `null`, sehingga router memindahkan layar ke
  /// layar masuk sendiri. Kalau server menolak karena masih ada penghalang (lihat
  /// [penghalangPenghapusanAkun]) atau kodenya salah, sesi TIDAK berubah dan
  /// pemanggil menerima galat dengan kalimat yang layak ditampilkan.
  Future<void> hapusAkun({required String kode});

  Future<void> keluar();
}
