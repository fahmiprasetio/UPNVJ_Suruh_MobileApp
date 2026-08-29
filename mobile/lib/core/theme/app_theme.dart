import 'package:flutter/material.dart';

import '../../domain/enums.dart';

/// Tema tunggal aplikasi.
///
/// Semua warna dan jarak diambil dari sini, tidak boleh ada `Color(0xFF...)`
/// yang ditulis langsung di dalam layar. Kalau nanti mitra memberi panduan
/// warna resmi, satu file ini saja yang berubah.
class AppTheme {
  const AppTheme._();

  /// Biru tua UPNVJ sebagai warna utama, kuning sebagai aksen tindakan.
  static const Color _biruUpnvj = Color(0xFF16336B);
  static const Color _kuningAksen = Color(0xFFF5A524);

  /// Jarak baku antar elemen, dipakai konsisten di semua layar.
  static const double spasiKecil = 8;
  static const double spasiSedang = 16;
  static const double spasiBesar = 24;
  static const double radiusKartu = 16;

  static ThemeData terang() => _bangun(Brightness.light);

  static ThemeData gelap() => _bangun(Brightness.dark);

  static ThemeData _bangun(Brightness brightness) {
    var skema = ColorScheme.fromSeed(
      seedColor: _biruUpnvj,
      brightness: brightness,
    ).copyWith(secondary: _kuningAksen);

    if (brightness == Brightness.dark) {
      // `ColorScheme.fromSeed` sengaja menjaga permukaannya abu-abu nyaris
      // tanpa warna di kedua mode, itu memang bawaan Material 3 supaya mata
      // betah membaca lama. Di tema terang itu tidak masalah karena putihnya
      // tetap terbaca sebagai putih. Di tema gelap, abu-abu nyaris tanpa warna
      // itu terbaca sebagai hitam murahan, dan kartu yang harusnya berdiri di
      // atasnya (`surfaceContainerHigh`, dua tingkat dari latar) nyaris tidak
      // terbedakan mata dari latarnya sendiri karena keduanya sama-sama abu
      // gelap tanpa arah warna. Tangga permukaannya ditimpa di sini dengan
      // navy yang searah warna merek (`_biruUpnvj`), supaya gelapnya terbaca
      // sebagai pilihan, dan supaya kartu benar-benar berdiri di atas latarnya.
      skema = skema.copyWith(
        surface: const Color(0xFF0E1526),
        surfaceContainerLowest: const Color(0xFF0A0F1C),
        surfaceContainerLow: const Color(0xFF121A2E),
        surfaceContainer: const Color(0xFF17203A),
        surfaceContainerHigh: const Color(0xFF1E2942),
        surfaceContainerHighest: const Color(0xFF27324F),
        onSurface: const Color(0xFFE7EAF5),
        onSurfaceVariant: const Color(0xFFA9B3D1),
        outline: const Color(0xFF56618A),
        outlineVariant: const Color(0xFF313D5E),
      );
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: skema,
      scaffoldBackgroundColor: skema.surface,
      appBarTheme: AppBarTheme(
        // Bukan `skema.surface`: appbar yang warnanya sama persis dengan latar
        // di baliknya tidak punya batas sama sekali, cuma judul yang mengambang.
        // Satu tingkat lebih terang menandai "ini bilah, bukan bagian dari isi",
        // dan ini yang paling terasa hilang di tema gelap, tempat perbedaan satu
        // tingkat itu jadi satu-satunya penanda batas selain garis tipis.
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
        // Bukan dibiarkan kosong. Kartu tanpa warna sendiri jatuh ke
        // `surfaceContainerLow`, satu tingkat saja dari latar, dan di tema gelap
        // dua tingkat yang berdekatan itu praktis tidak terbedakan mata: kartu
        // dan lubang di antaranya sama-sama terlihat hitam, dan yang tersisa
        // untuk menandai kartunya cuma garis setipis rambut. `surfaceContainerHigh`
        // memberi kartu warnanya sendiri yang jelas lebih terang dari latar,
        // di kedua tema, bukan cuma di gelap.
        color: skema.surfaceContainerHigh,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusKartu),
          side: BorderSide(color: skema.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: skema.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: skema.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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
/// Dipisah dari [AppTheme] karena pemetaannya adalah keputusan domain (status
/// mana yang "sedang berjalan", mana yang "butuh tindakan klien"), bukan
/// sekadar selera visual.
extension OrderStatusWarna on OrderStatus {
  Color warnaLatar(ColorScheme skema) => switch (this) {
    OrderStatus.permintaan => skema.surfaceContainerHighest,
    OrderStatus.menungguPersetujuanKlien => skema.tertiaryContainer,
    OrderStatus.menungguPembayaran => skema.errorContainer,
    OrderStatus.mencariRunner => skema.secondaryContainer,
    OrderStatus.dikerjakan => skema.primaryContainer,
    OrderStatus.selesai => skema.surfaceContainerHighest,
    OrderStatus.batal => skema.surfaceContainerHighest,
  };

  Color warnaTeks(ColorScheme skema) => switch (this) {
    OrderStatus.permintaan => skema.onSurfaceVariant,
    OrderStatus.menungguPersetujuanKlien => skema.onTertiaryContainer,
    OrderStatus.menungguPembayaran => skema.onErrorContainer,
    OrderStatus.mencariRunner => skema.onSecondaryContainer,
    OrderStatus.dikerjakan => skema.onPrimaryContainer,
    OrderStatus.selesai => skema.onSurfaceVariant,
    OrderStatus.batal => skema.onSurfaceVariant,
  };
}
