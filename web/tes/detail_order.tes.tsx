import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';

import { PenyediaSesi } from '../src/auth/sesi';
import { HalamanDetailOrder } from '../src/halaman/detail_order';
import { KlienApi } from '../src/inti/klien_api';
import type { Order, PerubahanStatusOrder } from '../src/inti/tipe';
import { buatKendaliHub, buatTiruanHub } from './dukungan_hub';

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
    mintaBatalPada: null,
    macet: false,
    ...ubah,
  };
}

function jawaban(status: number, badan: unknown): Response {
  return new Response(JSON.stringify(badan), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

/**
 * Jawaban untuk order, KECUALI kalau url yang diminta justru riwayat statusnya --
 * `RiwayatStatus` di layar ini mengambilnya sendiri lewat url yang berbeda, dan setiap
 * tiruan pengambilan di berkas ini perlu menjawabnya juga, bukan cuma pesannya.
 */
function jawabanOrder(url: string, order: Order): Response {
  if (url.includes('/riwayat-status')) return jawaban(200, []);
  return jawaban(200, order);
}

function halamanPesanKosong() {
  return { isi: [], total: 0, halaman: 1, ukuranHalaman: 50, totalHalaman: 0 };
}

function pasang(
  ambil: ReturnType<typeof vi.fn>,
  id = order().id,
  buatTiruan: () => ReturnType<typeof buatTiruanHub> = buatTiruanHub,
) {
  const buatKlien = (bacaToken: () => string | null) =>
    new KlienApi(bacaToken, 'http://uji', ambil as unknown as typeof fetch);

  return render(
    <MemoryRouter initialEntries={[`/order/${id}`]}>
      <PenyediaSesi buatKlien={buatKlien} buatHub={buatTiruan}>
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
        url.includes('/pesan') ? jawaban(200, halamanPesanKosong()) : jawabanOrder(url, order({ dibayarPada: null })),
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
          : jawabanOrder(url, order({ status: 'Batal', dibayarPada: new Date().toISOString() })),
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
          : jawabanOrder(url, order({ status: 'Dikerjakan', dibayarPada: new Date().toISOString() })),
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
          : jawabanOrder(url, order({ status: 'Dikerjakan', dibayarPada: new Date().toISOString() })),
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
        jawabanOrder(url, sudahDibatalkan ? { ...orderDibayar, status: 'Batal' } : orderDibayar),
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
      return Promise.resolve(jawabanOrder(url, orderDibayar));
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

/**
 * Sebelum rencana capstone bagian 43, layar ini cuma mengambil ulang setiap lima belas
 * detik: balasan klien atau runner baru terlihat admin rata-rata tujuh detik sesudah
 * dikirim. Dua hal yang diuji di sini, dan keduanya gampang salah ke arah yang berlawanan:
 * kabar untuk order INI harus memuat ulang, dan kabar untuk order lain tidak boleh —
 * grup admin menerima "OrderChanged" setiap order yang bergerak, bukan cuma yang sedang
 * dibuka.
 */
describe('kabar hub di layar detail', () => {
  function pasangDenganHub() {
    const kendali = buatKendaliHub();
    const ambil = vi.fn().mockImplementation((url: string) =>
      Promise.resolve(
        url.includes('/pesan') ? jawaban(200, halamanPesanKosong()) : jawabanOrder(url, order()),
      ),
    );

    pasang(ambil, order().id, () => kendali.hub);
    return { kendali, ambil };
  }

  it('mengikuti grup order yang sedang dibuka', async () => {
    const { kendali } = pasangDenganHub();

    await waitFor(() => expect(kendali.diikuti).toEqual([order().id]));
  });

  it('memuat ulang order dan percakapannya begitu ordernya dikabarkan berubah', async () => {
    const { kendali, ambil } = pasangDenganHub();

    await screen.findByText('SRH-042');
    const sebelum = ambil.mock.calls.length;

    kendali.picu(order().id);

    await waitFor(() => expect(ambil.mock.calls.length).toBeGreaterThan(sebelum));
  });

  it('mengabaikan kabar tentang order lain', async () => {
    const { kendali, ambil } = pasangDenganHub();

    await screen.findByText('SRH-042');
    const sebelum = ambil.mock.calls.length;

    kendali.picu('99999999-9999-9999-9999-999999999999');

    // Sengaja menunggu sebentar, bukan langsung memeriksa: pengambilan yang telanjur
    // berangkat butuh satu putaran mikrotugas untuk terlihat di hitungan ini.
    await new Promise((selesai) => setTimeout(selesai, 50));
    expect(ambil.mock.calls.length).toBe(sebelum);
  });
});

/**
 * Permintaan pembatalan dari klien: satu-satunya hal di layar ini yang menuntut jawaban,
 * karena di ujungnya ada uang yang dikembalikan atau tidak.
 *
 * Yang dijaga di sini dua-duanya: panelnya cuma muncul untuk order yang memang sedang
 * meminta, dan jawaban "tidak" benar-benar sampai ke endpoint yang benar berikut alasannya.
 * Sebelum endpoint tolak ada, "tidak" tidak punya jalan sama sekali: benderanya menempel
 * selamanya dan klien tidak pernah tahu permintaannya dibaca.
 */
describe('PanelPermintaanBatal', () => {
  const orderDiminta = () =>
    order({
      status: 'Dikerjakan',
      dibayarPada: new Date().toISOString(),
      mintaBatalPada: new Date().toISOString(),
    });

  it('tidak muncul untuk order yang tidak sedang meminta dibatalkan', async () => {
    const ambil = vi.fn().mockImplementation((url: string) =>
      Promise.resolve(
        url.includes('/pesan')
          ? jawaban(200, halamanPesanKosong())
          : jawabanOrder(url, order({ dibayarPada: new Date().toISOString() })),
      ),
    );

    pasang(ambil);

    await screen.findByText('SRH-042');
    expect(screen.queryByText('Klien minta order ini dibatalkan')).not.toBeInTheDocument();
  });

  it('muncul untuk order yang sedang menunggu keputusan', async () => {
    const ambil = vi.fn().mockImplementation((url: string) =>
      Promise.resolve(
        url.includes('/pesan') ? jawaban(200, halamanPesanKosong()) : jawabanOrder(url, orderDiminta()),
      ),
    );

    pasang(ambil);

    expect(await screen.findByText('Klien minta order ini dibatalkan')).toBeInTheDocument();
  });

  it('menolak permintaan mengirim alasannya ke endpoint tolak', async () => {
    const ambil = vi.fn().mockImplementation((url: string, init?: RequestInit) => {
      if (url.includes('/pesan')) return Promise.resolve(jawaban(200, halamanPesanKosong()));
      if (init?.method === 'POST' && url.includes('/tolak-pembatalan')) {
        return Promise.resolve(jawaban(200, order({ dibayarPada: new Date().toISOString() })));
      }
      return Promise.resolve(jawabanOrder(url, orderDiminta()));
    });

    pasang(ambil);

    fireEvent.click(await screen.findByRole('button', { name: 'Tolak permintaan' }));
    fireEvent.change(await screen.findByLabelText('Alasan menolak'), {
      target: { value: 'Runnernya sudah berangkat.' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Kirim penolakan' }));

    await waitFor(() => {
      const panggilan = ambil.mock.calls.find(
        ([url, init]) => String(url).includes('/tolak-pembatalan') && init?.method === 'POST',
      );
      expect(panggilan).toBeDefined();
      expect(JSON.parse(String(panggilan![1].body))).toEqual({
        alasan: 'Runnernya sudah berangkat.',
      });
    });
  });

  it('tombol kirim mati selama alasannya kosong', async () => {
    const ambil = vi.fn().mockImplementation((url: string) =>
      Promise.resolve(
        url.includes('/pesan') ? jawaban(200, halamanPesanKosong()) : jawabanOrder(url, orderDiminta()),
      ),
    );

    pasang(ambil);

    fireEvent.click(await screen.findByRole('button', { name: 'Tolak permintaan' }));

    expect(screen.getByRole('button', { name: 'Kirim penolakan' })).toBeDisabled();
  });
});


/**
 * Riwayat status: order yang mundur lalu maju lagi harus terlihat sebagai dua baris
 * terpisah, bukan cuma status terakhirnya. Diuji terpisah dari pembatalan/permintaan
 * batal di atas karena ini murni menampilkan, tidak ada aksi yang dikirim balik ke server.
 */
describe('RiwayatStatus', () => {
  function perubahan(ubah: Partial<PerubahanStatusOrder> = {}): PerubahanStatusOrder {
    return {
      id: 'p-1',
      orderId: order().id,
      dariStatus: 'MenungguPembayaran',
      keStatus: 'MencariRunner',
      dipicuOlehUserId: null,
      namaPemicu: null,
      diubahPada: new Date().toISOString(),
      ...ubah,
    };
  }

  function ambilDengan(riwayat: PerubahanStatusOrder[]) {
    return vi.fn().mockImplementation((url: string) => {
      if (url.includes('/pesan')) return Promise.resolve(jawaban(200, halamanPesanKosong()));
      if (url.includes('/riwayat-status')) return Promise.resolve(jawaban(200, riwayat));
      return Promise.resolve(jawaban(200, order()));
    });
  }

  it('order yang belum pernah berpindah menampilkan keterangan kosong', async () => {
    pasang(ambilDengan([]));

    expect(
      await screen.findByText('Order ini belum pernah berpindah status.'),
    ).toBeInTheDocument();
  });

  it('menampilkan perpindahan tanpa pemicu sebagai kabar sistem', async () => {
    pasang(ambilDengan([perubahan()]));

    expect(await screen.findByText('Menunggu Pembayaran → Mencari Runner')).toBeInTheDocument();
    expect(screen.getByText('Sistem (webhook pembayaran)')).toBeInTheDocument();
  });

  it('menampilkan nama pemicu ketika perpindahannya lahir dari tindakan seseorang', async () => {
    pasang(
      ambilDengan([
        perubahan({
          dariStatus: 'Dikerjakan',
          keStatus: 'MencariRunner',
          dipicuOlehUserId: 'r-1',
          namaPemicu: 'Adji',
        }),
      ]),
    );

    expect(await screen.findByText('Dikerjakan → Mencari Runner')).toBeInTheDocument();
    expect(screen.getByText('Adji')).toBeInTheDocument();
  });

  it('mundur lalu maju lagi tampil sebagai dua baris terpisah, bukan status terakhir saja', async () => {
    pasang(
      ambilDengan([
        perubahan({
          id: 'p-1',
          dariStatus: 'MencariRunner',
          keStatus: 'Dikerjakan',
          dipicuOlehUserId: 'r-1',
          namaPemicu: 'Adji',
        }),
        perubahan({
          id: 'p-2',
          dariStatus: 'Dikerjakan',
          keStatus: 'MencariRunner',
          dipicuOlehUserId: 'r-1',
          namaPemicu: 'Adji',
        }),
      ]),
    );

    expect(await screen.findByText('Mencari Runner → Dikerjakan')).toBeInTheDocument();
    expect(await screen.findByText('Dikerjakan → Mencari Runner')).toBeInTheDocument();
  });
});
