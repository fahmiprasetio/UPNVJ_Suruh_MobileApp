import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/enums.dart';
import '../../../../domain/models/order.dart';
import '../../../../domain/order_flow.dart';

/// Tahapan order digambar sebagai garis menurun.
///
/// Tahap yang ditampilkan mengikuti jalur ordernya, Jalur A hanya punya empat
/// tahap karena harganya sudah pasti sejak awal (rencana capstone bagian 4).
class LinimasaStatus extends StatelessWidget {
  const LinimasaStatus({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    if (order.dibatalkan) return const _OrderDibatalkan();

    final tahapan = order.alur;
    return Column(
      children: [
        for (var i = 0; i < tahapan.length; i++)
          _Tahap(
            status: tahapan[i],
            sudahLewat: order.sudahLewat(tahapan[i]),
            sedangDi: order.sedangDi(tahapan[i]),
            tahapTerakhir: i == tahapan.length - 1,
          ),
      ],
    );
  }
}

class _Tahap extends StatelessWidget {
  const _Tahap({
    required this.status,
    required this.sudahLewat,
    required this.sedangDi,
    required this.tahapTerakhir,
  });

  final OrderStatus status;
  final bool sudahLewat;
  final bool sedangDi;
  final bool tahapTerakhir;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final aktif = sudahLewat || sedangDi;
    final warna = aktif ? skema.primary : skema.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sudahLewat ? skema.primary : Colors.transparent,
                  border: Border.all(color: warna, width: 2),
                ),
                child: sudahLewat
                    ? Icon(Icons.check, size: 12, color: skema.onPrimary)
                    : null,
              ),
              if (!tahapTerakhir)
                Expanded(child: Container(width: 2, color: warna)),
            ],
          ),
          const SizedBox(width: AppTheme.spasiSedang),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: tahapTerakhir ? 0 : AppTheme.spasiSedang,
              ),
              child: Text(
                status.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: sedangDi ? FontWeight.w700 : FontWeight.w400,
                  color: aktif ? skema.onSurface : skema.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderDibatalkan extends StatelessWidget {
  const _OrderDibatalkan();

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.cancel_outlined, color: skema.error),
        const SizedBox(width: AppTheme.spasiSedang),
        Expanded(
          child: Text(
            'Order ini dibatalkan.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: skema.error),
          ),
        ),
      ],
    );
  }
}
