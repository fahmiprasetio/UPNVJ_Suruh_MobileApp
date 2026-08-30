import 'package:flutter/material.dart';

import '../../domain/enums.dart';

/// Tema tunggal aplikasi.
///
/// Semua warna dan jarak diambil dari sini, tidak boleh ada `Color(0xFF...)`
/// yang ditulis langsung di dalam layar. Satu berkas ini yang berubah kalau
/// paletnya berubah.
///
/// ## Dari mana warnanya
///
/// Seluruhnya dicuplik dari lencana buaya bermotor di `assets/logo/lencana.png`,
/// bukan dibangkitkan dari roda warna. Hijau badan buaya jadi warna utama,
/// maroon badan motornya jadi warna tindakan, tinta garis luarnya jadi warna
/// bayangan. Aturannya tertulis di DESIGN.md sebagai Badge Sourcing Rule: warna
/// yang tidak bisa ditunjuk di lencananya tidak boleh masuk ke sini.
///
/// Ini menggantikan navy `#16336B` dengan aksen kuning `#F5A524` yang dipakai
/// sebelumnya. Navy itu tidak pernah punya asal-usul; ia dipilih karena terdengar
/// seperti warna kampus, dan hasilnya aplikasi yang bisa jadi milik siapa saja.
///
/// ## Dua suara, tidak lebih
///
/// Hijau menyatakan apa yang **sudah benar**: tahap yang terlewati, harga yang
/// disepakati, pekerjaan yang sedang berjalan. Maroon meminta **ditekan**:
/// tombol utama, TERIMA milik runner, pintu permintaan bebas. Layar dengan tiga
/// warna aksen berarti ada satu yang salah tempat, bukan variasi.
class AppTheme {
  const AppTheme._();

  // --- Warna yang dicuplik dari lencana ---

  /// Badan buaya. Warna merek, tahap yang terlewati, harga yang sudah pasti.
  static const Color hijauLencana = Color(0xFF4B7043);

  /// Pengganti [hijauLencana] di tema gelap. Hijau penuh sebagai teks di atas
  /// latar gelap jatuh di bawah ambang keterbacaan; yang ini tidak.
  static const Color hijauLencanaMuda = Color(0xFF8FBF80);

  /// Badan motor. Warna tindakan, dan satu-satunya warna yang boleh menuntut
  /// jari pengguna.
  static const Color maroonMotor = Color(0xFF8B2331);

  /// Pengganti [maroonMotor] di tema gelap, dengan alasan yang sama.
  static const Color maroonMotorMuda = Color(0xFFE8909A);

  /// Tinta garis luar lencana. Bukan warna teks umum, itu tugas `onSurface`.
  /// Dipakai menyemir bayangan, supaya bayangannya terbaca tercetak, bukan kotor.
  static const Color tintaLencana = Color(0xFF1E302E);

  // --- Jarak dan sudut ---

  static const double spasiKecil = 8;

  /// Jarak antar elemen di dalam satu kelompok, dan sisi dalam kartu.
  static const double spasiSedang = 16;
  static const double spasiBesar = 24;

  /// Sudut terlembut, untuk wadah yang memuat satu satuan isi.
  static const double radiusKartu = 16;

  /// Lebih rapat daripada kartu, supaya kendali tidak pernah terbaca sebagai
  /// kartu: tombol, kolom isian, dan keping ikon di dalam kartu layanan.
  static const double radiusKontrol = 12;

  /// Sudut penuh, khusus label keadaan. Bulat penuh adalah cara mata menemukan
  /// status tanpa membacanya, jadi ia tidak boleh dipakai untuk hal lain.
  static const double radiusPil = 999;

  // --- Bayangan ---
  //
  // Disemir tinta lencana atau warna elemennya sendiri, tidak pernah hitam
  // murni. Sistem hijau-putih yang dibayangi `#000` terlihat kotor; dibayangi
  // tintanya sendiri ia terlihat tercetak.

  /// Kartu yang perlu berdiri di atas latar yang ramai.
  static List<BoxShadow> get bayanganAngkat => [
    BoxShadow(
      color: tintaLencana.withValues(alpha: 0.10),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Lembar bawah dan panel pembayaran, dicorkan ke atas.
  static List<BoxShadow> get bayanganLembar => [
    BoxShadow(
      color: tintaLencana.withValues(alpha: 0.16),
      blurRadius: 24,
      offset: const Offset(0, -4),
    ),
  ];

  static ThemeData terang() => _bangun(Brightness.light);

  static ThemeData gelap() => _bangun(Brightness.dark);

  static ThemeData _bangun(Brightness brightness) {
    final gelap = brightness == Brightness.dark;

    // Dua skema dibangun, lalu peran sekundernya diambil dari yang maroon.
    //
    // Bukan sekadar menimpa `secondary` dengan satu warna: peran turunannya
    // (`secondaryContainer`, `onSecondaryContainer`) ikut harus maroon, dan
    // membiarkannya tetap hijau membuat pintu permintaan bebas di beranda
    // terbaca sebagai kartu hijau kesekian alih-alih pintu yang berbeda.
    // Membangunnya lewat `fromSeed` memberi nilai tonal yang benar menurut
    // Material, bukan tebakan tangan.
    final dariHijau = ColorScheme.fromSeed(
      seedColor: hijauLencana,
      brightness: brightness,
    );
    final dariMaroon = ColorScheme.fromSeed(
      seedColor: maroonMotor,
      brightness: brightness,
    );

    final skema = dariHijau.copyWith(
      primary: gelap ? hijauLencanaMuda : hijauLencana,
      onPrimary: gelap ? const Color(0xFF10240B) : Colors.white,

      secondary: gelap ? maroonMotorMuda : maroonMotor,
      onSecondary: gelap ? const Color(0xFF3B0710) : Colors.white,
      secondaryContainer: dariMaroon.primaryContainer,
      onSecondaryContainer: dariMaroon.onPrimaryContainer,

      // Tangga permukaan ditulis penuh, tidak diserahkan ke `fromSeed`.
      //
      // Bawaan Material menjaga permukaannya nyaris tanpa warna supaya mata
      // betah membaca lama. Di sini itu justru yang harus dihindari: latar
      // abu-abu tanpa arah warna adalah persis rupa "aplikasi Flutter bawaan"
      // yang jadi anti-referensi sistem ini. Terang memakai putih kehijauan,
      // gelap memakai hutan dalam, dan keduanya menjaga jarak dua tingkat
      // antara kartu dan latarnya supaya kartu benar-benar berdiri.
      surface: gelap ? const Color(0xFF13211A) : const Color(0xFFF5F8F4),
      surfaceContainerLowest: gelap ? const Color(0xFF0E1813) : Colors.white,
      surfaceContainerLow: gelap
          ? const Color(0xFF182820)
          : const Color(0xFFF0F5EE),
      surfaceContainer: gelap
          ? const Color(0xFF1F3229)
          : const Color(0xFFE9F0E7),
      surfaceContainerHigh: gelap
          ? const Color(0xFF253B31)
          : const Color(0xFFE3ECE1),
      surfaceContainerHighest: gelap
          ? const Color(0xFF2E483C)
          : const Color(0xFFDCE7DA),

      onSurface: gelap ? const Color(0xFFEAF1EE) : const Color(0xFF17231C),
      onSurfaceVariant: gelap
          ? const Color(0xFFB2C8BE)
          : const Color(0xFF4A5A50),
      outline: gelap ? const Color(0xFF5E8271) : const Color(0xFF6F8577),
      outlineVariant: gelap ? const Color(0xFF395648) : const Color(0xFFD3DFD0),
    );

    /// Kartu berdiri di atas latar, bukan menyatu dengannya.
    ///
    /// Di terang kartunya putih murni di atas putih kehijauan: bedanya cuma
    /// 1,07:1, jadi yang benar-benar menandai kartu adalah garis rambutnya,
    /// bukan isiannya. Di gelap sebaliknya, warnanya yang bekerja.
    final warnaKartu = gelap
        ? skema.surfaceContainerHigh
        : skema.surfaceContainerLowest;

    return ThemeData(
      useMaterial3: true,
      colorScheme: skema,
      scaffoldBackgroundColor: skema.surface,
      appBarTheme: AppBarTheme(
        // Bukan `skema.surface`: bilah yang warnanya sama persis dengan latar di
        // baliknya tidak punya batas sama sekali, cuma judul yang mengambang.
        backgroundColor: skema.surfaceContainer,
        foregroundColor: skema.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: skema.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: warnaKartu,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusKartu),
          side: BorderSide(color: skema.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Maroon, bukan hijau. Tombol utama adalah hal yang diminta ditekan,
          // dan di sistem ini yang meminta ditekan selalu maroon. Hijau
          // menyatakan sesuatu sudah benar; tombol belum menyatakan apa-apa.
          backgroundColor: skema.secondary,
          foregroundColor: skema.onSecondary,
          // Bayangan yang disemir warna tombolnya sendiri, supaya tindakan
          // utama jadi tujuan yang jelas di layarnya tanpa perlu diperbesar.
          elevation: 3,
          shadowColor: skema.secondary.withValues(alpha: 0.45),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusKontrol),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: skema.surfaceContainer,
        indicatorColor: skema.primaryContainer,
        elevation: 0,
        // Label selalu tampak, bukan cuma yang terpilih. Dua tujuan yang
        // ikonnya mirip-mirip tidak boleh menuntut pengguna menebak yang mana.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((keadaan) {
          final terpilih = keadaan.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: terpilih ? FontWeight.w600 : FontWeight.w500,
            color: terpilih ? skema.onSurface : skema.onSurfaceVariant,
          );
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        // Segmen terpilih hijau, bukan maroon.
        //
        // Bawaan Material memakai secondaryContainer untuk segmen terpilih, dan
        // sejak maroon jadi warna sekunder, setiap pilihan yang sedang aktif di
        // aplikasi ini berubah jadi merah muda. Itu melanggar aturan dua suara:
        // maroon meminta ditekan, hijau menyatakan apa yang sudah benar, dan
        // pilihan yang sedang aktif jelas hal kedua. Merah pada sesuatu yang
        // sudah dipilih terbaca seperti peringatan yang belum diselesaikan.
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((keadaan) {
            if (keadaan.contains(WidgetState.selected)) {
              return skema.primaryContainer;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((keadaan) {
            if (keadaan.contains(WidgetState.selected)) {
              return skema.onPrimaryContainer;
            }
            return skema.onSurfaceVariant;
          }),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: skema.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusKontrol),
          borderSide: BorderSide(color: skema.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusKontrol),
          borderSide: BorderSide(color: skema.outlineVariant),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: spasiSedang),
      ),
    );
  }
}

/// Warna lencana status order.
///
/// Dipisah dari [AppTheme] karena pemetaannya keputusan domain (status mana yang
/// "sedang berjalan", mana yang "butuh tindakan klien"), bukan sekadar selera.
///
/// ## Kenapa `mencariRunner` pindah dari sekunder
///
/// Sejak maroon jadi warna sekunder, `secondaryContainer` dan `errorContainer`
/// sama-sama merah muda dan tidak terbedakan mata pada pil selebar 11 piksel.
/// Merah di sini hanya boleh berarti satu hal, yaitu **ada yang harus kamu
/// bayar**, jadi `mencariRunner` pindah ke hijau.
///
/// Hasilnya hijau punya dua tingkat yang bisa dibaca berurutan: pucat berarti
/// ordernya sedang ditawarkan ke runner, penuh berarti ada orang yang sedang
/// mengerjakannya. Yang penuh sengaja yang paling mencolok, karena itulah
/// keadaan yang paling ingin dilihat pemesannya di daftar.
extension OrderStatusWarna on OrderStatus {
  Color warnaLatar(ColorScheme skema) => switch (this) {
    OrderStatus.permintaan => skema.surfaceContainerHighest,
    OrderStatus.menungguPersetujuanKlien => skema.tertiaryContainer,
    OrderStatus.menungguPembayaran => skema.errorContainer,
    OrderStatus.mencariRunner => skema.primaryContainer,
    OrderStatus.dikerjakan => skema.primary,
    OrderStatus.selesai => skema.surfaceContainerHighest,
    OrderStatus.batal => skema.surfaceContainerHighest,
  };

  Color warnaTeks(ColorScheme skema) => switch (this) {
    OrderStatus.permintaan => skema.onSurfaceVariant,
    OrderStatus.menungguPersetujuanKlien => skema.onTertiaryContainer,
    OrderStatus.menungguPembayaran => skema.onErrorContainer,
    OrderStatus.mencariRunner => skema.onPrimaryContainer,
    OrderStatus.dikerjakan => skema.onPrimary,
    OrderStatus.selesai => skema.onSurfaceVariant,
    OrderStatus.batal => skema.onSurfaceVariant,
  };
}
