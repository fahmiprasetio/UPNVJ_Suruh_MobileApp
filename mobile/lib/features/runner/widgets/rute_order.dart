import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Jemput dan tujuan sebagai satu blok, bukan dua baris yang kebetulan
/// bertetangga.
///
/// Dua alamat yang ditulis berurutan tanpa apa-apa di antaranya terbaca sebagai
/// dua fakta terpisah, padahal yang menentukan layak-tidaknya order justru
/// hubungan keduanya: seberapa jauh dari sini ke sana. Garis penghubung antara
/// kedua titiknya yang menyatakan hubungan itu, dan wadah bernada satu tingkat
/// membuat keduanya terbaca sekali pandang sebagai satu rute.
///
/// Titik dan garisnya sengaja memakai kosakata yang sama dengan linimasa status
/// order: cakram kecil disambung garis 2 piksel. Runner dan klien melihat
/// bentuk yang sama untuk hal yang sama, yaitu perjalanan dari satu tempat ke
/// tempat lain.
class RuteOrder extends StatelessWidget {
  const RuteOrder({super.key, required this.jemput, required this.tujuan});

  final String? jemput;
  final String? tujuan;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final keduanya = jemput != null && tujuan != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spasiKecil + 4),
      decoration: BoxDecoration(
        color: skema.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusKontrol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (jemput != null)
            _BarisAlamat(
              label: 'Jemput',
              alamat: jemput!,
              // Cincin terbuka, bukan cakram penuh: titik berangkat adalah
              // tempat yang ditinggalkan, dan yang penuh disimpan untuk tempat
              // yang dituju.
              penanda: _Penanda.cincin,
              berlanjut: keduanya,
            ),
          if (tujuan != null)
            _BarisAlamat(
              label: 'Tujuan',
              alamat: tujuan!,
              penanda: _Penanda.pin,
              berlanjut: false,
            ),
        ],
      ),
    );
  }
}

enum _Penanda { cincin, pin }

class _BarisAlamat extends StatelessWidget {
  const _BarisAlamat({
    required this.label,
    required this.alamat,
    required this.penanda,
    required this.berlanjut,
  });

  final String label;
  final String alamat;
  final _Penanda penanda;

  /// Benar kalau masih ada alamat di bawahnya, jadi garis penghubungnya perlu
  /// digambar dan barisnya perlu menyisakan jarak untuk baris berikutnya.
  final bool berlanjut;

  @override
  Widget build(BuildContext context) {
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    // Tinggi barisnya diukur dari isinya lebih dulu, karena garis penghubung
    // harus setinggi teks di sebelahnya dan teks itu bisa satu atau dua baris.
    // Tanpa ini `Expanded` pada garisnya berada di dalam kolom yang tingginya
    // tak terbatas (kartu ini hidup di dalam ListView), dan Flutter menolaknya.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              // Setinggi satu baris label supaya penandanya sejajar dengan huruf
              // di sebelahnya, bukan menempel di tepi atas kotaknya.
              SizedBox(
                height: 18,
                child: Center(
                  child: penanda == _Penanda.cincin
                      ? Container(
                          height: 10,
                          width: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: skema.primary, width: 2),
                          ),
                        )
                      : Icon(Icons.place, size: 14, color: skema.primary),
                ),
              ),
              if (berlanjut)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: skema.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppTheme.spasiKecil + 2),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: berlanjut ? AppTheme.spasiKecil : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: teks.labelSmall?.copyWith(
                      color: skema.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    alamat,
                    style: teks.bodyMedium?.copyWith(color: skema.onSurface),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
