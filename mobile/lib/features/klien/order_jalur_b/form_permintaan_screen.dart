import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/batas_masukan.dart';

import '../../../core/format/formatters.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../../domain/service_catalog.dart';
import '../../../providers/repository_providers.dart';

/// Form Jalur B: klien menuliskan kebutuhannya, harga menyusul.
///
/// Satu layar ini melayani seluruh layanan Jalur B, termasuk pintu
/// "Permintaan Lain", karena yang dibutuhkan sama saja: cerita kebutuhan,
/// tempat, dan berapa orang yang diperlukan. Yang membedakan Jalur B dari
/// Jalur A bukan isian formnya, melainkan tidak adanya harga di ujung
/// (rencana capstone bagian 3).
///
/// Karena itu layar ini sengaja tidak punya kalkulator, tidak punya total, dan
/// tidak punya tombol bayar. Menampilkan angka apa pun di sini akan
/// menjanjikan sesuatu yang belum tentu disetujui admin.
class FormPermintaanScreen extends ConsumerStatefulWidget {
  const FormPermintaanScreen({super.key, required this.serviceType});

  final ServiceType serviceType;

  @override
  ConsumerState<FormPermintaanScreen> createState() =>
      _FormPermintaanScreenState();
}

class _FormPermintaanScreenState extends ConsumerState<FormPermintaanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _kebutuhanController = TextEditingController();
  final _alamatController = TextEditingController();

  int _jumlahRunner = 1;
  bool _sedangMengirim = false;

  /// Jadwal diisi di muka dengan besok pagi, bukan dibiarkan kosong.
  ///
  /// Jam sembilan besok adalah tebakan yang paling sering benar untuk
  /// pekerjaan terjadwal, dan isian yang sudah terisi lebih mudah dikoreksi
  /// daripada isian kosong yang harus diisi dari nol. Nilainya tetap tampil
  /// terang-terangan di layar, jadi tidak ada jadwal yang terkirim diam-diam.
  DateTime _jadwal = _besokPagi();

  static DateTime _besokPagi() {
    final besok = DateTime.now().add(const Duration(days: 1));
    return DateTime(besok.year, besok.month, besok.day, 9);
  }

  @override
  void dispose() {
    _kebutuhanController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layanan = serviceInfoOf(widget.serviceType);
    final teks = Theme.of(context).textTheme;
    final skema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(layanan.nama)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.spasiSedang),
            children: [
              _PitaCaraKerja(),
              const SizedBox(height: AppTheme.spasiBesar),
              TextFormField(
                controller: _kebutuhanController,
                maxLength: BatasMasukan.deskripsi,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 6,
                minLines: 4,
                decoration: InputDecoration(
                  labelText: 'Ceritakan kebutuhanmu',
                  hintText: _contohUntuk(widget.serviceType),
                  alignLabelWithHint: true,
                ),
                validator: _validasiKebutuhan,
              ),
              const SizedBox(height: AppTheme.spasiKecil),
              Text(
                'Semakin jelas ceritanya, semakin cepat admin bisa memberi '
                'harga.',
                style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
              ),
              const SizedBox(height: AppTheme.spasiSedang),
              TextFormField(
                controller: _alamatController,
                maxLength: BatasMasukan.alamat,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Alamat',
                  hintText: 'Kos Melati, Jl. Pondok Labu Raya No. 12',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                validator: _validasiAlamat,
              ),
              const SizedBox(height: AppTheme.spasiBesar),
              Text(
                'Kapan dikerjakan?',
                style: teks.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Jadwal ini yang dibaca admin saat menghitung harga. Kalau '
                'timnya penuh di jam itu, admin akan mengusulkan waktu lain '
                'lewat penawarannya.',
                style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
              ),
              const SizedBox(height: AppTheme.spasiKecil),
              _PemilihJadwal(
                nilai: _jadwal,
                onUbah: _sedangMengirim ? null : _pilihJadwal,
              ),
              const SizedBox(height: AppTheme.spasiBesar),
              Text(
                'Butuh berapa orang?',
                style: teks.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Pekerjaan berat seperti pindah kos biasanya butuh lebih dari '
                'satu runner. Order baru ditutup setelah kuotanya penuh.',
                style: teks.bodySmall?.copyWith(color: skema.onSurfaceVariant),
              ),
              const SizedBox(height: AppTheme.spasiKecil),
              _PemilihJumlahRunner(
                nilai: _jumlahRunner,
                onUbah: _sedangMengirim
                    ? null
                    : (nilai) => setState(() => _jumlahRunner = nilai),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spasiSedang),
          child: FilledButton(
            onPressed: _sedangMengirim ? null : _kirimPermintaan,
            child: _sedangMengirim
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kirim Permintaan'),
          ),
        ),
      ),
    );
  }

  Future<void> _kirimPermintaan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sedangMengirim = true);

    final Order order;
    try {
      order = await ref
          .read(orderRepositoryProvider)
          .buatPermintaanJalurB(
            serviceType: widget.serviceType,
            deskripsi: _kebutuhanController.text.trim(),
            jadwalMulai: _jadwal,
            alamatTujuan: _alamatController.text.trim(),
            jumlahRunnerDibutuhkan: _jumlahRunner,
          );
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangMengirim = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Permintaan gagal dikirim: $galat')),
        );
      return;
    }

    if (!mounted) return;
    setState(() => _sedangMengirim = false);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Permintaan ${order.kodeOrder} terkirim. Tunggu penawaran admin.',
          ),
        ),
      );

    context.pushReplacement(Rute.detailOrder(order.id));
  }

  Future<void> _pilihJadwal() async {
    final sekarang = DateTime.now();
    final tanggal = await showDatePicker(
      context: context,
      initialDate: _jadwal,
      // Permintaan untuk waktu yang sudah lewat tidak masuk akal, dan lebih
      // baik dicegah di pemilihnya daripada ditolak setelah dikirim.
      firstDate: DateTime(sekarang.year, sekarang.month, sekarang.day),
      lastDate: sekarang.add(const Duration(days: 90)),
    );
    if (tanggal == null || !mounted) return;

    final jam = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_jadwal),
    );
    if (jam == null || !mounted) return;

    setState(() {
      _jadwal = DateTime(
        tanggal.year,
        tanggal.month,
        tanggal.day,
        jam.hour,
        jam.minute,
      );
    });
  }

  static String? _validasiKebutuhan(String? nilai) {
    final bersih = nilai?.trim() ?? '';
    if (bersih.isEmpty) return 'Ceritakan dulu apa yang kamu butuhkan';
    if (bersih.length < 20) {
      return 'Ceritakan lebih lengkap, admin tidak bisa memberi harga dari '
          'satu kalimat pendek';
    }
    return null;
  }

  static String? _validasiAlamat(String? nilai) {
    final bersih = nilai?.trim() ?? '';
    if (bersih.isEmpty) return 'Alamat wajib diisi';
    if (bersih.length < 5) return 'Tulis alamat lebih jelas';
    return null;
  }

  static String _contohUntuk(ServiceType type) => switch (type) {
    ServiceType.bantuPindahKos =>
      'Pindah dari Kos Melati ke Kos Anggrek, sekitar 2 km. Barang: lemari '
          'plastik, 2 koper, kasur lipat, sekardus buku. Kos lama lantai 2, '
          'tangganya sempit.',
    ServiceType.bersihKos =>
      'Kamar kos 3x4 meter, sudah lama tidak dibersihkan. Perlu sapu, pel, '
          'dan beres-beres meja. Alat pel belum ada.',
    ServiceType.bersihKamarMandi =>
      'Kamar mandi kos, kloset dan bak mandi berkerak. Alat dan sabun sudah '
          'ada di tempat.',
    _ =>
      'Ceritakan apa yang kamu butuhkan dan di mana. Apa pun boleh selama '
          'masuk akal dan aman dikerjakan.',
  };
}

/// Penjelasan alur Jalur B sebelum klien mulai menulis.
///
/// Tanpa ini, klien yang terbiasa dengan Jalur A akan mencari-cari harga dan
/// menyangka layarnya rusak. Menerangkan urutannya di depan lebih murah
/// daripada menjawab pertanyaan yang sama berulang kali lewat chat.
class _PitaCaraKerja extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spasiSedang),
      decoration: BoxDecoration(
        color: skema.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 20,
            color: skema.onSecondaryContainer,
          ),
          const SizedBox(width: AppTheme.spasiKecil),
          Expanded(
            child: Text(
              'Layanan ini tidak punya harga tetap. Kamu menulis kebutuhan, '
              'admin membacanya, lalu mengirim penawaran harga. Kamu bayar '
              'hanya kalau penawarannya kamu setujui.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: skema.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pemilih tanggal dan jam pekerjaan.
///
/// Sebelum ada isian ini, klien diminta menyebut waktunya di dalam ceritanya,
/// dan admin harus menebaknya dari kalimat bebas. Jadwal yang terstruktur bisa
/// dibandingkan dengan jadwal penawaran, diurutkan, dan nanti dipakai
/// mengingatkan runner.
class _PemilihJadwal extends StatelessWidget {
  const _PemilihJadwal({required this.nilai, required this.onUbah});

  final DateTime nilai;
  final VoidCallback? onUbah;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;

    return OutlinedButton.icon(
      onPressed: onUbah,
      icon: const Icon(Icons.event_outlined),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(formatJadwal(nilai)),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        alignment: Alignment.centerLeft,
        foregroundColor: skema.onSurface,
        side: BorderSide(color: skema.outline),
      ),
    );
  }
}

/// Pemilih jumlah runner, dibatasi tiga karena tim mitra cuma tujuh orang.
class _PemilihJumlahRunner extends StatelessWidget {
  const _PemilihJumlahRunner({required this.nilai, required this.onUbah});

  static const int maksimal = 3;

  final int nilai;
  final void Function(int)? onUbah;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: [
        for (var i = 1; i <= maksimal; i++)
          ButtonSegment<int>(
            value: i,
            label: Text(i == 1 ? '1 orang' : '$i orang'),
          ),
      ],
      selected: {nilai},
      onSelectionChanged: onUbah == null
          ? null
          : (pilihan) => onUbah!(pilihan.first),
    );
  }
}
