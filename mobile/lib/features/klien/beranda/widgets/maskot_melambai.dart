import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Maskot buaya yang diam bersandar, lalu sesekali melambai lewat sprite
/// sheet (satu gambar berisi seluruh frame lambaian, ditempel sebaris).
///
/// Kenapa sprite sheet, bukan berkas gambar terpisah per frame: satu gambar
/// cuma di-decode sekali lalu masuk cache Flutter, dan ganti frame sesudahnya
/// cuma menggambar potongan persegi berbeda dari gambar yang sama lewat
/// [Canvas.drawImageRect] -- tanpa decode ulang tiap ganti frame, jadi tidak
/// patah-patah di HP kelas bawah.
class MaskotMelambai extends StatefulWidget {
  const MaskotMelambai({
    super.key,
    required this.spriteSheet,
    required this.jumlahFrame,
    this.tinggi = 140,
    this.fps = 6,
    this.jedaMelambai = const Duration(seconds: 6),
  });

  /// Sprite sheet lambaian: [jumlahFrame] frame ditempel sebaris (horizontal),
  /// frame pertama adalah pose diam bersandar.
  final ImageProvider spriteSheet;

  final int jumlahFrame;
  final double tinggi;

  /// Kecepatan putar animasi lambaian.
  final int fps;

  /// Jeda diam di frame pertama sebelum satu putaran lambaian dimulai lagi.
  final Duration jedaMelambai;

  @override
  State<MaskotMelambai> createState() => _MaskotMelambaiState();
}

class _MaskotMelambaiState extends State<MaskotMelambai> {
  ui.Image? _gambar;
  ImageStream? _aliranGambar;
  late final ImageStreamListener _pendengar;
  int _frame = 0;
  Timer? _pewaktuJeda;
  Timer? _pewaktuFrame;

  @override
  void initState() {
    super.initState();
    _pendengar = ImageStreamListener(_saatGambarSiap);
    _jadwalkanLambaian();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _aliranGambar?.removeListener(_pendengar);
    _aliranGambar = widget.spriteSheet.resolve(
      createLocalImageConfiguration(context),
    );
    _aliranGambar!.addListener(_pendengar);
  }

  void _saatGambarSiap(ImageInfo info, bool synchronousCall) {
    setState(() => _gambar = info.image);
  }

  void _jadwalkanLambaian() {
    _pewaktuJeda = Timer(widget.jedaMelambai, _lambai);
  }

  void _lambai() {
    final jedaFrame = Duration(milliseconds: (1000 / widget.fps).round());
    var langkah = 0;
    _pewaktuFrame = Timer.periodic(jedaFrame, (pewaktu) {
      langkah++;
      if (langkah >= widget.jumlahFrame) {
        pewaktu.cancel();
        setState(() => _frame = 0);
        if (mounted) _jadwalkanLambaian();
        return;
      }
      setState(() => _frame = langkah);
    });
  }

  @override
  void dispose() {
    _pewaktuJeda?.cancel();
    _pewaktuFrame?.cancel();
    _aliranGambar?.removeListener(_pendengar);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gambar = _gambar;
    if (gambar == null) return SizedBox(height: widget.tinggi);

    final lebarFrameAsli = gambar.width / widget.jumlahFrame;
    final skala = widget.tinggi / gambar.height;

    return SizedBox(
      height: widget.tinggi,
      width: lebarFrameAsli * skala,
      child: CustomPaint(
        size: Size(lebarFrameAsli * skala, widget.tinggi),
        painter: _PelukisFrame(
          gambar: gambar,
          frame: _frame,
          lebarFrameAsli: lebarFrameAsli,
        ),
      ),
    );
  }
}

class _PelukisFrame extends CustomPainter {
  _PelukisFrame({
    required this.gambar,
    required this.frame,
    required this.lebarFrameAsli,
  });

  final ui.Image gambar;
  final int frame;
  final double lebarFrameAsli;

  @override
  void paint(Canvas canvas, Size size) {
    final sumber = Rect.fromLTWH(
      frame * lebarFrameAsli,
      0,
      lebarFrameAsli,
      gambar.height.toDouble(),
    );
    final tujuan = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(gambar, sumber, tujuan, Paint());
  }

  @override
  bool shouldRepaint(covariant _PelukisFrame oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.gambar != gambar;
}
