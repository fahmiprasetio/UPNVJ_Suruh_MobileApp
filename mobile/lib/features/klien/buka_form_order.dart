import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../domain/enums.dart';
import '../../domain/models/order.dart';
import '../../domain/service_catalog.dart';

/// Satu tempat yang memutuskan form mana yang dibuka untuk satu layanan.
///
/// Keputusan ini dulu tinggal di beranda saja, ketika beranda memang satu-satunya
/// pintu masuk ke form order. "Pesan lagi" di riwayat adalah pintu kedua, dan dua
/// pintu yang memutuskan sendiri-sendiri adalah dua pintu yang bisa tidak sepakat:
/// yang satu bisa menawarkan layanan yang formnya belum dibuat, sementara yang lain
/// menyembunyikannya.

/// Benar kalau layanan ini sudah punya form untuk membuatnya.
///
/// Seluruh Jalur B bermuara ke satu form permintaan yang sama, dan seluruh
/// Jalur A sekarang punya formnya sendiri.
bool adaFormOrder(ServiceType layanan) =>
    layanan.track == OrderTrack.jalurB ||
    layanan == ServiceType.anterJemput ||
    layanan == ServiceType.jastipBarang ||
    layanan == ServiceType.jastipMakanan;

/// Membuka form order untuk [layanan].
///
/// [contoh] adalah order lama yang isinya dipakai mengisi form di muka, dan null
/// berarti form kosong seperti biasa. Ordernya dititipkan lewat `extra` GoRouter,
/// bukan lewat id di jalur rute, karena pemanggilnya selalu sudah memegang
/// ordernya: mengirim idnya saja berarti menyuruh form mengambil ulang sesuatu
/// yang sudah ada di tangan, lengkap dengan keadaan memuat dan galatnya sendiri.
///
/// Konsekuensinya `extra` hilang kalau rutenya dibuka ulang dari tautan langsung
/// atau sesudah aplikasi dimatikan sistem. Yang terjadi kalau begitu cuma form
/// kembali kosong, bukan galat, dan itu memang jawaban yang benar untuk "pesan
/// lagi" yang kehilangan order yang mau diulangnya.
void bukaFormOrder(
  BuildContext context,
  ServiceType layanan, {
  Order? contoh,
}) {
  if (layanan.track == OrderTrack.jalurB) {
    context.push(Rute.formPermintaan(layanan), extra: contoh);
    return;
  }

  switch (layanan) {
    case ServiceType.anterJemput:
      context.push(Rute.formAnterJemput, extra: contoh);
    case ServiceType.jastipBarang:
      context.push(Rute.formJastipBarang, extra: contoh);
    case ServiceType.jastipMakanan:
      context.push(Rute.formJastipMakanan, extra: contoh);
    case _:
      belumTersedia(context, serviceInfoOf(layanan).nama);
  }
}

/// Pemberitahuan sementara untuk pintu yang layarnya belum dibuat.
void belumTersedia(BuildContext context, String namaLayar) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$namaLayar belum dibuat, menyusul.')));
}
