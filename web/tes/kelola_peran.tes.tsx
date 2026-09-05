import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';

import { PenyediaSesi } from '../src/auth/sesi';
import { HalamanKelolaPeran } from '../src/halaman/kelola_peran';
import { KlienApi } from '../src/inti/klien_api';
import type { Pengguna } from '../src/inti/tipe';
import { buatTiruanHub } from './dukungan_hub';

/**
 * Tes ini menembus jalur admin mengangkat runner: mencari akun, mencentang perannya,
 * memberi alasan, lalu mengirim. Yang paling penting diuji bukan render, melainkan tiga
 * hal yang mudah salah: kata kunci pendek tidak boleh sampai memanggil server sama sekali
 * (backend menolaknya dan itu tidak perlu satu bolak-balik jaringan untuk dibuktikan),
 * tombol simpan tidak boleh aktif tanpa alasan, dan permintaan PUT yang berangkat harus
 * membawa persis peran yang tercentang di layar, bukan peran lama.
 */

function pengguna(ubah: Partial<Pengguna> = {}): Pengguna {
  return {
    id: '44444444-4444-4444-4444-444444444444',
    nama: 'Rifqi',
    noHp: '081234567890',
    alamat: null,
    roles: ['Klien'],
    ditangguhkanPada: null,
    alasanPenangguhan: null,
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
        <HalamanKelolaPeran />
      </PenyediaSesi>
    </MemoryRouter>,
  );
}

describe('HalamanKelolaPeran', () => {
  it('tidak memanggil server untuk kata kunci di bawah 3 huruf', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    const ambil = vi.fn().mockResolvedValue(jawaban(200, []));
    pasang(ambil);

    fireEvent.change(screen.getByLabelText('Cari nama atau nomor HP'), {
      target: { value: 'ri' },
    });

    await act(() => vi.advanceTimersByTimeAsync(500));
    expect(ambil).not.toHaveBeenCalled();
    expect(
      screen.getByText('Isi minimal 3 huruf dari nama atau nomor HP-nya.'),
    ).toBeInTheDocument();
    vi.useRealTimers();
  });

  it('menunggu pengetikan berhenti sebelum mencari, lalu menampilkan hasilnya', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    const ambil = vi.fn().mockImplementation((url: string) =>
      Promise.resolve(
        url.includes('/api/admin/pengguna?q=')
          ? jawaban(200, [pengguna()])
          : jawaban(200, { isi: [], total: 0, halaman: 1, ukuranHalaman: 20, totalHalaman: 0 }),
      ),
    );
    pasang(ambil);

    fireEvent.change(screen.getByLabelText('Cari nama atau nomor HP'), {
      target: { value: 'rifqi' },
    });

    await act(() => vi.advanceTimersByTimeAsync(400));
    vi.useRealTimers();

    expect(await screen.findByText('Rifqi')).toBeInTheDocument();
    expect(ambil.mock.calls.some((c) => (c[0] as string).includes('q=rifqi'))).toBe(true);
  });

  it('tidak mengizinkan simpan tanpa alasan diisi', async () => {
    // Panel muncul lewat pemilihan baris, yang menuntut hasil pencarian lebih dulu, jadi
    // tes ini menembus jalur penuh: ketik, tunggu, klik baris, baru periksa tombolnya.
    const ambil = vi.fn().mockImplementation((url: string) =>
      Promise.resolve(
        url.includes('q=rifqi')
          ? jawaban(200, [pengguna()])
          : jawaban(200, { isi: [], total: 0, halaman: 1, ukuranHalaman: 20, totalHalaman: 0 }),
      ),
    );
    pasang(ambil);

    fireEvent.change(screen.getByLabelText('Cari nama atau nomor HP'), {
      target: { value: 'rifqi' },
    });

    fireEvent.click(await screen.findByText('Rifqi'));

    const tombolSimpan = await screen.findByRole('button', { name: 'Simpan perubahan peran' });
    expect(tombolSimpan).toBeDisabled();

    fireEvent.click(screen.getByRole('checkbox', { name: 'Runner' }));
    // Peran berubah tapi alasan masih kosong: tombol tetap harus mati.
    expect(tombolSimpan).toBeDisabled();

    fireEvent.change(screen.getByLabelText('Alasan perubahan'), {
      target: { value: 'Diangkat jadi runner setelah wawancara.' },
    });
    expect(tombolSimpan).toBeEnabled();
  });

  it('mengirim persis peran yang tercentang di layar, bukan peran lama', async () => {
    const permintaan: { url: string; init: RequestInit }[] = [];
    const ambil = vi.fn().mockImplementation((url: string, init: RequestInit) => {
      permintaan.push({ url, init });
      if (url.includes('/peran/riwayat') || url.includes('/pelepasan')) {
        return Promise.resolve(
          jawaban(200, { isi: [], total: 0, halaman: 1, ukuranHalaman: 20, totalHalaman: 0 }),
        );
      }
      if (init?.method === 'PUT') {
        return Promise.resolve(jawaban(200, pengguna({ roles: ['Klien', 'Runner'] })));
      }
      return Promise.resolve(jawaban(200, [pengguna()]));
    });

    pasang(ambil);

    fireEvent.change(screen.getByLabelText('Cari nama atau nomor HP'), {
      target: { value: 'rifqi' },
    });
    fireEvent.click(await screen.findByText('Rifqi'));
    fireEvent.click(await screen.findByRole('checkbox', { name: 'Runner' }));
    fireEvent.change(screen.getByLabelText('Alasan perubahan'), {
      target: { value: 'Diangkat jadi runner setelah wawancara.' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Simpan perubahan peran' }));

    await waitFor(() => {
      expect(permintaan.some((p) => p.init?.method === 'PUT')).toBe(true);
    });

    const permintaanPut = permintaan.find((p) => p.init?.method === 'PUT');
    const badan = JSON.parse(permintaanPut?.init.body as string) as {
      roles: string[];
      alasan: string;
    };

    expect(badan.roles.sort()).toEqual(['Klien', 'Runner'].sort());
    expect(badan.alasan).toBe('Diangkat jadi runner setelah wawancara.');
  });

  it('memperingatkan sebelum mencabut peran admin dari akun sendiri', async () => {
    const admin = pengguna({
      id: '55555555-5555-5555-5555-555555555555',
      nama: 'Jiro',
      roles: ['Admin', 'Runner'],
    });

    const ambil = vi.fn().mockImplementation((url: string) => {
      if (url.includes('/api/auth/saya')) return Promise.resolve(jawaban(200, admin));
      if (url.includes('/peran/riwayat') || url.includes('/pelepasan')) {
        return Promise.resolve(
          jawaban(200, { isi: [], total: 0, halaman: 1, ukuranHalaman: 20, totalHalaman: 0 }),
        );
      }
      if (url.includes('/api/admin/pengguna?q=')) return Promise.resolve(jawaban(200, [admin]));
      return Promise.resolve(jawaban(404, {}));
    });

    window.sessionStorage.setItem('upnvj-suruh.token-admin', 'token-uji');
    pasang(ambil);

    fireEvent.change(await screen.findByLabelText('Cari nama atau nomor HP'), {
      target: { value: 'jiro' },
    });

    fireEvent.click(await screen.findByText('Jiro'));
    fireEvent.click(await screen.findByRole('checkbox', { name: 'Admin' }));

    expect(
      screen.getByText(
        'Ini akun kamu sendiri. Mencabut peran admin dari akun sendiri akan ditolak server.',
      ),
    ).toBeInTheDocument();

    window.sessionStorage.clear();
  });
});

/**
 * Menangguhkan akun berdiri terpisah dari mengubah peran, dan itu keputusan yang diuji di
 * sini: mengubah peran mempersempit apa yang bisa dikerjakan seseorang, sedangkan
 * menangguhkan menghentikannya sama sekali. Satu tombol simpan untuk keduanya berarti satu
 * kesalahan klik bisa menghentikan orang yang sebenarnya cuma mau diubah perannya.
 */
describe('PanelPenangguhan', () => {
  function ambilDengan(hasilPencarian: Pengguna) {
    return vi.fn().mockImplementation((url: string, init?: RequestInit) => {
      if (url.includes('/peran/riwayat') || url.includes('/pelepasan')) {
        return Promise.resolve(
          jawaban(200, { isi: [], total: 0, halaman: 1, ukuranHalaman: 20, totalHalaman: 0 }),
        );
      }
      if (init?.method === 'POST') {
        return Promise.resolve(
          jawaban(200, pengguna({ ditangguhkanPada: new Date().toISOString() })),
        );
      }
      return Promise.resolve(jawaban(200, [hasilPencarian]));
    });
  }

  async function pilihRifqi(hasilPencarian: Pengguna) {
    const ambil = ambilDengan(hasilPencarian);
    pasang(ambil);

    fireEvent.change(screen.getByLabelText('Cari nama atau nomor HP'), {
      target: { value: 'rifqi' },
    });
    fireEvent.click(await screen.findByText('Rifqi'));
    return ambil;
  }

  it('akun biasa menawarkan penangguhan, bukan pemulihan', async () => {
    await pilihRifqi(pengguna());

    expect(
      await screen.findByRole('button', { name: 'Tangguhkan akun ini' }),
    ).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Pulihkan akun ini' })).not.toBeInTheDocument();
  });

  /// Admin harus tahu akun itu sedang berhenti sebelum menyunting apa pun, supaya ia tidak
  /// mengira perubahan peran yang ia simpan akan langsung dipakai orangnya.
  it('akun yang ditangguhkan mengatakannya beserta alasannya', async () => {
    await pilihRifqi(
      pengguna({
        ditangguhkanPada: new Date().toISOString(),
        alasanPenangguhan: 'Memesan lalu minta batal berulang kali.',
      }),
    );

    expect(
      await screen.findByText(/Memesan lalu minta batal berulang kali\./),
    ).toBeInTheDocument();
    expect(
      screen.getByRole('button', { name: 'Pulihkan akun ini' }),
    ).toBeInTheDocument();
  });

  it('menuntut alasan sebelum penangguhan bisa dikirim', async () => {
    await pilihRifqi(pengguna());

    fireEvent.click(await screen.findByRole('button', { name: 'Tangguhkan akun ini' }));

    const kirim = screen.getByRole('button', { name: 'Ya, tangguhkan akun ini' });
    expect(kirim).toBeDisabled();

    fireEvent.change(screen.getByLabelText('Alasan menangguhkan'), {
      target: { value: 'Nomor palsu.' },
    });
    expect(kirim).toBeEnabled();
  });

  it('mengirim alasannya ke endpoint tangguhkan', async () => {
    const ambil = await pilihRifqi(pengguna());

    fireEvent.click(await screen.findByRole('button', { name: 'Tangguhkan akun ini' }));
    fireEvent.change(screen.getByLabelText('Alasan menangguhkan'), {
      target: { value: 'Nomor palsu.' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Ya, tangguhkan akun ini' }));

    await waitFor(() => {
      const panggilan = ambil.mock.calls.find(
        ([url, init]) => String(url).includes('/tangguhkan') && init?.method === 'POST',
      );
      expect(panggilan).toBeDefined();
      expect(JSON.parse(String(panggilan![1].body))).toEqual({ alasan: 'Nomor palsu.' });
    });
  });

  /// Backend menolaknya, dan menunggu penolakan server untuk hal yang sudah pasti ditolak
  /// cuma membuang satu bolak-balik jaringan.
  it('tidak menawarkan penangguhan untuk akun sendiri', async () => {
    window.sessionStorage.setItem('upnvj-suruh.token-admin', 'token-uji');

    const saya = pengguna({ roles: ['Admin'] });
    const ambil = vi.fn().mockImplementation((url: string) => {
      if (url.includes('/api/auth/saya')) return Promise.resolve(jawaban(200, saya));
      if (url.includes('/peran/riwayat') || url.includes('/pelepasan')) {
        return Promise.resolve(
          jawaban(200, { isi: [], total: 0, halaman: 1, ukuranHalaman: 20, totalHalaman: 0 }),
        );
      }
      return Promise.resolve(jawaban(200, [saya]));
    });

    pasang(ambil);
    fireEvent.change(screen.getByLabelText('Cari nama atau nomor HP'), {
      target: { value: 'rifqi' },
    });
    fireEvent.click(await screen.findByText('Rifqi'));

    expect(
      await screen.findByText(/tidak bisa ditangguhkan dari sini/),
    ).toBeInTheDocument();

    window.sessionStorage.clear();
  });

  /**
   * Penangguhan bisa dicabut, tapi tanpa penyaring ini satu-satunya jalan menemukan
   * akunnya kembali adalah mengingat namanya. Kotak centangnya karena itu harus bisa
   * meminta daftar tanpa kata kunci sama sekali — yang persis dilarang untuk pencarian
   * biasa, jadi ini justru bagian yang paling mudah salah.
   */
  it('meminta daftar akun tertangguh tanpa kata kunci sama sekali', async () => {
    const ambil = vi.fn().mockImplementation((url: string) =>
      Promise.resolve(
        String(url).includes('tertangguh=true')
          ? jawaban(200, [pengguna({ ditangguhkanPada: '2026-09-05T10:00:00Z' })])
          : jawaban(200, []),
      ),
    );
    pasang(ambil);

    fireEvent.click(screen.getByLabelText('Hanya akun yang ditangguhkan'));

    expect(await screen.findByText('Rifqi')).toBeInTheDocument();
    const dipanggil = ambil.mock.calls.map((c) => String(c[0]));
    expect(dipanggil.some((u) => u.includes('tertangguh=true'))).toBe(true);
    expect(dipanggil.every((u) => !u.includes('q='))).toBe(true);
  });

  it('menandai akun yang ditangguhkan di hasil pencarian biasa', async () => {
    await pilihRifqi(pengguna({ ditangguhkanPada: '2026-09-05T10:00:00Z' }));

    expect(await screen.findByText('ditangguhkan')).toBeInTheDocument();
  });

  /**
   * Bukti yang dipakai memutuskan apakah sebuah akun pantas dihentikan. Sebelum catatan
   * ini ada, runner yang menerima lalu melepas sepuluh order berturut-turut meninggalkan
   * basis data yang bentuknya persis sama dengan runner yang tidak pernah melakukannya.
   */
  it('menampilkan order yang pernah dilepas beserta alasannya', async () => {
    const ambil = vi.fn().mockImplementation((url: string) => {
      if (String(url).includes('/pelepasan')) {
        return Promise.resolve(
          jawaban(200, {
            isi: [
              {
                id: 'p-1',
                orderId: 'o-1',
                kodeOrder: 'SRH-0042',
                runnerId: '44444444-4444-4444-4444-444444444444',
                alasan: 'Motor mogok di Lenteng Agung.',
                dilepasPada: '2026-09-05T10:00:00Z',
              },
            ],
            total: 1,
            halaman: 1,
            ukuranHalaman: 20,
            totalHalaman: 1,
          }),
        );
      }
      if (String(url).includes('/peran/riwayat')) {
        return Promise.resolve(
          jawaban(200, { isi: [], total: 0, halaman: 1, ukuranHalaman: 20, totalHalaman: 0 }),
        );
      }
      return Promise.resolve(jawaban(200, [pengguna()]));
    });

    pasang(ambil);
    fireEvent.change(screen.getByLabelText('Cari nama atau nomor HP'), {
      target: { value: 'rifqi' },
    });
    fireEvent.click(await screen.findByText('Rifqi'));

    expect(await screen.findByText('SRH-0042')).toBeInTheDocument();
    expect(screen.getByText('Motor mogok di Lenteng Agung.')).toBeInTheDocument();
    // Jumlahnya ikut di judulnya: yang dicari admin pola, dan satu kali melepas berbeda
    // artinya dari sepuluh kali.
    expect(screen.getByText(/Order yang pernah dilepas \(1\)/)).toBeInTheDocument();
  });

  it('mengatakan dengan jelas kalau akun ini belum pernah melepas order', async () => {
    await pilihRifqi(pengguna());

    expect(
      await screen.findByText(
        'Akun ini belum pernah melepas order yang sudah diterimanya.',
      ),
    ).toBeInTheDocument();
  });
});
