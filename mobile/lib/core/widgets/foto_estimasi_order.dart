import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/order.dart';
import '../providers/repository_providers.dart';

class FotoEstimasiOrder extends ConsumerWidget {
  const FotoEstimasiOrder({super.key, required this.order, this.height = 180});

  final Order order;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = order.fotoEstimasiUrl;
    if (url == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foto kondisi dari klien',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: url.startsWith('http://') || url.startsWith('https://')
              ? Image.network(
                  url,
                  headers: ref.watch(klienApiProvider).headerOtorisasi,
                  height: height,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _galat(context),
                )
              : _galat(context),
        ),
      ],
    );
  }

  Widget _galat(BuildContext context) => Container(
    height: height,
    width: double.infinity,
    alignment: Alignment.center,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Text('Foto kondisi tidak dapat dimuat.'),
  );
}
