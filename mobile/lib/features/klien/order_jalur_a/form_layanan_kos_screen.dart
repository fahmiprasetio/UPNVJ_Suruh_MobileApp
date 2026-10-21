import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api/galat_api.dart';
import '../../../core/api/idempotency_key.dart';
import '../../../core/config/batas_masukan.dart';
import '../../../core/format/formatters.dart';
import '../../../core/format/jarak.dart';
import '../../../core/peta/jarak_rute.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pesan_kosong.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/order.dart';
import '../../../domain/models/tarif.dart';
import '../../../domain/pricing/kalkulator_tarif.dart';
import '../../../domain/service_catalog.dart';
import '../peta/pemilih_lokasi_screen.dart';
import 'widgets/ringkasan_harga.dart';

class FormLayananKosScreen extends ConsumerStatefulWidget {
  const FormLayananKosScreen({
    super.key,
    required this.serviceType,
    this.contoh,
  }) : assert(
         serviceType == ServiceType.bantuPindahKos ||
             serviceType == ServiceType.bersihKos ||
             serviceType == ServiceType.bersihKamarMandi,
       );

  final ServiceType serviceType;
  final Order? contoh;

  @override
  ConsumerState<FormLayananKosScreen> createState() =>
      _FormLayananKosScreenState();
}

class _FormLayananKosScreenState
    extends ConsumerState<FormLayananKosScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String _idempotencyKey = buatIdempotencyKey();
  final _catatanController = TextEditingController();
  final _asalController = TextEditingController();
  final _tujuanController = TextEditingController();
  final _jarakController = TextEditingController();
  final _alamatController = TextEditingController();

  LatLng? _posisiAsal;
  LatLng? _posisiTujuan;
  int _jumlahRunner = 1;
  MovingVehicleType _jenisKendaraan = MovingVehicleType.pickup;
  Uint8List? _foto;
  String? _namaFoto;
  bool _sedangHitungRute = false;
  bool _sedangMemilihFoto = false;
  bool _sedangMengirim = false;

  bool get _pindahan => widget.serviceType == ServiceType.bantuPindahKos;
  bool get _kebersihan => !_pindahan;

  @override
  void initState() {
    super.initState();
    final contoh = widget.contoh;
    if (contoh != null) {
      _catatanController.text = contoh.deskripsi ?? '';
      _asalController.text = contoh.alamatJemput ?? '';
      _tujuanController.text = contoh.alamatTujuan ?? '';
      _alamatController.text = contoh.alamatTujuan ?? '';
      _jarakController.text = tulisJarak(contoh.jarakKm);
      _jumlahRunner = contoh.jumlahRunnerDibutuhkan;
      _jenisKendaraan = contoh.jenisKendaraan ?? MovingVehicleType.pickup;
      if (contoh.latitudeJemput != null && contoh.longitudeJemput != null) {
        _posisiAsal = LatLng(
          contoh.latitudeJemput!,
          contoh.longitudeJemput!,
        );
      }
      if (contoh.latitudeTujuan != null && contoh.longitudeTujuan != null) {
        _posisiTujuan = LatLng(
          contoh.latitudeTujuan!,
          contoh.longitudeTujuan!,
        );
      }
    } else {
      final alamat = ref.read(authRepositoryProvider).userAktif?.alamat;
      if (alamat != null && alamat.isNotEmpty) {
        if (_pindahan) {
          _asalController.text = alamat;
        } else {
          _alamatController.text = alamat;
        }
      }
    }
  }

  @override
  void dispose() {
    _catatanController.dispose();
    _asalController.dispose();
    _tujuanController.dispose();
    _jarakController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  HasilTarif? _hasilTarif(Tarif tarif) {
    if (_pindahan) {
      final jarak = bacaJarak(_jarakController.text);
      if (jarak == null) return null;
      return KalkulatorTarif.pindahKos(
        jarakKm: jarak,
        jumlahRunner: _jumlahRunner,
        jenisKendaraan: _jenisKendaraan,
        tarif: tarif,
      );
    }
    return KalkulatorTarif.hitung(widget.serviceType, null, tarif);
  }

  @override
  Widget build(BuildContext context) {
    final tarifAsync = ref.watch(tarifProvider);
    return Scaffold(
      appBar: AppBar(title: Text(serviceInfoOf(widget.serviceType).nama)),
      body: tarifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (galat, _) => PesanKosong(
          ikon: Icons.wifi_off_outlined,
          judul: 'Tarif gagal dimuat',
          keterangan: galat is GalatApi
              ? galat.pesan
              : 'Tidak bisa menghitung harga tanpa tarif. Coba lagi.',
          labelAksi: 'Coba lagi',
          onAksi: () => ref.invalidate(tarifProvider),
        ),
        data: (tarif) => _isi(tarif),
      ),
      bottomNavigationBar: tarifAsync.maybeWhen(
        data: (tarif) {
          final hasil = _hasilTarif(tarif);
          final jarak = bacaJarak(_jarakController.text);
          final melebihiBatas = _pindahan &&
              jarak != null &&
              jarak > tarif.anjemJarakMaksimalKm;
          final bool bolehKirim = !_sedangMengirim &&
              (!_pindahan || (hasil != null && !melebihiBatas));

          return _BilahBawahGojekKos(
            total: hasil?.total,
            labelTotal: melebihiBatas
                ? 'Di Luar Batas'
                : (_pindahan ? 'Pilih Rute' : null),
            labelAksi: melebihiBatas
                ? 'Maks. ${tarif.anjemJarakMaksimalKm.round()} km'
                : 'Buat Order',
            sedangMengirim: _sedangMengirim,
            onTekan: bolehKirim ? _buatOrder : null,
            melebihiBatas: melebihiBatas,
          );
        },
        orElse: () => null,
      ),
    );
  }

  Widget _isi(Tarif tarif) {
    final hasil = _hasilTarif(tarif);
    return SafeArea(
      child: Form(
        key: _formKey,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spasiSedang),
          children: [
            if (_pindahan) ..._formPindahan(tarif) else ..._formKebersihan(),
            const SizedBox(height: AppTheme.spasiBesar),
            if (hasil != null) RingkasanHarga(hasil: hasil),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  List<Widget> _formPindahan(Tarif tarif) => [
    _kolomLokasi(
      controller: _asalController,
      label: 'Lokasi asal pindahan',
      ikon: Icons.trip_origin,
      untukAsal: true,
    ),
    const SizedBox(height: AppTheme.spasiSedang),
    _kolomLokasi(
      controller: _tujuanController,
      label: 'Lokasi tujuan pindahan',
      ikon: Icons.location_on_outlined,
      untukAsal: false,
    ),
    const SizedBox(height: AppTheme.spasiSedang),
    TextFormField(
      controller: _jarakController,
      enabled: !_sedangHitungRute,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      decoration: InputDecoration(
        labelText: 'Jarak rute',
        suffixText: 'km',
        prefixIcon: const Icon(Icons.route_outlined),
        helperText: _sedangHitungRute
            ? 'Menghitung rute jalan...'
            : 'Terisi otomatis setelah dua titik dipilih di peta.',
      ),
      validator: (nilai) {
        final jarak = bacaJarak(nilai ?? '');
        if (jarak == null || jarak <= 0) return 'Jarak wajib diisi';
        if (jarak > tarif.anjemJarakMaksimalKm) {
          return 'Maksimal ${tarif.anjemJarakMaksimalKm.round()} km';
        }
        return null;
      },
    ),
    const SizedBox(height: AppTheme.spasiBesar),
    Text('Butuh berapa runner?', style: Theme.of(context).textTheme.titleSmall),
    const SizedBox(height: AppTheme.spasiKecil),
    SegmentedButton<int>(
      segments: [
        for (var nilai = 1; nilai <= 5; nilai++)
          ButtonSegment(value: nilai, label: Text('$nilai')),
      ],
      selected: {_jumlahRunner},
      onSelectionChanged: _sedangMengirim
          ? null
          : (nilai) => setState(() => _jumlahRunner = nilai.single),
    ),
    const SizedBox(height: AppTheme.spasiBesar),
    Text(
      'Kendaraan yang dibawa runner',
      style: Theme.of(context).textTheme.titleSmall,
    ),
    const SizedBox(height: 4),
    Text(
      'Runner menyediakan kendaraan yang kamu pilih.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
    const SizedBox(height: AppTheme.spasiKecil),
    DropdownButtonFormField<MovingVehicleType>(
      initialValue: _jenisKendaraan,
      decoration: const InputDecoration(prefixIcon: Icon(Icons.local_shipping_outlined)),
      items: [
        for (final kendaraan in MovingVehicleType.values)
          DropdownMenuItem(value: kendaraan, child: Text(kendaraan.label)),
      ],
      onChanged: _sedangMengirim
          ? null
          : (nilai) {
              if (nilai != null) setState(() => _jenisKendaraan = nilai);
            },
    ),
    const SizedBox(height: AppTheme.spasiSedang),
    _kolomCatatan('Catatan tambahan (opsional)', 'Contoh: waktu pindahan atau akses gerbang kos.'),
  ];

  List<Widget> _formKebersihan() => [
    TextFormField(
      controller: _alamatController,
      maxLength: BatasMasukan.alamat,
      maxLines: 2,
      decoration: const InputDecoration(
        counterText: '',
        labelText: 'Alamat kos',
        prefixIcon: Icon(Icons.place_outlined),
      ),
      validator: _validasiAlamat,
    ),
    const SizedBox(height: AppTheme.spasiSedang),
    _kolomCatatan(
      'Catatan kondisi (opsional)',
      'Tulis hal penting yang tidak terlihat jelas dari foto.',
    ),
    const SizedBox(height: AppTheme.spasiBesar),
    Text('Foto kondisi', style: Theme.of(context).textTheme.titleSmall),
    const SizedBox(height: 4),
    Text(
      'Foto wajib agar runner dapat memperkirakan usaha pembersihan sebelum menerima order.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
    const SizedBox(height: AppTheme.spasiKecil),
    if (_foto != null)
      ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusKartu),
        child: Image.memory(_foto!, height: 180, fit: BoxFit.cover),
      ),
    if (_foto != null) const SizedBox(height: AppTheme.spasiKecil),
    OutlinedButton.icon(
      onPressed: _sedangMemilihFoto || _sedangMengirim ? null : _pilihFoto,
      icon: const Icon(Icons.add_a_photo_outlined),
      label: Text(_foto == null ? 'Pilih Foto Kondisi' : 'Ganti Foto'),
    ),
    if (_foto == null)
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          'Foto kondisi belum dipilih.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
  ];

  Widget _kolomCatatan(String label, String hint) => TextFormField(
    controller: _catatanController,
    maxLength: BatasMasukan.deskripsi,
    maxLines: 3,
    minLines: 2,
    textCapitalization: TextCapitalization.sentences,
    decoration: InputDecoration(
      counterText: '',
      labelText: label,
      hintText: hint,
      prefixIcon: const Icon(Icons.notes_outlined),
    ),
  );

  Widget _kolomLokasi({
    required TextEditingController controller,
    required String label,
    required IconData ikon,
    required bool untukAsal,
  }) => TextFormField(
    controller: controller,
    maxLength: BatasMasukan.alamat,
    maxLines: 2,
    decoration: InputDecoration(
      counterText: '',
      labelText: label,
      prefixIcon: Icon(ikon),
      suffixIcon: IconButton(
        tooltip: 'Pilih di peta',
        icon: const Icon(Icons.map_outlined),
        onPressed: () => _pilihLokasi(controller, label, untukAsal),
      ),
    ),
    validator: _validasiAlamat,
  );

  static String? _validasiAlamat(String? nilai) {
    final bersih = nilai?.trim() ?? '';
    if (bersih.isEmpty) return 'Alamat wajib diisi';
    if (bersih.length < 5) return 'Tulis alamat lebih jelas';
    return null;
  }

  Future<void> _pilihLokasi(
    TextEditingController controller,
    String judul,
    bool untukAsal,
  ) async {
    final hasil = await Navigator.of(context).push<HasilPilihLokasi>(
      MaterialPageRoute(
        builder: (_) => PemilihLokasiScreen(
          judul: judul,
          posisiAwal: untukAsal ? _posisiAsal : _posisiTujuan,
        ),
      ),
    );
    if (hasil == null || !mounted) return;
    controller.text = hasil.alamat;
    setState(() {
      if (untukAsal) {
        _posisiAsal = hasil.posisi;
      } else {
        _posisiTujuan = hasil.posisi;
      }
    });

    if (_posisiAsal == null || _posisiTujuan == null) return;
    setState(() => _sedangHitungRute = true);
    final kilometer = await JarakRuteOsrm.kilometer(
      _posisiAsal!,
      _posisiTujuan!,
    );
    if (!mounted) return;
    setState(() {
      _sedangHitungRute = false;
      if (kilometer != null) {
        _jarakController.text = tulisJarak(
          double.parse(kilometer.toStringAsFixed(1)),
        );
      }
    });
    if (kilometer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rute gagal dihitung. Isi jarak secara manual.'),
        ),
      );
    }
  }

  Future<void> _pilihFoto() async {
    setState(() => _sedangMemilihFoto = true);
    try {
      final pilihan = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (pilihan == null || !mounted) return;
      final isi = await pilihan.readAsBytes();
      if (!mounted) return;
      setState(() {
        _foto = isi;
        _namaFoto = pilihan.name;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto gagal dibuka. Coba foto lain.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sedangMemilihFoto = false);
    }
  }

  Future<void> _buatOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_kebersihan && _foto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih foto kondisi terlebih dahulu.')),
      );
      return;
    }

    setState(() => _sedangMengirim = true);
    try {
      final jarak = _pindahan ? bacaJarak(_jarakController.text) : null;
      final order = await ref.read(orderRepositoryProvider).buatOrderJalurA(
        serviceType: widget.serviceType,
        jarakKm: jarak,
        deskripsi: _catatanController.text.trim().isEmpty
            ? null
            : _catatanController.text.trim(),
        alamatJemput: _pindahan ? _asalController.text.trim() : null,
        alamatTujuan: _pindahan
            ? _tujuanController.text.trim()
            : _alamatController.text.trim(),
        latitudeJemput: _posisiAsal?.latitude,
        longitudeJemput: _posisiAsal?.longitude,
        latitudeTujuan: _posisiTujuan?.latitude,
        longitudeTujuan: _posisiTujuan?.longitude,
        jumlahRunnerDibutuhkan: _pindahan ? _jumlahRunner : 1,
        jenisKendaraan: _pindahan ? _jenisKendaraan : null,
        idempotencyKey: _idempotencyKey,
      );

      if (_kebersihan) {
        await ref.read(fotoBuktiRepositoryProvider).unggahFotoEstimasi(
          orderId: order.id,
          namaBerkas: _namaFoto!,
          isi: _foto!,
        );
      }

      if (!mounted) return;
      context.pushReplacement(Rute.detailOrder(order.id));
    } catch (galat) {
      if (!mounted) return;
      setState(() => _sedangMengirim = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            galat is GalatApi
                ? galat.pesan
                : 'Order atau foto gagal dikirim. Periksa sambungan lalu coba lagi.',
          ),
        ),
      );
    }
  }

}

/// Bilah bawah tombol aksi pemesanan layanan kos ala Gojek
class _BilahBawahGojekKos extends StatelessWidget {
  const _BilahBawahGojekKos({
    required this.total,
    this.labelTotal,
    this.labelAksi = 'Buat Order',
    required this.sedangMengirim,
    required this.onTekan,
    this.melebihiBatas = false,
  });

  final int? total;
  final String? labelTotal;
  final String labelAksi;
  final bool sedangMengirim;
  final VoidCallback? onTekan;
  final bool melebihiBatas;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: sedangMengirim ? null : onTekan,
              style: FilledButton.styleFrom(
                backgroundColor: melebihiBatas
                    ? const Color(0xFFC4C4C4)
                    : const Color(0xFF00AA13),
                disabledBackgroundColor: melebihiBatas
                    ? const Color(0xFFE2E2E2)
                    : const Color(0xFFB0D9B3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                elevation: 0,
              ),
              child: sedangMengirim
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              melebihiBatas ? 'Batas Layanan' : 'Total Biaya',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            Text(
                              total != null
                                  ? formatRupiah(total)
                                  : (labelTotal ?? '-'),
                              style: TextStyle(
                                fontSize: melebihiBatas ? 13.5 : 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              labelAksi,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              melebihiBatas
                                  ? Icons.block_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

