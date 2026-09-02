import { labelStatus } from '../inti/format';
import type { Jalur, StatusOrder } from '../inti/tipe';

/**
 * Status order sebagai lencana berwarna.
 *
 * Warnanya mengikuti dua aturan yang sudah ditetapkan DESIGN.md untuk seluruh sistem ini,
 * bukan dipilih ulang di sini:
 *
 * - "Green states, maroon acts": hijau menceritakan keadaan, maroon meminta tindakan.
 * - "Red means one thing, that something is owed": merah cuma untuk utang, dan
 *   `MencariRunner` sengaja dipindahkan dari merah ke hijau di aturan itu supaya merah
 *   tidak kehilangan artinya.
 *
 * Karena itu cuma `MenungguPembayaran` yang merah di sini: itu satu-satunya keadaan yang
 * artinya ada yang belum dibayar. Order yang macet di `MencariRunner` memang lebih genting
 * bagi organisasi, tapi kegentingannya disampaikan lewat tanda "macet" di sebelahnya, bukan
 * dengan mengambil warna yang sudah punya arti lain.
 *
 * Warna tidak pernah jadi satu-satunya penanda: tulisannya tetap menyebut statusnya.
 */
export function LencanaStatus({ status }: { status: StatusOrder }) {
  return <span className={'lencana lencana--' + nada(status)}>{labelStatus(status)}</span>;
}

export function LencanaJalur({ jalur }: { jalur: Jalur }) {
  return (
    <span className="lencana lencana--jalur" title={keteranganJalur(jalur)}>
      {jalur === 'JalurA' ? 'Jalur A' : 'Jalur B'}
    </span>
  );
}

type Nada = 'utang' | 'proses' | 'jalan' | 'selesai' | 'akhir';

function nada(status: StatusOrder): Nada {
  switch (status) {
    case 'MenungguPembayaran':
      return 'utang';
    case 'Permintaan':
    case 'MenungguPersetujuanKlien':
    case 'MencariRunner':
      return 'proses';
    case 'Dikerjakan':
      return 'jalan';
    case 'Selesai':
      return 'selesai';
    case 'Batal':
      return 'akhir';
  }
}

function keteranganJalur(jalur: Jalur): string {
  return jalur === 'JalurA'
    ? 'Harga dihitung server dari isian klien, langsung ke pembayaran.'
    : 'Harga lewat tawar-menawar: runner mengajukan, klien memilih.';
}
