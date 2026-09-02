import { useCallback, useEffect, useState } from 'react';

/**
 * Mengambil data, lalu mengambilnya ulang selama layarnya terbuka.
 *
 * Satu tempat untuk pola yang kalau tidak dikumpulkan akan ditulis ulang di setiap layar,
 * dan ditulis ulang berarti ada yang lupa satu bagiannya. Tiga bagian yang paling sering
 * hilang:
 *
 * 1. Permintaan dibatalkan saat layarnya ditinggalkan. Tanpa itu, jawaban yang datang
 *    belakangan menulisi keadaan layar yang sudah tidak ada.
 * 2. Jawaban yang datang terlambat tidak boleh menimpa jawaban yang lebih baru. Admin
 *    yang mengganti penyaring dua kali dengan cepat akan melihat hasil penyaring pertama
 *    kalau urutannya tidak dijaga; di sini dijaga oleh sinyal batal yang sama.
 * 3. Pengambilan ulang berkala tidak boleh mengosongkan layar lebih dulu. Daftar yang
 *    berkedip jadi "Memuat..." setiap lima belas detik tidak bisa dibaca.
 *
 * Selang pengambilan ulangnya disamakan dengan sisi mobile (15 detik) dan alasannya sama:
 * ini jaring pengaman untuk perubahan yang dibuat orang lain, sampai hub SignalR dipakai
 * dan kabarnya datang tepat saat ada yang berubah.
 */

export const jedaSegarkanMilidetik = 15_000;

export interface HasilMuat<T> {
  data: T | null;
  memuat: boolean;
  galat: unknown;
  muatUlang: () => void;
}

export function gunakanMuat<T>(
  ambil: (sinyal: AbortSignal) => Promise<T>,
  opsi: { segarkanBerkala?: boolean } = {},
): HasilMuat<T> {
  const { segarkanBerkala = false } = opsi;

  const [data, setData] = useState<T | null>(null);
  const [memuat, setMemuat] = useState(true);
  const [galat, setGalat] = useState<unknown>(null);
  const [penanda, setPenanda] = useState(0);

  const muatUlang = useCallback(() => setPenanda((n) => n + 1), []);

  useEffect(() => {
    const kendali = new AbortController();
    let hidup = true;

    // Hanya pengambilan pertama yang menyalakan keadaan memuat. Pengambilan berkala
    // membiarkan data lama tetap di layar sampai penggantinya siap.
    setMemuat((sebelumnya) => sebelumnya || data === null);

    ambil(kendali.signal)
      .then((hasil) => {
        if (!hidup) return;
        setData(hasil);
        setGalat(null);
      })
      .catch((salah) => {
        if (!hidup) return;
        setGalat(salah);
      })
      .finally(() => {
        if (hidup) setMemuat(false);
      });

    return () => {
      hidup = false;
      kendali.abort();
    };
    // `data` sengaja tidak jadi dependensi: ia cuma dibaca untuk memutuskan apakah layar
    // perlu menampilkan keadaan memuat, dan memasukkannya akan membuat setiap jawaban
    // memicu pengambilan berikutnya tanpa henti.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ambil, penanda]);

  useEffect(() => {
    if (!segarkanBerkala) return;
    const pewaktu = setInterval(muatUlang, jedaSegarkanMilidetik);
    return () => clearInterval(pewaktu);
  }, [segarkanBerkala, muatUlang]);

  return { data, memuat, galat, muatUlang };
}
