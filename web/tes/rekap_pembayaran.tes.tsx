import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';

import { PenyediaSesi } from '../src/auth/sesi';
import { HalamanRekapPembayaran } from '../src/halaman/rekap_pembayaran';
import { KlienApi } from '../src/inti/klien_api';
import type { BarisPayout, PayoutSetting, RekapPayout, RekapRunner, RincianPayout } from '../src/inti/tipe';
import { buatTiruanHub } from './dukungan_hub';

/**
 * Yang paling penting diuji di sini adalah dua hal yang menyangkut uang sungguhan.
 *
 * Pertama, keadaan "rumus bagi hasil belum diatur" harus kelihatan sebagai keadaan yang
 * belum dikerjakan, bukan sebagai angka nol yang wajar: admin yang melihat "Rp 0" tanpa
 * penjelasan akan mengira runnernya memang belum berhak dibayar.
 *
 * Kedua, yang dikirim saat menandai lunas harus persis baris yang tercentang di layar,
 * bukan perintah "lunasi semua yang belum lunas". Order yang selesai beberapa detik setelah
 * halamannya dimuat akan ikut tertandai lunas oleh perintah semacam itu, padahal uang yang
 * berpindah tangan cuma sebesar yang tertera di layar tadi.
 */

function setting(ubah: Partial<PayoutSetting> = {}): PayoutSetting {
  return {
    mode: 'Persen',
    komisiPersen: 20,
    komisiTetap: 0,
    sudahDiatur: true,
    diaturPada: '2026-09-04T02:00:00Z',
    ...ubah,
  };
}

function runner(ubah: Partial<RekapRunner> = {}): RekapRunner {
  return {
    runnerId: 'runner-1',
    nama: 'Adji',
    telepon: '081234567890',
    jumlahOrderBelumDibayar: 2,
    totalBelumDibayar: 24000,
    totalSudahDibayar: 8000,
    menungguRumus: 0,
    terakhirDibayarPada: null,
    ...ubah,
  };
}

function rekap(ubah: Partial<RekapPayout> = {}): RekapPayout {
  return {
    setting: setting(),
    runner: [runner()],
    totalBelumDibayar: 24000,
    totalMenungguRumus: 0,
    ...ubah,
  };
}

function baris(ubah: Partial<BarisPayout> = {}): BarisPayout {
  return {
    penugasanId: 'tugas-1',
    orderId: 'order-1',
    kodeOrder: 'SRH-0412',
    layanan: 'AnterJemput',
    selesaiPada: '2026-09-03T10:00:00Z',
    jumlah: 12000,
    dibayarPada: null,
    ...ubah,
  };
}

function rincian(ubah: Partial<RincianPayout> = {}): RincianPayout {
  return {
    runnerId: 'runner-1',
    nama: 'Adji',
    telepon: '081234567890',
    belumDibayar: [baris(), baris({ penugasanId: 'tugas-2', kodeOrder: 'SRH-0413' })],
    totalBelumDibayar: 24000,
    sudahDibayar: { isi: [], total: 0, halaman: 1, ukuranHalaman: 20, totalHalaman: 0 },
    totalSudahDibayar: 8000,
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
        <HalamanRekapPembayaran />
      </PenyediaSesi>
    </MemoryRouter>,
  );
}

/** Pelayan tiruan yang menjawab tiap endpoint payout dan mencatat permintaannya. */
function pelayan(opsi: { rekap?: RekapPayout; rincian?: RincianPayout } = {}) {
  const permintaan: { url: string; init?: RequestInit }[] = [];

  const ambil = vi.fn().mockImplementation((url: string, init?: RequestInit) => {
    permintaan.push({ url, init });

    if (url.includes('/lunas')) {
      return Promise.resolve(
        jawaban(200, { jumlahDitandai: 2, totalDitandai: 24000, dibayarPada: '2026-09-04T03:00:00Z' }),
      );
    }
    if (init?.method === 'PUT') {
      return Promise.resolve(jawaban(200, setting()));
    }
    if (/\/rekap\/[^/?]+/.test(url)) {
      return Promise.resolve(jawaban(200, opsi.rincian ?? rincian()));
    }
    return Promise.resolve(jawaban(200, opsi.rekap ?? rekap()));
  });

  return { ambil, permintaan };
}

describe('HalamanRekapPembayaran', () => {
  it('menampilkan siapa harus dibayar berapa', async () => {
    const { ambil } = pelayan();
    pasang(ambil);

    expect(await screen.findByText('Adji')).toBeInTheDocument();
    expect(screen.getAllByText('Rp 24.000').length).toBeGreaterThan(0);
  });

  it('menyebut bahwa rumusnya belum diatur, bukan diam-diam menampilkan nol', async () => {
    const { ambil } = pelayan({
      rekap: rekap({
        setting: setting({ sudahDiatur: false, komisiPersen: 0, diaturPada: null }),
        runner: [runner({ jumlahOrderBelumDibayar: 0, totalBelumDibayar: 0, menungguRumus: 3 })],
        totalBelumDibayar: 0,
        totalMenungguRumus: 3,
      }),
    });
    pasang(ambil);

    expect(
      await screen.findByText(/Rumus bagi hasil belum pernah diatur/),
    ).toBeInTheDocument();
    expect(screen.getByText(/3 bayaran sedang menunggu rumus ini/)).toBeInTheDocument();
    expect(screen.getByText('+3 menunggu rumus')).toBeInTheDocument();
  });

  it('mengirim mode beserta kedua angkanya saat rumus disimpan', async () => {
    const { ambil, permintaan } = pelayan();
    pasang(ambil);

    const kolomPersen = await screen.findByLabelText('Komisi organisasi (%)');
    fireEvent.change(kolomPersen, { target: { value: '30' } });
    fireEvent.click(screen.getByRole('button', { name: 'Simpan rumus' }));

    await waitFor(() => {
      expect(permintaan.some((p) => p.init?.method === 'PUT')).toBe(true);
    });

    const put = permintaan.find((p) => p.init?.method === 'PUT');
    expect(put?.url).toBe('http://uji/api/admin/payout/setting');
    expect(JSON.parse(put?.init?.body as string)).toEqual({
      mode: 'Persen',
      komisiPersen: 30,
      komisiTetap: 0,
    });
  });

  it('mematikan angka milik mode yang tidak dipilih', async () => {
    const { ambil } = pelayan();
    pasang(ambil);

    expect(await screen.findByLabelText('Komisi organisasi (%)')).toBeEnabled();
    expect(screen.getByLabelText('Komisi organisasi (Rp)')).toBeDisabled();

    fireEvent.click(screen.getByRole('radio', { name: /Rupiah tetap/ }));

    expect(screen.getByLabelText('Komisi organisasi (%)')).toBeDisabled();
    expect(screen.getByLabelText('Komisi organisasi (Rp)')).toBeEnabled();
  });

  it('membuka rincian order yang membentuk tagihan seorang runner', async () => {
    const { ambil } = pelayan();
    pasang(ambil);

    fireEvent.click(await screen.findByRole('button', { name: 'Rincian' }));

    expect(await screen.findByText('SRH-0412')).toBeInTheDocument();
    expect(screen.getByText('SRH-0413')).toBeInTheDocument();
  });

  it('mengirim persis bayaran yang tercentang, bukan seluruh yang belum lunas', async () => {
    const { ambil, permintaan } = pelayan();
    pasang(ambil);

    fireEvent.click(await screen.findByRole('button', { name: 'Rincian' }));

    // Semuanya tercentang saat dibuka; satu dilepas, jadi yang terkirim tinggal satu.
    fireEvent.click(await screen.findByLabelText('Bayaran order SRH-0413'));

    fireEvent.click(screen.getByRole('button', { name: /Tandai 1 bayaran lunas/ }));

    await waitFor(() => {
      expect(permintaan.some((p) => p.url.includes('/lunas'))).toBe(true);
    });

    const lunas = permintaan.find((p) => p.url.includes('/lunas'));
    expect(lunas?.url).toBe('http://uji/api/admin/payout/rekap/runner-1/lunas');
    expect(JSON.parse(lunas?.init?.body as string)).toEqual({ penugasanIds: ['tugas-1'] });
  });

  it('menyebutkan total yang akan ditandai, mengikuti centangnya', async () => {
    const { ambil } = pelayan();
    pasang(ambil);

    fireEvent.click(await screen.findByRole('button', { name: 'Rincian' }));

    expect(
      await screen.findByRole('button', { name: 'Tandai 2 bayaran lunas (Rp 24.000)' }),
    ).toBeInTheDocument();

    fireEvent.click(screen.getByLabelText('Bayaran order SRH-0413'));

    expect(
      screen.getByRole('button', { name: 'Tandai 1 bayaran lunas (Rp 12.000)' }),
    ).toBeInTheDocument();
  });

  /**
   * Bayaran yang belum punya angka ditolak server, jadi centangnya dimatikan di sini juga:
   * menawarkan centang untuk sesuatu yang pasti ditolak cuma membuat admin menemukan
   * penolakannya sesudah menekan tombol.
   */
  it('tidak menawarkan pelunasan untuk bayaran yang belum dihitung', async () => {
    const { ambil } = pelayan({
      rincian: rincian({
        belumDibayar: [baris({ jumlah: null })],
        totalBelumDibayar: 0,
      }),
    });
    pasang(ambil);

    fireEvent.click(await screen.findByRole('button', { name: 'Rincian' }));

    expect(await screen.findByLabelText('Bayaran order SRH-0412')).toBeDisabled();
    expect(screen.getByText('menunggu rumus')).toBeInTheDocument();
  });

  it('mengatakan bahwa menandai lunas bukan mengirim uang', async () => {
    const { ambil } = pelayan();
    pasang(ambil);

    fireEvent.click(await screen.findByRole('button', { name: 'Rincian' }));

    expect(
      await screen.findByText(
        'Menandai lunas hanya mencatat bahwa uangnya sudah diserahkan; tidak ada uang yang dikirim aplikasi ini.',
      ),
    ).toBeInTheDocument();
  });

  it('menampilkan keadaan kosong saat belum ada runner yang menyelesaikan order', async () => {
    const { ambil } = pelayan({
      rekap: rekap({ runner: [], totalBelumDibayar: 0 }),
    });
    pasang(ambil);

    expect(
      await screen.findByText('Belum ada runner yang menyelesaikan order.'),
    ).toBeInTheDocument();
  });
});
