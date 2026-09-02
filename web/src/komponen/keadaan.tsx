import { GalatApi, GalatJaringan, GalatServer } from '../inti/galat_api';

/**
 * Tiga keadaan yang dimiliki setiap layar yang mengambil data: sedang memuat, gagal, dan
 * berhasil tapi kosong.
 *
 * Dikumpulkan jadi komponen bersama supaya ketiganya benar-benar ada di semua layar. Yang
 * paling sering hilang adalah yang ketiga: daftar kosong yang digambar sebagai tabel tanpa
 * baris tidak bisa dibedakan dari daftar yang gagal dimuat, dan admin akan menunggu sesuatu
 * yang tidak akan pernah muncul.
 */

export function Memuat({ keterangan = 'Memuat...' }: { keterangan?: string }) {
  return (
    <p className="keadaan keadaan--memuat" role="status">
      {keterangan}
    </p>
  );
}

export function Kosong({ keterangan }: { keterangan: string }) {
  return <p className="keadaan keadaan--kosong">{keterangan}</p>;
}

/**
 * Galat, beserta tombol coba lagi yang cuma muncul kalau mencoba lagi memang masuk akal.
 *
 * Tombol yang selalu ada pada galat apa pun adalah kebohongan kecil yang mahal: untuk
 * kata kunci yang terlalu pendek atau akses yang memang tidak diizinkan, menekannya
 * berkali-kali tidak akan pernah mengubah apa pun, dan orangnya menyalahkan jaringan.
 */
export function KotakGalat({ galat, cobaLagi }: { galat: unknown; cobaLagi?: () => void }) {
  const bolehCobaLagi =
    cobaLagi !== undefined && (galat instanceof GalatJaringan || galat instanceof GalatServer);

  return (
    <div className="keadaan keadaan--galat" role="alert">
      <p>{pesanGalat(galat)}</p>
      {bolehCobaLagi && (
        <button type="button" onClick={cobaLagi}>
          Coba lagi
        </button>
      )}
    </div>
  );
}

/**
 * Kalimat yang layak ditampilkan apa adanya.
 *
 * Galat yang bukan GalatApi berarti bug di dashboard ini, bukan jawaban server. Pesannya
 * tidak ditampilkan karena isinya nama variabel dan jejak kode, yang tidak menolong
 * siapa pun yang sedang memantau order.
 */
export function pesanGalat(galat: unknown): string {
  if (galat instanceof GalatApi) return galat.message;
  return 'Ada yang salah di dashboard ini. Muat ulang halamannya.';
}
