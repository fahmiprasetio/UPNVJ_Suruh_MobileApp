import { useEffect, useState } from 'react';

/**
 * Nilai yang baru berubah sesudah pengetikan berhenti sejenak.
 *
 * Dipakai di pencarian pengguna: backend menolak kata kunci di bawah 3 huruf, dan tanpa
 * tundaan ini setiap huruf yang diketik akan mengirim satu permintaan yang hampir pasti
 * ditolak sebelum hurufnya lengkap.
 */
export function gunakanTunda<T>(nilai: T, jedaMilidetik: number): T {
  const [tertunda, setTertunda] = useState(nilai);

  useEffect(() => {
    const pewaktu = setTimeout(() => setTertunda(nilai), jedaMilidetik);
    return () => clearTimeout(pewaktu);
  }, [nilai, jedaMilidetik]);

  return tertunda;
}
