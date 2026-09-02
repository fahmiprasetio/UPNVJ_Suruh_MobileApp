import { Navigate, Route, Routes } from 'react-router-dom';

import { PerluAdmin } from './auth/penjaga_admin';
import { PenyediaSesi } from './auth/sesi';
import { Rangka } from './komponen/rangka';
import { HalamanDetailOrder } from './halaman/detail_order';
import { HalamanMasuk } from './halaman/masuk';
import { HalamanPantauanOrder } from './halaman/pantauan_order';

/**
 * Peta alamat dashboard.
 *
 * Seluruh halaman berada di dalam satu penjaga, bukan dijaga satu per satu. Penjagaan yang
 * dipasang per halaman menuntut setiap halaman baru mengingat memasangnya, dan yang lupa
 * tidak akan ketahuan sampai ada yang membuka alamatnya tanpa masuk.
 *
 * Halaman masuk sengaja di luar rangka: bilah atas berisi nama pengguna dan tombol keluar
 * tidak punya arti bagi orang yang belum masuk.
 */
export function App() {
  return (
    <PenyediaSesi>
      <Routes>
        <Route path="/masuk" element={<HalamanMasuk />} />

        <Route
          element={
            <PerluAdmin>
              <Rangka />
            </PerluAdmin>
          }
        >
          <Route path="/order" element={<HalamanPantauanOrder />} />
          <Route path="/order/:id" element={<HalamanDetailOrder />} />
        </Route>

        {/* Beranda dashboard adalah pantauan order, bukan halaman sambutan. Yang membuka
            alamat ini selalu punya satu pertanyaan yang sama: ada order apa sekarang. */}
        <Route path="/" element={<Navigate to="/order" replace />} />
        <Route path="*" element={<Navigate to="/order" replace />} />
      </Routes>
    </PenyediaSesi>
  );
}
