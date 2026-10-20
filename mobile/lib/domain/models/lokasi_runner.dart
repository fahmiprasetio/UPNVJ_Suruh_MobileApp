import 'package:flutter/foundation.dart';

@immutable
class LokasiRunner {
  const LokasiRunner({
    required this.orderId,
    required this.runnerId,
    required this.latitude,
    required this.longitude,
    required this.direkamPada,
    required this.diterimaPada,
    this.akurasiMeter,
    this.arahDerajat,
    this.kecepatanMeterPerDetik,
  });

  final String orderId;
  final String runnerId;
  final double latitude;
  final double longitude;
  final double? akurasiMeter;
  final double? arahDerajat;
  final double? kecepatanMeterPerDetik;
  final DateTime direkamPada;
  final DateTime diterimaPada;

  factory LokasiRunner.dariJson(Map<String, dynamic> json) => LokasiRunner(
    orderId: json['orderId'] as String,
    runnerId: json['runnerId'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    akurasiMeter: (json['akurasiMeter'] as num?)?.toDouble(),
    arahDerajat: (json['arahDerajat'] as num?)?.toDouble(),
    kecepatanMeterPerDetik: (json['kecepatanMeterPerDetik'] as num?)
        ?.toDouble(),
    direkamPada: DateTime.parse(json['direkamPada'] as String).toLocal(),
    diterimaPada: DateTime.parse(json['diterimaPada'] as String).toLocal(),
  );
}
