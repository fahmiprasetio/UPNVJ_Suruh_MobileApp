import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/galat_api.dart';
import '../../../../core/api/idempotency_key.dart';
import '../../../../core/config/batas_masukan.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/models/order.dart';
import '../../../../domain/service_catalog.dart';
import '../../../../core/providers/repository_providers.dart';

/// Lembar penyelesaian order: foto bukti dan catatan serah-terima harus lengkap,
/// baru order boleh ditandai selesai.
///
/// Foto bukti dibuat wajib, bukan disarankan. Tanpa foto, "selesai" cuma
/// pengakuan runner, dan pengakuan tidak bisa ditunjukkan ke klien yang
/// protes maupun dipakai admin saat menengahi. Urutannya juga disengaja:
/// tombol selesai baru hidup setelah fotonya ada, jadi tidak ada jalan untuk
/// menutup order lebih dulu dan menyusulkan fotonya nanti.
///
/// ## Yang maroon selalu langkah yang sedang hidup
///
/// Sebelumnya tombol foto bergaris tipis dan tombol Tandai Selesai maroon
/// selebar lembar, padahal saat lembar ini baru dibuka yang bisa dilakukan
/// justru cuma memotret: Tandai Selesai mati sampai fotonya ada. Yang paling
/// keras bicara adalah tombol yang tidak bisa ditekan, dan yang harus ditekan
/// tampil seperti pilihan sampingan. Runner yang menekan tombol besar lalu
/// tidak terjadi apa-apa akan menyimpulkan aplikasinya rusak, bukan bahwa ada
/// syarat yang belum ia penuhi.
///
/// Sekarang maroonnya berpindah mengikuti langkah yang sedang hidup: tombol
/// foto selagi fotonya belum ada, Tandai Selesai setelah ada. Dua tombol maroon
/// tidak pernah hidup bersamaan di lembar ini.
///
/// Mengembalikan `true` lewat [Navigator.pop] kalau order berhasil ditutup.
class LembarSelesaikanOrder extends ConsumerStatefulWidget {
  const LembarSelesaikanOrder({super.key, required this.order});

  final Order order;

  @override
  ConsumerState<LembarSelesaikanOrder> createState() =>
      _LembarSelesaikanOrderState();
}

class _LembarSelesaikanOrderState extends ConsumerState<LembarSelesaikanOrder> {
  final _catatanController = TextEditingController();

  String? _fotoBuktiUrl;
  String? _pesanGalatFoto;
  bool _sedangAmbilFoto = false;
  bool _sedangMenutup = false;
  final Map<String, String> _keySelesai = {};

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layanan = serviceInfoOf(widget.order.serviceType);
    final sibuk = _sedangAmbilFoto || _sedangMenutup;

    // Bisa digulung, karena papan ketik yang terbuka untuk kolom catatan
    // memakan separuh layar ponsel pendek dan sisanya tidak cukup memuat
    // lembar ini utuh. Tanpa ini yang muncul adalah pita luber kuning-hitam
    // tepat saat runner mulai mengetik.
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F8EA),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    layanan.icon,
                    color: const Color(0xFF00AA13),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selesaikan ${layanan.nama}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.order.kodeOrder,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Foto bukti',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Wajib. Inilah yang membedakan pekerjaan selesai dari pengakuan '
            'selesai.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          if (_fotoBuktiUrl == null)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: sibuk ? null : _ambilFoto,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00AA13),
                  disabledBackgroundColor: const Color(0xFFA7E5AF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _sedangAmbilFoto
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.camera_alt_rounded, size: 20),
                label: Text(
                  _sedangAmbilFoto ? 'Mengunggah foto...' : 'Ambil Foto Bukti',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            )
          else
            _KartuFotoTerkirim(onGanti: sibuk ? null : _ambilFoto),
          if (_pesanGalatFoto != null) ...[
            const SizedBox(height: 8),
            Text(
              _pesanGalatFoto!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
          if (ref.watch(fotoBuktiTiruanProvider)) ...[
            const SizedBox(height: 10),
            const _CatatanAlatPenguji(),
          ],
          const SizedBox(height: 18),
          TextField(
            controller: _catatanController,
            maxLength: BatasMasukan.catatanSerahTerima,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            minLines: 2,
            enabled: !sibuk,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
            decoration: InputDecoration(
              labelText: 'Catatan serah terima',
              hintText: 'Barang dititipkan ke penjaga kos',
              helperText: 'Wajib: tulis lokasi atau penerima hasil pekerjaan.',
              helperStyle: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF6B7280),
              ),
              counterStyle: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF9CA3AF),
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF00AA13),
                  width: 1.8,
                ),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed:
                  _fotoBuktiUrl == null ||
                      _catatanController.text.trim().isEmpty ||
                      sibuk
                  ? null
                  : _tandaiSelesai,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00AA13),
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                foregroundColor: Colors.white,
                disabledForegroundColor: const Color(0xFF9CA3AF),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _sedangMenutup
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Tandai Selesai',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _ambilFoto() async {
    setState(() {
      _sedangAmbilFoto = true;
      _pesanGalatFoto = null;
    });

    final String? url;
    try {
      url = await ref
          .read(fotoBuktiRepositoryProvider)
          .ambilDanUnggah(orderId: widget.order.id);
    } catch (galat) {
      if (!mounted) return;
      final pesan = galat is GalatApi
          ? galat.pesan
          : 'Foto gagal diunggah. Coba lagi, ya.';
      setState(() {
        _sedangAmbilFoto = false;
        _pesanGalatFoto = pesan;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _sedangAmbilFoto = false;
      if (url != null) {
        _fotoBuktiUrl = url;
        _pesanGalatFoto = null;
      } else if (kIsWeb) {
        _pesanGalatFoto =
            'Tidak ada foto yang dipilih. Pastikan memilih berkas gambar (JPG/PNG).';
      }
    });
  }

  Future<void> _tandaiSelesai() async {
    final fotoBuktiUrl = _fotoBuktiUrl;
    final catatan = _catatanController.text.trim();
    if (fotoBuktiUrl == null || catatan.isEmpty) return;

    setState(() => _sedangMenutup = true);

    final requestKey = '$fotoBuktiUrl|$catatan';
    final idempotencyKey = _keySelesai.putIfAbsent(
      requestKey,
      buatIdempotencyKey,
    );
    try {
      await ref
          .read(orderRepositoryProvider)
          .selesaikanOrder(
            orderId: widget.order.id,
            fotoBuktiUrl: fotoBuktiUrl,
            catatanSerahTerima: catatan,
            idempotencyKey: idempotencyKey,
          );
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangMenutup = false);
      _kabari(
        galat is GalatApi ? galat.pesan : 'Order gagal ditutup. Coba lagi, ya.',
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _kabari(String pesan) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(pesan)));
  }
}

/// Bukti yang sudah aman di server, dan satu-satunya jalan menggantinya.
///
/// Hijau, bukan maroon: ini pernyataan bahwa satu syarat sudah terpenuhi, dan
/// hijau di sistem ini memang berarti sesuatu yang sudah benar. Begitu kartu
/// ini muncul, maroon pindah ke Tandai Selesai di bawahnya.
///
/// Yang ditulis di bawah judul bukan lagi alamat berkasnya. Tautan mentah tidak
/// menjawab satu pun pertanyaan yang mungkin dipunyai runner tentang fotonya,
/// dan yang ia butuhkan cuma tahu bahwa fotonya sudah aman dan bisa diganti
/// kalau salah.
class _KartuFotoTerkirim extends StatelessWidget {
  const _KartuFotoTerkirim({required this.onGanti});

  final VoidCallback? onGanti;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8EA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC7EBC9), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF00AA13),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Foto bukti terkirim',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tersimpan di server, ikut tercatat di order ini.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onGanti,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00AA13),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Ganti',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pengakuan bahwa fotonya belum sungguhan, khusus untuk alat penguji foto.
class _CatatanAlatPenguji extends StatelessWidget {
  const _CatatanAlatPenguji();

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.science_outlined, size: 16, color: skema.error),
        const SizedBox(width: AppTheme.spasiKecil),
        Expanded(
          child: Text(
            'ALAT PENGUJI: kamera dan penyimpanan foto belum terpasang. '
            'Tombol ini menghasilkan tautan tiruan, bukan foto sungguhan.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: skema.error),
          ),
        ),
      ],
    );
  }
}
