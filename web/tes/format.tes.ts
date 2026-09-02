import { describe, expect, it } from 'vitest';

import {
  formatDurasi,
  formatRupiah,
  formatWaktuRelatif,
  labelStatus,
  menitSejak,
} from '../src/inti/format';

describe('formatRupiah', () => {
  it('menulis harga yang belum ada sebagai tanda hubung, bukan Rp 0', () => {
    // Bedanya bukan gaya. Harga Jalur B memang belum ada sebelum satu penawaran
    // disetujui, dan "Rp 0" di kolom harga terbaca sebagai gratis.
    expect(formatRupiah(null)).toBe('-');
    expect(formatRupiah(undefined)).toBe('-');
  });

  it('memberi pemisah ribuan tanpa angka di belakang koma', () => {
    expect(formatRupiah(30000)).toContain('30.000');
    expect(formatRupiah(30000)).not.toContain(',00');
  });
});

describe('formatWaktuRelatif', () => {
  const sekarang = new Date('2026-09-02T10:00:00Z');

  it('menyebut menit, jam, lalu hari sesuai jauhnya', () => {
    expect(formatWaktuRelatif('2026-09-02T09:48:00Z', sekarang)).toBe('12 menit lalu');
    expect(formatWaktuRelatif('2026-09-02T07:00:00Z', sekarang)).toBe('3 jam lalu');
    expect(formatWaktuRelatif('2026-08-31T10:00:00Z', sekarang)).toBe('2 hari lalu');
  });

  it('menyebut "baru saja" untuk yang belum genap semenit', () => {
    expect(formatWaktuRelatif('2026-09-02T09:59:30Z', sekarang)).toBe('baru saja');
  });

  it('membaca waktu tanpa penanda zona sebagai UTC, bukan waktu setempat', () => {
    // Ini bug yang paling mahal di layar pantauan kalau salah: backend mengirim waktu
    // UTC dan tidak selalu menempelkan Z. Dibaca sebagai waktu setempat, order yang baru
    // saja masuk tampak masuk tujuh jam lalu, dan seluruh penandaan macet jadi omong
    // kosong. Dua bentuk di bawah ini harus dibaca sebagai saat yang sama persis.
    expect(formatWaktuRelatif('2026-09-02T09:48:00', sekarang)).toBe(
      formatWaktuRelatif('2026-09-02T09:48:00Z', sekarang),
    );
  });
});

describe('menitSejak', () => {
  it('menghitung selisih dalam menit penuh', () => {
    const sekarang = new Date('2026-09-02T10:00:00Z');
    expect(menitSejak('2026-09-02T09:49:30Z', sekarang)).toBe(10);
  });
});

describe('formatDurasi', () => {
  it('menyembunyikan bagian yang nol', () => {
    expect(formatDurasi(45)).toBe('45 menit');
    expect(formatDurasi(120)).toBe('2 jam');
    expect(formatDurasi(150)).toBe('2 jam 30 menit');
  });
});

describe('labelStatus', () => {
  it('tetap punya kalimat untuk status yang tidak lagi diproduksi backend', () => {
    // Baris lama di basis data masih menyandangnya, dan status tanpa label akan muncul
    // sebagai nama enum mentah persis di layar yang gunanya menelusuri order bermasalah.
    expect(labelStatus('MenungguPersetujuanKlien')).toBe('Menunggu Jawaban Klien');
  });

  it('memakai kata yang sama dengan aplikasi mobile', () => {
    expect(labelStatus('MencariRunner')).toBe('Mencari Runner');
  });
});
