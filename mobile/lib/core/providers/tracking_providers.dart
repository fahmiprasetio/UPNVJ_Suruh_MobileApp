import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/lokasi_runner.dart';
import 'repository_providers.dart';

final lokasiRunnerProvider = StreamProvider.autoDispose
    .family<LokasiRunner?, String>((ref, orderId) {
      final repository = ref.watch(trackingRepositoryProvider);
      return repository?.pantau(orderId) ?? Stream.value(null);
    });
