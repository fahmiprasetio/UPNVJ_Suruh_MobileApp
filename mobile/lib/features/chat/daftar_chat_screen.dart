import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/galat_api.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/format/formatters.dart';
import '../../domain/models/order.dart';
import '../../domain/service_catalog.dart';
import '../../providers/order_providers.dart';
import '../../providers/ukuran_daftar.dart';
import '../widgets/pesan_kosong.dart';
import '../widgets/rangka_daftar_order.dart';
import '../widgets/tombol_muat_lagi.dart';

/// Daftar percakapan klien, satu baris per order yang pernah dibicarakan.
///
/// Bukan ruang obrolan bebas -- tidak ada satu pun di sini yang berdiri
/// sendiri tanpa order (rencana capstone bagian 4). Layar ini cuma pintu
/// masuk kedua ke [ChatOrderScreen] yang sama; obrolan Jalur B yang masih
/// menerima beberapa tawaran sekaligus tetap dibuka lewat kartu penawarannya
/// sendiri di detail order, karena di situlah runner mana yang mau dibuka
/// jalurnya diketahui.
///
/// ## Kenapa tanpa cuplikan pesan terakhir
///
/// Daftar order tidak membawa isi percakapannya, cuma jumlah pesan dan berapa
/// yang belum dibaca (lihat [Order.jumlahPesan]) -- keputusan yang sama yang
/// menahan `KartuOrderRingkas` dari menampilkan cuplikan. Menampilkan cuplikan
/// sungguhan berarti tiap order di sini harus dimuat detailnya satu-satu,
/// dan biayanya tumbuh persis saat aplikasi ini mulai ramai dipakai.
class DaftarChatScreen extends ConsumerStatefulWidget {
  const DaftarChatScreen({super.key});

  @override
  ConsumerState<DaftarChatScreen> createState() => _DaftarChatScreenState();
}

class _DaftarChatScreenState extends ConsumerState<DaftarChatScreen> {
  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(orderKlienProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: orders.when(
        skipLoadingOnReload: true,
        loading: () => const RangkaDaftarOrder(),
        error: (galat, _) => PesanKosong(
          ikon: Icons.wifi_off_outlined,
          judul: 'Chat gagal dimuat',
          keterangan: galat is GalatApi
              ? galat.pesan
              : 'Sambungan ke server terputus.',
          labelAksi: 'Coba lagi',
          onAksi: () => ref.invalidate(orderKlienProvider),
        ),
        data: (halaman) {
          // Cuma order yang pernah punya percakapan. Order yang belum dibalas
          // siapa pun tidak layak jadi baris chat kosong di sini -- ia sudah
          // punya tempatnya sendiri di tab Pesanan.
          final berpercakapan = halaman.isi
              .where((o) => o.jumlahPesan > 0)
              .toList()
            // Belum dibaca dulu, lalu yang terbaru. Daftar order tidak membawa
            // waktu pesan terakhir (lihat catatan kelas), jadi tanggal order
            // sendiri dipakai sebagai urutan yang paling dekat dengan itu.
            ..sort((a, b) {
              final belumDibacaA = a.jumlahPesanBelumDibaca > 0;
              final belumDibacaB = b.jumlahPesanBelumDibaca > 0;
              if (belumDibacaA != belumDibacaB) {
                return belumDibacaA ? -1 : 1;
              }
              return b.dibuatPada.compareTo(a.dibuatPada);
            });

          if (berpercakapan.isEmpty) {
            return const PesanKosong(
              ikon: Icons.forum_outlined,
              judul: 'Belum ada percakapan',
              keterangan:
                  'Chat yang menempel pada orderanmu muncul di sini begitu '
                  'ada yang menulis.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spasiKecil),
            itemCount: berpercakapan.length + 1,
            separatorBuilder: (context, indeks) => const Divider(height: 1),
            itemBuilder: (context, indeks) {
              if (indeks == berpercakapan.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spasiSedang,
                  ),
                  child: TombolMuatLagi(
                    halaman: halaman,
                    ukuranProvider: ukuranOrderKlienProvider,
                  ),
                );
              }
              return _BarisChat(order: berpercakapan[indeks]);
            },
          );
        },
      ),
    );
  }
}

class _BarisChat extends StatelessWidget {
  const _BarisChat({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final layanan = serviceInfoOf(order.serviceType);
    final belumDibaca = order.jumlahPesanBelumDibaca;

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: skema.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(layanan.icon, size: 20, color: skema.onPrimaryContainer),
      ),
      title: Text(
        layanan.nama,
        style: TextStyle(
          fontWeight: belumDibaca > 0 ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${order.kodeOrder} · ${formatWaktuRelatif(order.dibuatPada)}',
      ),
      trailing: belumDibaca > 0 ? Badge.count(count: belumDibaca) : null,
      onTap: () => context.push(Rute.chatOrder(order.id)),
    );
  }
}
