import { fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { PerluAdmin } from '../src/auth/penjaga_admin';
import { PenyediaSesi, useSesi } from '../src/auth/sesi';
import { HalamanMasuk } from '../src/halaman/masuk';
import { KlienApi } from '../src/inti/klien_api';
import type { Pengguna } from '../src/inti/tipe';
import { buatTiruanHub } from './dukungan_hub';

/**
 * Penjaga ini bukan penjagaan keamanan; yang menjaga data ada di backend. Yang diuji di
 * sini adalah janji yang lain: orang tidak dilempar ke layar yang seluruh isinya akan
 * dijawab 403, dan orang yang salah akun diberi tahu apa yang sebenarnya kurang alih-alih
 * diputar-putar di antara dua layar.
 */

/// Memicu satu permintaan atas nama sesi yang sedang berjalan, tanpa bergantung pada
/// isi layar tertentu.
function TombolAmbil() {
  const { api } = useSesi();
  return (
    <button
      type="button"
      onClick={() => {
        void api.minta('/api/orders').catch(() => {});
      }}
    >
      Ambil sesuatu
    </button>
  );
}

function pasangSesi(jawabanSaya: () => Promise<Response>, halamanMasukSungguhan = false) {
  const ambil = vi.fn().mockImplementation(jawabanSaya);
  const buatKlien = (bacaToken: () => string | null, saatSesiDitolak: () => void) =>
    new KlienApi(
      bacaToken,
      'http://uji',
      ambil as unknown as typeof fetch,
      saatSesiDitolak,
    );

  return render(
    <MemoryRouter initialEntries={['/order']}>
      <PenyediaSesi buatKlien={buatKlien} buatHub={buatTiruanHub}>
        <Routes>
          <Route
            path="/masuk"
            element={halamanMasukSungguhan ? <HalamanMasuk /> : <p>Halaman masuk</p>}
          />
          <Route
            path="/order"
            element={
              <PerluAdmin>
                <p>Isi dashboard</p>
                <TombolAmbil />
              </PerluAdmin>
            }
          />
        </Routes>
      </PenyediaSesi>
    </MemoryRouter>,
  );
}

function pengguna(roles: Pengguna['roles']): Response {
  const isi: Pengguna = {
    id: '11111111-1111-1111-1111-111111111111',
    nama: 'Jiro',
    noHp: '08123',
    alamat: null,
    roles,
    ditangguhkanPada: null,
    alasanPenangguhan: null,
  };
  return new Response(JSON.stringify(isi), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

afterEach(() => {
  window.sessionStorage.clear();
});

describe('PerluAdmin', () => {
  it('melempar yang belum masuk ke halaman masuk', async () => {
    pasangSesi(() => Promise.resolve(pengguna(['Admin'])));

    expect(await screen.findByText('Halaman masuk')).toBeInTheDocument();
  });

  it('meloloskan akun yang menyandang peran admin', async () => {
    window.sessionStorage.setItem('upnvj-suruh.token-admin', 'token-uji');
    pasangSesi(() => Promise.resolve(pengguna(['Admin', 'Runner'])));

    expect(await screen.findByText('Isi dashboard')).toBeInTheDocument();
  });

  it('menahan akun tanpa peran admin tanpa melemparnya ke layar masuk', async () => {
    // Masuk ulang tidak akan menambah peran. Melemparnya ke halaman masuk cuma membuat
    // orang berputar-putar tanpa pernah diberi tahu apa yang kurang.
    window.sessionStorage.setItem('upnvj-suruh.token-admin', 'token-uji');
    pasangSesi(() => Promise.resolve(pengguna(['Runner'])));

    expect(await screen.findByText('Dashboard ini khusus admin')).toBeInTheDocument();
    expect(screen.queryByText('Halaman masuk')).not.toBeInTheDocument();
  });

  it('mengeluarkan orang saat tokennya sudah tidak berlaku', async () => {
    window.sessionStorage.setItem('upnvj-suruh.token-admin', 'token-basi');
    pasangSesi(() => Promise.resolve(new Response('', { status: 401 })));

    expect(await screen.findByText('Halaman masuk')).toBeInTheDocument();
    expect(window.sessionStorage.getItem('upnvj-suruh.token-admin')).toBeNull();
  });

  it('tidak membuang token hanya karena server sedang mati', async () => {
    // Kode masuk dikirim lewat SMS dan berbiaya per pesan. Menghapus token setiap kali
    // backend sempat direstart berarti menyuruh admin membeli kode baru tanpa sebab.
    window.sessionStorage.setItem('upnvj-suruh.token-admin', 'token-baik');
    pasangSesi(() => Promise.reject(new TypeError('failed to fetch')));

    expect(await screen.findByText('Halaman masuk')).toBeInTheDocument();
    expect(window.sessionStorage.getItem('upnvj-suruh.token-admin')).toBe('token-baik');
  });

  /**
   * Token berlaku 60 menit dan tidak ada penyegarannya, jadi admin yang membiarkan
   * dashboard terbuka lebih lama dari itu adalah kejadian biasa. Sebelumnya 401 cuma
   * ditangani pada pemeriksaan token saat dashboard DIBUKA; yang habis saat sedang
   * dipakai tidak menghasilkan apa pun selain setiap kartu berubah jadi kotak galat
   * dengan tombol coba lagi yang selamanya gagal.
   */
  it('mengeluarkan orang saat tokennya ditolak di tengah pemakaian', async () => {
    window.sessionStorage.setItem('upnvj-suruh.token-admin', 'token-baik');

    // Pemeriksaan pertama lolos, permintaan berikutnya ditolak. Itu bentuk sungguhan
    // dari sesi yang habis waktunya: dashboard sempat terbuka, lalu berhenti diterima.
    let pertama = true;
    pasangSesi(() => {
      if (pertama) {
        pertama = false;
        return Promise.resolve(pengguna(['Admin']));
      }
      return Promise.resolve(new Response('', { status: 401 }));
    });

    const isi = await screen.findByText('Isi dashboard');
    expect(isi).toBeInTheDocument();

    // Kartu mana pun di dashboard akan mengambil data lagi; di sini satu permintaan
    // dipicu lewat tombol supaya tesnya tidak bergantung pada isi layar tertentu.
    fireEvent.click(screen.getByRole('button', { name: 'Ambil sesuatu' }));

    expect(await screen.findByText('Halaman masuk')).toBeInTheDocument();
    expect(window.sessionStorage.getItem('upnvj-suruh.token-admin')).toBeNull();
  });

  it('menjelaskan kenapa orangnya tiba-tiba ada di halaman masuk', async () => {
    window.sessionStorage.setItem('upnvj-suruh.token-admin', 'token-basi');
    pasangSesi(() => Promise.resolve(new Response('', { status: 401 })), true);

    expect(
      await screen.findByText(/Sesimu sudah berakhir/),
    ).toBeInTheDocument();
  });

  it('tidak menuduh sesi berakhir sendiri saat tidak ada token sama sekali', async () => {
    pasangSesi(() => Promise.resolve(pengguna(['Admin'])), true);

    expect(await screen.findByText('Dashboard Admin')).toBeInTheDocument();
    expect(screen.queryByText(/Sesimu sudah berakhir/)).not.toBeInTheDocument();
  });
});
