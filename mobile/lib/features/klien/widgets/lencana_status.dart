import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/enums.dart';

/// Lencana kecil bertuliskan status order.
class LencanaStatus extends StatelessWidget {
  const LencanaStatus({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.warnaLatar(skema),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: status.warnaTeks(skema),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
