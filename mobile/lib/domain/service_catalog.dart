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
  });

  final ServiceType type;
  final String nama;
  final String deskripsi;
  final IconData icon;

  OrderTrack get track => type.track;
}

/// Enam layanan resmi + satu pintu permintaan bebas (bagian 4, "Layar pertama:
/// dua pintu"). Urutannya menentukan urutan tampil di beranda.
const List<ServiceInfo> serviceCatalog = [
  ServiceInfo(
    type: ServiceType.anterJemput,
    nama: 'Anter Jemput',
    deskripsi: 'Diantar atau dijemput ke tujuan',
    icon: Icons.two_wheeler_outlined,
  ),
  ServiceInfo(
    type: ServiceType.jastipMakanan,
    nama: 'Jastip Makanan',
    deskripsi: 'Titip beli makanan & minuman',
    icon: Icons.lunch_dining_outlined,
  ),
  ServiceInfo(
    type: ServiceType.jastipBarang,
    nama: 'Jastip Barang',
    deskripsi: 'Titip beli atau ambil barang',
    icon: Icons.shopping_bag_outlined,
  ),
  ServiceInfo(
    type: ServiceType.bantuPindahKos,
    nama: 'Bantu Pindah Kos',
    deskripsi: 'Angkut barang pindahan',
    icon: Icons.local_shipping_outlined,
  ),
  ServiceInfo(
    type: ServiceType.bersihKos,
    nama: 'Bersih-Bersih Kos',
    deskripsi: 'Beres-beres kamar kos',
    icon: Icons.cleaning_services_outlined,
  ),
  ServiceInfo(
    type: ServiceType.bersihKamarMandi,
    nama: 'Bersih Kamar Mandi',
    deskripsi: 'Sikat dan kuras kamar mandi',
    icon: Icons.bathtub_outlined,
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
