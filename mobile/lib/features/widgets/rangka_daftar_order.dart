import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Bentuk kasar daftar order selagi isinya diambil.
///
/// Bukan pemutar di tengah layar. Yang dinanti pengguna adalah daftar, dan
/// rangka yang sudah berbentuk daftar membuat isinya terasa sedang datang alih-
/// alih membuat layarnya terasa berhenti. Hanya muncul pada pengambilan pertama;
/// pengambilan ulang berkala mempertahankan daftar yang sudah tampil.
///
/// Dipakai bersama daftar klien dan daftar runner. Perbedaannya cuma satu,
/// [denganTombol]: kartu runner punya tombol selebar kartu di kakinya, kartu
/// klien tidak. Menyamakan keduanya justru merusak gunanya, karena rangka yang
/// bentuknya meleset dari isi yang datang menyebabkan lompatan tata letak tepat
/// pada saat orang mulai membaca.
class RangkaDaftarOrder extends StatelessWidget {
  const RangkaDaftarOrder({
    super.key,
    this.jumlah = 3,
    this.denganJudulBagian = true,
    this.denganTombol = false,
  });

  /// Berapa kartu bayangan yang digambar. Tiga cukup untuk mengisi layar
  /// ponsel; lebih dari itu cuma menambah kerja untuk piksel di bawah lipatan.
  final int jumlah;

  /// Balok judul bagian di atas kartu pertama, untuk daftar yang memang
  /// berjudul bagian ("Sedang dikerjakan", "Sudah selesai").
  final bool denganJudulBagian;

  final bool denganTombol;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    Widget balok(double lebar, double tinggi) => Container(
      width: lebar,
      height: tinggi,
      decoration: BoxDecoration(
        color: skema.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.spasiKecil / 2),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      children: [
        if (denganJudulBagian)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spasiKecil + 2),
            child: balok(150, 20),
          ),
        for (var i = 0; i < jumlah; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spasiKecil + 2),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spasiSedang),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        balok(120, 14),
                        const Spacer(),
                        balok(72, 18),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spasiKecil),
                    balok(160, 12),
                    const SizedBox(height: AppTheme.spasiSedang),
                    balok(110, 22),
                    if (denganTombol) ...[
                      const SizedBox(height: AppTheme.spasiSedang),
                      balok(double.infinity, 46),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
