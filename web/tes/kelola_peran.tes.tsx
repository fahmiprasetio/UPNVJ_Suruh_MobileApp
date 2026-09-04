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
      if (url.includes('/peran/riwayat')) {
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
      if (url.includes('/peran/riwayat')) {
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
