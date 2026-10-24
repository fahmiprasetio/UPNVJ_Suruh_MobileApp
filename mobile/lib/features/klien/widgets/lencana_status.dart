import 'package:flutter/material.dart';

import '../../../domain/enums.dart';

/// Lencana status order modern ala Gojek Aloha dengan pil warna lembut,
/// border penegas, dan ikon status kontekstual.
class LencanaStatus extends StatelessWidget {
  const LencanaStatus({super.key, required this.status, this.compact = false});

  final OrderStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = _styleStatus(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 2.5 : 3.5,
      ),
      decoration: BoxDecoration(
        color: style.latar,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: style.garis, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (style.ikon != null) ...[
            Icon(style.ikon, size: compact ? 11 : 12.5, color: style.teks),
            SizedBox(width: compact ? 3 : 4),
          ],
          Text(
            status.label,
            style: TextStyle(
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              color: style.teks,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  static ({Color latar, Color teks, Color garis, IconData? ikon}) _styleStatus(
    OrderStatus status,
  ) {
    switch (status) {
      case OrderStatus.mencariRunner:
        return (
          latar: const Color(0xFFE8F8EA),
          teks: const Color(0xFF00880C),
          garis: const Color(0xFFC6F6D5),
          ikon: Icons.radar_rounded,
        );
      case OrderStatus.dikerjakan:
        return (
          latar: const Color(0xFF00AA13),
          teks: Colors.white,
          garis: const Color(0xFF00AA13),
          ikon: Icons.directions_bike_rounded,
        );
      case OrderStatus.menungguPembayaran:
        return (
          latar: const Color(0xFFFFFBEB),
          teks: const Color(0xFFB45309),
          garis: const Color(0xFFFDE68A),
          ikon: Icons.payment_rounded,
        );
      case OrderStatus.menungguPersetujuanKlien:
        return (
          latar: const Color(0xFFEFF6FF),
          teks: const Color(0xFF1D4ED8),
          garis: const Color(0xFFBFDBFE),
          ikon: Icons.pending_actions_rounded,
        );
      case OrderStatus.permintaan:
        return (
          latar: const Color(0xFFF1F5F9),
          teks: const Color(0xFF475569),
          garis: const Color(0xFFE2E8F0),
          ikon: Icons.hourglass_top_rounded,
        );
      case OrderStatus.selesai:
        return (
          latar: const Color(0xFFF3F4F6),
          teks: const Color(0xFF374151),
          garis: const Color(0xFFE5E7EB),
          ikon: Icons.check_circle_rounded,
        );
      case OrderStatus.batal:
        return (
          latar: const Color(0xFFFEF2F2),
          teks: const Color(0xFFDC2626),
          garis: const Color(0xFFFECACA),
          ikon: Icons.cancel_rounded,
        );
    }
  }
}
