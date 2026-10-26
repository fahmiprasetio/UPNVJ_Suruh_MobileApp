import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/lokasi_runner.dart';
import 'repository_providers.dart';

final lokasiRunnerProvider = StreamProvider.autoDispose
    .family<LokasiRunner?, String>((ref, orderId) {
      final repository = ref.watch(trackingRepositoryProvider);
      return repository?.pantau(orderId) ?? Stream.value(null);
    });

/// Tahap pelacakan rute perjalanan untuk layanan yang memiliki rute (Anter Jemput / Jastip).
enum TahapTrackingOrder {
  /// Tahap 1: Runner sedang dalam perjalanan menuju lokasi jemput klien / warung.
  /// Rute live tracking hijau: Runner ➔ Titik Jemput.
  menujuJemput,

  /// Tahap 2: Runner sudah sampai di titik jemput & menekan "Mulai Antar".
  /// Rute live tracking hijau: Runner & Klien ➔ Titik Tujuan.
  sedangAntar,
}

class TahapTrackingState extends Notifier<Map<String, TahapTrackingOrder>> {
  @override
  Map<String, TahapTrackingOrder> build() => const {};

  TahapTrackingOrder untuk(String orderId) =>
      state[orderId] ?? TahapTrackingOrder.menujuJemput;

  void mulaiAntar(String orderId) {
    state = {...state, orderId: TahapTrackingOrder.sedangAntar};
  }

  void kembaliKeJemput(String orderId) {
    state = {...state, orderId: TahapTrackingOrder.menujuJemput};
  }
}

final tahapTrackingProvider =
    NotifierProvider<TahapTrackingState, Map<String, TahapTrackingOrder>>(
      TahapTrackingState.new,
    );
