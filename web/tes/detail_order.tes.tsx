import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';

import { PenyediaSesi } from '../src/auth/sesi';
import { HalamanDetailOrder } from '../src/halaman/detail_order';
import { KlienApi } from '../src/inti/klien_api';
import type { Order } from '../src/inti/tipe';
import { buatTiruanHub } from './dukungan_hub';

/**
 * Panel pembatalan ini satu-satunya tempat di dashboard yang mengubah data lewat aksi
 * destruktif, jadi yang paling penting diuji: panelnya cuma muncul untuk order yang
 * memang layak dibatalkan lewat sini (sudah dibayar, belum berakhir), formnya menuntut
 * alasan sebelum tombol kirim aktif, dan permintaan yang berangkat membawa alasan itu ke
 * endpoint admin yang benar — bukan endpoint batal biasa yang dipakai klien.
 */

function order(ubah: Partial<Order> = {}): Order {
  return {
    id: '66666666-6666-6666-6666-666666666666',
    kodeOrder: 'SRH-042',
    serviceType: 'AnterJemput',
    track: 'JalurA',
    status: 'MencariRunner',
    klienId: '33333333-3333-3333-3333-333333333333',
    namaKlien: 'Sinta',
    harga: 30000,
    hargaUsulan: null,
    deskripsi: null,
    alamatJemput: null,
    alamatTujuan: null,
    jarakKm: null,
    jumlahRunnerDibutuhkan: 1,
    runnerIds: [],
    estimasiDurasiMenit: null,
    jadwalMulai: null,
    fotoBuktiUrl: null,
    catatanSerahTerima: null,
    penawaran: [],
    jumlahPesan: 0,
    dibuatPada: new Date().toISOString(),
    dibayarPada: null,
    selesaiPada: null,
    ...ubah,
  };
}

function jawaban(status: number, badan: unknown): Response {
  return new Response(JSON.stringify(badan), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function halamanPesanKosong() {
  return { isi: [], total: 0, halaman: 1, ukuranHalaman: 50, totalHalaman: 0 };
}

function pasang(ambil: ReturnType<typeof vi.fn>, id = order().id) {
  const buatKlien = (bacaToken: () => string | null) =>
    new KlienApi(bacaToken, 'http://uji', ambil as unknown as typeof fetch);

  return render(
    <MemoryRouter initialEntries={[`/order/${id}`]}>
      <PenyediaSesi buatKlien={buatKlien} buatHub={buatTiruanHub}>
        <Routes>
          <Route path="/order/:id" element={<HalamanDetailOrder />} />
        </Routes>
      </PenyediaSesi>
    </MemoryRouter>,
  );
}

describe('PanelPembatalan', () => {
  it('tidak muncul untuk order yang belum dibayar', async () => {
    const ambil = vi.fn().mockImplementation((url: string) =>
      Promise.resolve(
        url.includes('/pesan') ? jawaban(200, halamanPesanKosong()) : jawaban(200, order({ dibayarPada: null })),
      ),
    );
    pasang(ambil);

    expect(await screen.findByText('SRH-042')).toBeInTheDocument();
    expect(screen.queryByText('Batalkan & kembalikan dana')).not.toBeInTheDocument();
  });

  it('tidak muncul untuk order yang sudah berakhir', async () => {
    const ambil = vi.fn().mockImplementation((url: string) =>
      Promise.resolve(
        url.includes('/pesan')
          ? jawaban(200, halamanPesanKosong())
          : jawaban(200, order({ status: 'Batal', dibayarPada: new Date().toISOString() })),
      ),
    );
    pasang(ambil);

    expect(await screen.findByText('SRH-042')).toBeInTheDocument();
    expect(screen.queryByText('Batalkan & kembalikan dana')).not.toBeInTheDocument();
  });

  it('muncul untuk order aktif yang sudah dibayar', async () => {
    const ambil = vi.fn().mockImplementation((url: string) =>
      Promise.resolve(
        url.includes('/pesan')
          ? jawaban(200, halamanPesanKosong())
          : jawaban(200, order({ status: 'Dikerjakan', dibayarPada: new Date().toISOString() })),
      ),
    );
    pasang(ambil);

    expect(await screen.findByText('Batalkan & kembalikan dana')).toBeInTheDocument();
  });

  it('tidak mengizinkan kirim tanpa alasan', async () => {
    const ambil = vi.fn().mockImplementation((url: string) =>
      Promise.resolve(
        url.includes('/pesan')
          ? jawaban(200, halamanPesanKosong())
          : jawaban(200, order({ status: 'Dikerjakan', dibayarPada: new Date().toISOString() })),
      ),
    );
    pasang(ambil);

    fireEvent.click(await screen.findByRole('button', { name: 'Batalkan order ini' }));

    const tombolKirim = await screen.findByRole('button', {
      name: 'Ya, batalkan dan catat pengembalian',
    });
    expect(tombolKirim).toBeDisabled();

    fireEvent.change(screen.getByLabelText('Alasan pembatalan'), {
      target: { value: 'Klien komplain barang rusak.' },
    });
    expect(tombolKirim).toBeEnabled();
  });

  it('mengirim alasan ke endpoint admin, bukan endpoint batal klien', async () => {
    const permintaan: { url: string; init?: RequestInit }[] = [];
    const orderDibayar = order({ status: 'Dikerjakan', dibayarPada: new Date().toISOString() });
    let sudahDibatalkan = false;

    const ambil = vi.fn().mockImplementation((url: string, init?: RequestInit) => {
      permintaan.push({ url, init });
      if (url.includes('/pesan')) return Promise.resolve(jawaban(200, halamanPesanKosong()));
      if (init?.method === 'POST' && url.includes('/batalkan')) {
        sudahDibatalkan = true;
        return Promise.resolve(jawaban(200, { ...orderDibayar, status: 'Batal' }));
      }
      // Pengambilan ulang order sesudah dibatalkan (dipicu onDibatalkan -> muatUlang) harus
      // menampilkan statusnya yang baru, sama seperti server sungguhan akan menjawabnya.
      return Promise.resolve(
        jawaban(200, sudahDibatalkan ? { ...orderDibayar, status: 'Batal' } : orderDibayar),
      );
    });

    pasang(ambil);

    fireEvent.click(await screen.findByRole('button', { name: 'Batalkan order ini' }));
    fireEvent.change(await screen.findByLabelText('Alasan pembatalan'), {
      target: { value: 'Klien komplain barang rusak.' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Ya, batalkan dan catat pengembalian' }));

    await waitFor(() => {
      expect(permintaan.some((p) => p.url.includes('/batalkan'))).toBe(true);
    });

    const permintaanBatal = permintaan.find((p) => p.url.includes('/batalkan'));
    expect(permintaanBatal?.url).toBe(`http://uji/api/admin/orders/${orderDibayar.id}/batalkan`);
    expect(permintaanBatal?.init?.method).toBe('POST');

    const badan = JSON.parse(permintaanBatal?.init?.body as string) as { alasan: string };
    expect(badan.alasan).toBe('Klien komplain barang rusak.');

    // Panel menghilang begitu ordernya kembali dimuat dengan status Batal.
    await waitFor(() => {
      expect(screen.queryByText('Batalkan & kembalikan dana')).not.toBeInTheDocument();
    });
  });

  it('menampilkan galat server tanpa menutup formnya', async () => {
    const orderDibayar = order({ status: 'Dikerjakan', dibayarPada: new Date().toISOString() });

    const ambil = vi.fn().mockImplementation((url: string, init?: RequestInit) => {
      if (url.includes('/pesan')) return Promise.resolve(jawaban(200, halamanPesanKosong()));
      if (init?.method === 'POST' && url.includes('/batalkan')) {
        return Promise.resolve(jawaban(400, { title: 'Order ini belum dibayar' }));
      }
      return Promise.resolve(jawaban(200, orderDibayar));
    });

    pasang(ambil);

    fireEvent.click(await screen.findByRole('button', { name: 'Batalkan order ini' }));
    fireEvent.change(await screen.findByLabelText('Alasan pembatalan'), {
      target: { value: 'Klien komplain barang rusak.' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Ya, batalkan dan catat pengembalian' }));

    expect(await screen.findByText('Order ini belum dibayar')).toBeInTheDocument();
    // Formnya tetap terbuka, alasan yang sudah diketik tidak hilang.
    expect(screen.getByLabelText('Alasan pembatalan')).toHaveValue('Klien komplain barang rusak.');
  });
});
