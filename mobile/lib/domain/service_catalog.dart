import 'package:flutter/material.dart';

import 'enums.dart';

/// Metadata tampilan untuk satu layanan di beranda klien.
@immutable
class ServiceInfo {
  const ServiceInfo({
    required this.type,
    required this.nama,
    required this.deskripsi,
    required this.icon,
    this.gambarIkon,
    this.skalaIkon = 1,
  });

  final ServiceType type;
  final String nama;
  final String deskripsi;
  final IconData icon;

  /// Ilustrasi maskot buaya untuk petak layanan di beranda, dipakai kalau
  /// ada; `icon` tetap dipakai apa adanya di tempat lain (riwayat, chat,
  /// kartu order) yang butuh glyph kecil, bukan ilustrasi penuh.
  final String? gambarIkon;

  /// Pengali ukuran tampil [gambarIkon] di beranda. Sebagian ilustrasi
  /// (Jastip Makanan, Bantu Pindah Kos) menggambar karakternya lebih kecil
  /// dalam kanvasnya sendiri dibanding yang lain, jadi kelihatan lebih kecil
  /// walau kotaknya sama -- ini yang menyamakan besarnya secara visual, bukan
  /// mengubah kotaknya.
  final double skalaIkon;

  OrderTrack get track => type.track;
}

/// Enam layanan resmi + satu pintu permintaan bebas (bagian 4, "Layar pertama:
/// dua pintu"). Urutannya menentukan urutan tampil di beranda: baris pertama
/// Anter Jemput/Jastip Makanan/Bersih Kamar Mandi, baris kedua Bersih-Bersih
/// Kos/Bantu Pindah Kos/Jastip Barang, sesuai rancangan.
const List<ServiceInfo> serviceCatalog = [
  ServiceInfo(
    type: ServiceType.anterJemput,
    nama: 'Anter Jemput',
    deskripsi: 'Diantar atau dijemput ke tujuan',
    icon: Icons.two_wheeler_outlined,
    gambarIkon: 'assets/layanan/anter_jemput.png',
  ),
  ServiceInfo(
    type: ServiceType.jastipMakanan,
    nama: 'Jastip Makanan',
    deskripsi: 'Titip beli makanan & minuman',
    icon: Icons.lunch_dining_outlined,
    gambarIkon: 'assets/layanan/jastip_makanan.png',
    skalaIkon: 1.1,
  ),
  ServiceInfo(
    type: ServiceType.bersihKamarMandi,
    nama: 'Bersih Kamar Mandi',
    deskripsi: 'Sikat dan kuras kamar mandi',
    icon: Icons.bathtub_outlined,
    gambarIkon: 'assets/layanan/bersih_kamar_mandi.png',
  ),
  ServiceInfo(
    type: ServiceType.bersihKos,
    nama: 'Bersih-Bersih Kos',
    deskripsi: 'Beres-beres kamar kos',
    icon: Icons.cleaning_services_outlined,
    gambarIkon: 'assets/layanan/bersih_kos.png',
  ),
  ServiceInfo(
    type: ServiceType.bantuPindahKos,
    nama: 'Bantu Pindah Kos',
    deskripsi: 'Angkut barang pindahan',
    icon: Icons.local_shipping_outlined,
    gambarIkon: 'assets/layanan/pindah_kos.png',
    skalaIkon: 1.1,
  ),
  ServiceInfo(
    type: ServiceType.jastipBarang,
    nama: 'Jastip Barang',
    deskripsi: 'Titip beli atau ambil barang',
    icon: Icons.shopping_bag_outlined,
    gambarIkon: 'assets/layanan/jastip_barang.png',
  ),
  ServiceInfo(
    type: ServiceType.permintaanLain,
    nama: 'Permintaan Lain',
    deskripsi: 'Ceritakan kebutuhanmu',
    icon: Icons.edit_note_outlined,
  ),
];

ServiceInfo serviceInfoOf(ServiceType type) =>
    serviceCatalog.firstWhere((s) => s.type == type);

/// Palet warna dan ikon visual modern Gojek Aloha untuk setiap kategori layanan.
extension ServiceTypeAloha on ServiceType {
  ({Color latar, Color aksen}) get warnaAloha {
    switch (this) {
      case ServiceType.anterJemput:
        return (latar: const Color(0xFFE8F8EA), aksen: const Color(0xFF00AA13));
      case ServiceType.jastipMakanan:
        return (latar: const Color(0xFFFFF7ED), aksen: const Color(0xFFEA580C));
      case ServiceType.jastipBarang:
        return (latar: const Color(0xFFEFF6FF), aksen: const Color(0xFF2563EB));
      case ServiceType.bersihKamarMandi:
      case ServiceType.bersihKos:
        return (latar: const Color(0xFFF0FDF4), aksen: const Color(0xFF059669));
      case ServiceType.bantuPindahKos:
        return (latar: const Color(0xFFFAF5FF), aksen: const Color(0xFF9333EA));
      case ServiceType.permintaanLain:
        return (latar: const Color(0xFFF1F5F9), aksen: const Color(0xFF475569));
    }
  }

  IconData get ikonAloha {
    switch (this) {
      case ServiceType.anterJemput:
        return Icons.two_wheeler_rounded;
      case ServiceType.jastipMakanan:
        return Icons.lunch_dining_rounded;
      case ServiceType.jastipBarang:
        return Icons.shopping_bag_outlined;
      case ServiceType.bersihKamarMandi:
        return Icons.bathtub_outlined;
      case ServiceType.bersihKos:
        return Icons.cleaning_services_rounded;
      case ServiceType.bantuPindahKos:
        return Icons.local_shipping_outlined;
      case ServiceType.permintaanLain:
        return Icons.more_horiz_rounded;
    }
  }
}
