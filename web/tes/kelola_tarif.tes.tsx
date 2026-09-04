import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';

import { PenyediaSesi } from '../src/auth/sesi';
import { HalamanKelolaTarif } from '../src/halaman/kelola_tarif';
import { KlienApi } from '../src/inti/klien_api';
import type { Tarif } from '../src/inti/tipe';
import { buatTiruanHub } from './dukungan_hub';

/**
 * Yang paling penting diuji di sini: form dimuat dari angka yang sedang berlaku (bukan
 * kosong), dan yang dikirim ke server saat disimpan persis apa yang tercantum di form
 * (tujuh angka sekaligus, sesuai `PerbaruiTarifRequest` di backend), bukan diam-diam
 * membiarkan salah satu kolom terbawa nilai lama.
 */

function tarif(ubah: Partial<Tarif> = {}): Tarif {
  return {
    anjemTarifDasar: 5000,
    anjemTarifPerKm: 2000,
    anjemJarakMinimalKm: 0.5,
    anjemJarakMaksimalKm: 15,
    jastipMakananFee: 8000,
    jastipBarangFee: 10000,
    jastipBarangTarifPerKm: 2000,
    diubahPada: null,
    ...ubah,
  };
}

function jawaban(status: number, badan: unknown): Response {
  return new Response(JSON.stringify(badan), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function pasang(ambil: ReturnType<typeof vi.fn>) {
  const buatKlien = (bacaToken: () => string | null) =>
    new KlienApi(bacaToken, 'http://uji', ambil as unknown as typeof fetch);

  return render(
    <MemoryRouter>
      <PenyediaSesi buatKlien={buatKlien} buatHub={buatTiruanHub}>
        <HalamanKelolaTarif />
      </PenyediaSesi>
    </MemoryRouter>,
  );
}

describe('HalamanKelolaTarif', () => {
  it('memuat form dengan angka yang sedang berlaku, bukan kosong', async () => {
    const ambil = vi.fn().mockResolvedValue(jawaban(200, tarif({ anjemTarifDasar: 5000 })));
    pasang(ambil);

    const kolom = await screen.findByLabelText('Tarif dasar (Rp)');
    expect(kolom).toHaveValue(5000);
  });

  it('menyebut bahwa order lama tidak ikut berubah', async () => {
    const ambil = vi.fn().mockResolvedValue(jawaban(200, tarif()));
    pasang(ambil);

    expect(
      await screen.findByText(
        'Cuma Jalur A: anter jemput, jastip makanan, jastip barang. Harga Jalur B lewat tawar-menawar langsung antara klien dan runner, tidak diatur dari sini.',
      ),
    ).toBeInTheDocument();
  });

  it('mengirim persis tujuh angka di form, termasuk yang baru diketik', async () => {
    const permintaan: { url: string; init?: RequestInit }[] = [];
    const ambil = vi.fn().mockImplementation((url: string, init?: RequestInit) => {
      permintaan.push({ url, init });
      if (init?.method === 'PUT') {
        return Promise.resolve(
          jawaban(200, tarif({ anjemTarifDasar: 7000, diubahPada: '2026-09-02T10:00:00Z' })),
        );
      }
      return Promise.resolve(jawaban(200, tarif()));
    });

    pasang(ambil);

    const kolomDasar = await screen.findByLabelText('Tarif dasar (Rp)');
    fireEvent.change(kolomDasar, { target: { value: '7000' } });
    fireEvent.click(screen.getByRole('button', { name: 'Simpan tarif' }));

    await waitFor(() => {
      expect(permintaan.some((p) => p.init?.method === 'PUT')).toBe(true);
    });

    const permintaanPut = permintaan.find((p) => p.init?.method === 'PUT');
    expect(permintaanPut?.url).toBe('http://uji/api/tarif');

    const badan = JSON.parse(permintaanPut?.init?.body as string) as Record<string, unknown>;
    expect(badan).toEqual({
      anjemTarifDasar: 7000,
      anjemTarifPerKm: 2000,
      anjemJarakMinimalKm: 0.5,
      anjemJarakMaksimalKm: 15,
      jastipMakananFee: 8000,
      jastipBarangFee: 10000,
      jastipBarangTarifPerKm: 2000,
    });
    // `diubahPada` tidak ikut terkirim: itu bukan sesuatu yang admin tentukan, server yang
    // mengisinya sendiri saat menyimpan.
    expect(badan).not.toHaveProperty('diubahPada');
  });

  it('menampilkan kabar berhasil sesudah tersimpan', async () => {
    const ambil = vi.fn().mockImplementation((_url: string, init?: RequestInit) => {
      if (init?.method === 'PUT') {
        return Promise.resolve(jawaban(200, tarif({ diubahPada: '2026-09-02T10:00:00Z' })));
      }
      return Promise.resolve(jawaban(200, tarif()));
    });

    pasang(ambil);

    fireEvent.click(await screen.findByRole('button', { name: 'Simpan tarif' }));

    expect(
      await screen.findByText(
        'Tersimpan. Order Jalur A berikutnya memakai tarif ini; order yang sudah ada tidak berubah.',
      ),
    ).toBeInTheDocument();
  });

  it('menampilkan galat validasi dari server tanpa kehilangan isian', async () => {
    const ambil = vi.fn().mockImplementation((_url: string, init?: RequestInit) => {
      if (init?.method === 'PUT') {
        return Promise.resolve(
          jawaban(400, { title: 'Jarak minimal harus lebih kecil dari jarak maksimal.' }),
        );
      }
      return Promise.resolve(jawaban(200, tarif()));
    });

    pasang(ambil);

    const kolomDasar = await screen.findByLabelText('Tarif dasar (Rp)');
    fireEvent.change(kolomDasar, { target: { value: '9999' } });
    fireEvent.click(screen.getByRole('button', { name: 'Simpan tarif' }));

    expect(
      await screen.findByText('Jarak minimal harus lebih kecil dari jarak maksimal.'),
    ).toBeInTheDocument();
    expect(kolomDasar).toHaveValue(9999);
  });
});
