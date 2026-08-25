import 'package:flutter/material.dart';

import '../../domain/enums.dart';

/// Tema tunggal aplikasi.
///
/// Semua warna dan jarak diambil dari sini — tidak boleh ada `Color(0xFF...)`
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
    final skema = ColorScheme.fromSeed(
      seedColor: _biruUpnvj,
      brightness: brightness,
    ).copyWith(secondary: _kuningAksen);

    return ThemeData(
      useMaterial3: true,
      colorScheme: skema,
      scaffoldBackgroundColor: skema.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: skema.surface,
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
