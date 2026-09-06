import { useState, type FormEvent } from 'react';

/**
 * State dan alur "buka form → tulis alasan → kirim" yang sama persis di tiga panel
 * konfirmasi admin: menolak permintaan batal, membatalkan order beserta pengembalian
 * dananya, dan menangguhkan/memulihkan akun. Ketiganya sebelum ini menyalin sendiri-sendiri
 * empat `useState` dan satu fungsi `kirim` yang bentuknya identik, cuma isi panggilan API-nya
 * yang berbeda.
 *
 * Yang TIDAK ikut disatukan sengaja: bentuk kartunya (artikel besar berjudul sendiri, atau
 * sub-bagian di dalam kartu lain), dan teks tombol/label/placeholder-nya. Itu urusan
 * `FormAlasan` (lihat `komponen/form_alasan.tsx`) dan pemanggilnya masing-masing, karena
 * bentuknya berbeda cukup jauh antar ketiganya untuk dipaksakan jadi satu markup.
 *
 * Formnya selalu ditutup dan dikosongkan sesudah `kirimKe` berhasil, tidak peduli apakah
 * pemanggilnya butuh itu atau tidak. Untuk panel yang komponennya langsung dibongkar begitu
 * tindakannya berhasil (menolak permintaan batal, membatalkan order — parennya memuat ulang
 * order dan panelnya lenyap begitu keadaannya berubah), penutupan ini tidak pernah sempat
 * terlihat. Untuk panel yang komponennya tetap ada (menangguhkan akun — akun yang sama tetap
 * menampilkan panel yang sama sesudah ditangguhkan), penutupan ini yang membuat formnya tidak
 * nyangkut terbuka dengan teks lama sesudah berhasil disimpan.
 */
export function gunakanPanelKonfirmasi(kirimKe: (alasan: string) => Promise<void>) {
  const [terbuka, setTerbuka] = useState(false);
  const [alasan, setAlasan] = useState('');
  const [sibuk, setSibuk] = useState(false);
  const [galat, setGalat] = useState<unknown>(null);

  async function kirim(peristiwa: FormEvent) {
    peristiwa.preventDefault();
    setSibuk(true);
    setGalat(null);
    try {
      await kirimKe(alasan.trim());
      setAlasan('');
      setTerbuka(false);
    } catch (salah) {
      setGalat(salah);
    } finally {
      setSibuk(false);
    }
  }

  function urungkan() {
    setTerbuka(false);
    setAlasan('');
    setGalat(null);
  }

  return {
    terbuka,
    bukaForm: () => setTerbuka(true),
    urungkan,
    alasan,
    setAlasan,
    sibuk,
    galat,
    kirim,
  };
}
