import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';

import { PenyediaSesi } from '../src/auth/sesi';
import { AMBANG_MACET_MENIT, HalamanPantauanOrder, sedangMacet } from '../src/halaman/pantauan_order';
import { KlienApi } from '../src/inti/klien_api';
import type { Halaman, Order, StatusOrder } from '../src/inti/tipe';
import { buatKendaliHub, buatTiruanHub } from './dukungan_hub';

function order(ubah: Partial<Order> = {}): Order {
  return {
    id: '22222222-2222-2222-2222-222222222222',
    kodeOrder: 'SRH-001',
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
    mintaBatalPada: null,
    ...ubah,
  };
}

function menitLalu(menit: number): string {
  return new Date(Date.now() - menit * 60_000).toISOString();
}

describe('sedangMacet', () => {
  it('menandai order yang sudah dibayar tapi belum diambil siapa pun', () => {
    // Keadaan terburuk yang bisa dialami sistem ini: uangnya sudah masuk, pekerjaannya
    // belum dimulai, kliennya menunggu.
    const macet = order({ status: 'MencariRunner', dibuatPada: menitLalu(AMBANG_MACET_MENIT) });
    expect(sedangMacet(macet)).toBe(true);
  });

  it('menandai permintaan Jalur B yang belum ditawar siapa pun', () => {
    const macet = order({ status: 'Permintaan', track: 'JalurB', dibuatPada: menitLalu(30) });
    expect(sedangMacet(macet)).toBe(true);
  });

  it('membiarkan order yang baru masuk', () => {
    expect(sedangMacet(order({ dibuatPada: menitLalu(1) }))).toBe(false);
  });

  it('tidak menandai order yang menunggu klien membayar', () => {
    // Yang ditunggu di sana klien, bukan organisasi. Menandainya macet berarti menyuruh
    // admin mengejar sesuatu yang memang bukan urusannya.
    const menunggu = order({ status: 'MenungguPembayaran', dibuatPada: menitLalu(120) });
    expect(sedangMacet(menunggu)).toBe(false);
  });

  it('tidak menandai order yang sudah berakhir', () => {
    const status: StatusOrder[] = ['Selesai', 'Batal', 'Dikerjakan'];
    for (const s of status) {
      expect(sedangMacet(order({ status: s, dibuatPada: menitLalu(600) }))).toBe(false);
    }
  });
});

function pasang(isi: Order[], total = isi.length, buatHub = buatTiruanHub) {
  const halaman: Halaman<Order> = {
    isi,
    total,
    halaman: 1,
    ukuranHalaman: 20,
    totalHalaman: Math.max(Math.ceil(total / 20), 1),
  };

  const ambil = vi.fn().mockResolvedValue(
    new Response(JSON.stringify(halaman), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    }),
  );

  const buatKlien = (bacaToken: () => string | null) =>
    new KlienApi(bacaToken, 'http://uji', ambil as unknown as typeof fetch);

  render(
    <MemoryRouter>
      <PenyediaSesi buatKlien={buatKlien} buatHub={buatHub}>
        <HalamanPantauanOrder />
      </PenyediaSesi>
    </MemoryRouter>,
  );

  return ambil;
}

describe('HalamanPantauanOrder', () => {
  it('membedakan daftar kosong dari daftar yang gagal dimuat', async () => {
    // Tabel tanpa baris tidak bisa dibedakan dari daftar yang gagal, dan admin akan
    // menunggu sesuatu yang tidak akan pernah muncul.
    pasang([]);
    expect(
      await screen.findByText('Tidak ada order yang cocok dengan penyaring ini.'),
    ).toBeInTheDocument();
  });

  it('menampilkan harga usulan klien sebagai angka yang belum disepakati', async () => {
    pasang([
      order({
        track: 'JalurB',
        status: 'Permintaan',
        serviceType: 'BersihKos',
        harga: null,
        hargaUsulan: 50000,
      }),
    ]);

    const angka = await screen.findByTitle('Harga usulan klien, belum disepakati');
    expect(angka.tagName).toBe('EM');
    expect(angka).toHaveTextContent('50.000');
  });

  it('menyebut total dari server, bukan cuma yang muat di halaman ini', async () => {
    // "Menunggu penawaran: 20" yang ternyata cuma isi satu halaman adalah kabar yang
    // menyesatkan justru ketika antreannya sedang menumpuk.
    pasang([order()], 137);
    expect(await screen.findByText('137 order')).toBeInTheDocument();
  });

  it('menandai baris order yang menganggur terlalu lama', async () => {
    pasang([order({ dibuatPada: menitLalu(45) })]);

    const baris = (await screen.findByText('SRH-001')).closest('tr');
    expect(baris).not.toBeNull();
    expect(within(baris as HTMLElement).getByText('macet')).toBeInTheDocument();
  });

  it('memuat ulang begitu hub mengabarkan ada order yang berubah', async () => {
    // Jaring penyegar tambahan di atas pengambilan berkala 15 detik: begitu ada kabar
    // dari hub, layar ini harus menanyakan ulang daftarnya tanpa menunggu jeda itu habis.
    const { hub, picu } = buatKendaliHub();
    const ambil = pasang([order()], 1, () => hub);

    await screen.findByText('SRH-001');
    expect(ambil).toHaveBeenCalledTimes(1);

    act(() => picu());

    await waitFor(() => expect(ambil).toHaveBeenCalledTimes(2));
  });

  /**
   * Satu-satunya antrean di dashboard yang isinya menuntut jawaban, bukan sekadar ditonton.
   * Tanpa penanda dan penyaringnya, admin harus memindai seluruh daftar order untuk
   * menemukan yang mana yang sedang bertanya.
   */
  it('menandai baris order yang sedang meminta dibatalkan', async () => {
    pasang([order({ mintaBatalPada: menitLalu(3) })]);

    const baris = (await screen.findByText('SRH-001')).closest('tr');
    expect(baris).not.toBeNull();
    expect(within(baris as HTMLElement).getByText('minta batal')).toBeInTheDocument();
  });

  it('baris biasa tidak ikut ditandai', async () => {
    pasang([order()]);

    const baris = (await screen.findByText('SRH-001')).closest('tr');
    expect(within(baris as HTMLElement).queryByText('minta batal')).not.toBeInTheDocument();
  });

  it('penyaring antrean pembatalan ikut terkirim ke server', async () => {
    const ambil = pasang([order()]);
    await screen.findByText('SRH-001');

    fireEvent.click(screen.getByRole('button', { name: 'Minta dibatalkan' }));

    await waitFor(() => {
      const terakhir = String(ambil.mock.calls.at(-1)![0]);
      expect(terakhir).toContain('mintaBatal=true');
    });
  });

  /// Penyaring yang mati tidak boleh terkirim sebagai "false" yang harus ditafsirkan server.
  it('penyaring yang mati tidak ikut terkirim sama sekali', async () => {
    const ambil = pasang([order()]);
    await screen.findByText('SRH-001');

    expect(String(ambil.mock.calls.at(-1)![0])).not.toContain('mintaBatal');
  });
});
