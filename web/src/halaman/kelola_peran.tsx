import { useCallback, useEffect, useState, type FormEvent } from 'react';

import { useSesi, usePengguna } from '../auth/sesi';
import { cariPengguna, riwayatPeran, tetapkanPeran } from '../inti/api_admin';
import { formatTanggalJam } from '../inti/format';
import { gunakanMuat } from '../inti/gunakan_muat';
import { gunakanTunda } from '../inti/gunakan_tunda';
import type { Pengguna, Peran } from '../inti/tipe';
import { Kosong, KotakGalat, Memuat, pesanGalat } from '../komponen/keadaan';

/**
 * Kelola peran pengguna: mencari akun, lalu mengubah peran yang dipegangnya.
 *
 * Satu-satunya jalan seseorang bisa menjadi runner atau admin (lihat `AdminPenggunaController`
 * di backend). Endpoint pencarian tidak menyediakan "ambil satu pengguna lewat id", cuma
 * pencarian kata kunci yang mengembalikan larik, jadi layar ini sengaja tidak dibuat sebagai
 * dua rute terpisah (`/pengguna` dan `/pengguna/:id`) seperti pantauan order: itu akan
 * menjanjikan tautan langsung ke satu pengguna yang tidak bisa dipulihkan sesudah dimuat
 * ulang. Pengguna yang sedang dikelola cuma hidup sebagai state di komponen ini, berasal
 * dari baris yang diklik di hasil pencarian.
 */

const PANJANG_KATA_KUNCI_MINIMAL = 3;

const seluruhPeran: Peran[] = ['Klien', 'Runner', 'Admin'];

export function HalamanKelolaPeran() {
  const { api } = useSesi();
  const [kataKunci, setKataKunci] = useState('');
  const kataKunciTertunda = gunakanTunda(kataKunci.trim(), 300);
  const [dipilih, setDipilih] = useState<Pengguna | null>(null);

  const layakDicari = kataKunciTertunda.length >= PANJANG_KATA_KUNCI_MINIMAL;

  const ambil = useCallback(
    (sinyal: AbortSignal) =>
      layakDicari ? cariPengguna(api, kataKunciTertunda, sinyal) : Promise.resolve([]),
    [api, kataKunciTertunda, layakDicari],
  );

  const { data: hasil, memuat, galat, muatUlang } = gunakanMuat(ambil);

  return (
    <section className="kelola-peran">
      <header>
        <h1>Kelola Peran</h1>
      </header>

      <div className="kelola-peran__kolom">
        <div className="kartu">
          <label htmlFor="kataKunci">Cari nama atau nomor HP</label>
          <input
            id="kataKunci"
            type="search"
            value={kataKunci}
            onChange={(e) => setKataKunci(e.target.value)}
            placeholder="Minimal 3 huruf..."
          />

          {kataKunciTertunda.length > 0 && !layakDicari && (
            <p className="kelola-peran__petunjuk">
              Isi minimal {PANJANG_KATA_KUNCI_MINIMAL} huruf dari nama atau nomor HP-nya.
            </p>
          )}

          {galat !== null && <KotakGalat galat={galat} cobaLagi={muatUlang} />}
          {layakDicari && memuat && hasil === null && <Memuat />}
          {layakDicari && hasil !== null && hasil.length === 0 && (
            <Kosong keterangan="Tidak ada akun yang cocok." />
          )}

          {hasil !== null && hasil.length > 0 && (
            <ul className="daftar-pengguna">
              {hasil.map((pengguna) => (
                <li key={pengguna.id}>
                  <button
                    type="button"
                    className={
                      pengguna.id === dipilih?.id
                        ? 'daftar-pengguna__baris daftar-pengguna__baris--aktif'
                        : 'daftar-pengguna__baris'
                    }
                    onClick={() => setDipilih(pengguna)}
                  >
                    <span className="daftar-pengguna__nama">{pengguna.nama}</span>
                    <span className="daftar-pengguna__hp">{pengguna.noHp}</span>
                    <span className="daftar-pengguna__peran">
                      {pengguna.roles.length > 0 ? pengguna.roles.join(', ') : 'tanpa peran'}
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        {dipilih && (
          <PanelPengguna
            key={dipilih.id}
            pengguna={dipilih}
            onBerubah={(diperbarui) => setDipilih(diperbarui)}
          />
        )}
      </div>
    </section>
  );
}

function PanelPengguna({
  pengguna,
  onBerubah,
}: {
  pengguna: Pengguna;
  onBerubah: (diperbarui: Pengguna) => void;
}) {
  const { api } = useSesi();
  const pengirim = usePengguna();

  const [rolesDipilih, setRolesDipilih] = useState<Peran[]>(pengguna.roles);
  const [alasan, setAlasan] = useState('');
  const [sibuk, setSibuk] = useState(false);
  const [galat, setGalat] = useState<unknown>(null);
  const [penandaRiwayat, setPenandaRiwayat] = useState(0);

  // Peran yang ditampilkan mengikuti pengguna yang sedang dipilih, bukan menyisakan
  // pilihan dari akun sebelumnya. Efeknya cuma berjalan saat identitas pengguna berganti
  // (dijaga lewat `key={dipilih.id}` di pemanggilnya), bukan setiap kali objeknya
  // dibangun ulang, jadi tidak menimpa perubahan checkbox yang sedang diketik admin.
  useEffect(() => {
    setRolesDipilih(pengguna.roles);
    setAlasan('');
    setGalat(null);
  }, [pengguna]);

  function tukarPeran(peran: Peran) {
    setRolesDipilih((sebelumnya) =>
      sebelumnya.includes(peran)
        ? sebelumnya.filter((p) => p !== peran)
        : [...sebelumnya, peran],
    );
  }

  const adaPerubahan =
    rolesDipilih.length !== pengguna.roles.length ||
    !rolesDipilih.every((p) => pengguna.roles.includes(p));

  const mengubahDiriSendiri = pengirim?.id === pengguna.id;

  async function simpan(peristiwa: FormEvent) {
    peristiwa.preventDefault();
    setSibuk(true);
    setGalat(null);
    try {
      const diperbarui = await tetapkanPeran(api, pengguna.id, rolesDipilih, alasan.trim());
      onBerubah(diperbarui);
      setAlasan('');
      // Riwayat dimuat ulang lewat penanda, bukan langsung menyisipkan barisnya di sini:
      // baris yang benar (id, waktu server) cuma diketahui setelah diminta ulang, dan
      // menambahkan tebakan sendiri berarti ada dua sumber kebenaran untuk hal yang sama.
      setPenandaRiwayat((n) => n + 1);
    } catch (salah) {
      setGalat(salah);
    } finally {
      setSibuk(false);
    }
  }

  return (
    <div className="kartu kartu--panel-pengguna">
      <h2>{pengguna.nama}</h2>
      <p className="panel-pengguna__hp">{pengguna.noHp}</p>

      <form onSubmit={simpan} className="panel-pengguna__form">
        <fieldset>
          <legend>Peran</legend>
          {seluruhPeran.map((peran) => (
            <label key={peran} className="cek">
              <input
                type="checkbox"
                checked={rolesDipilih.includes(peran)}
                onChange={() => tukarPeran(peran)}
                disabled={sibuk}
              />
              {peran}
            </label>
          ))}
        </fieldset>

        {mengubahDiriSendiri && rolesDipilih.length > 0 && !rolesDipilih.includes('Admin') && (
          <p className="panel-pengguna__peringatan">
            {/* Backend menolak ini (admin tidak boleh mencabut peran adminnya sendiri), tapi
                menunggu penolakan server untuk hal yang sudah pasti ditolak cuma membuang
                satu bolak-balik jaringan. Peringatan ini bukan pengganti penjagaan backend,
                cuma menghindarkan kejutannya. */}
            Ini akun kamu sendiri. Mencabut peran admin dari akun sendiri akan ditolak server.
          </p>
        )}

        <label htmlFor="alasan">Alasan perubahan</label>
        <textarea
          id="alasan"
          rows={2}
          maxLength={2000}
          required
          value={alasan}
          disabled={sibuk}
          onChange={(e) => setAlasan(e.target.value)}
        />

        <button
          type="submit"
          className="tombol"
          disabled={sibuk || !adaPerubahan || alasan.trim().length === 0}
        >
          {sibuk ? 'Menyimpan...' : 'Simpan perubahan peran'}
        </button>
      </form>

      {galat !== null && (
        <p className="keadaan keadaan--galat" role="alert">
          {pesanGalat(galat)}
        </p>
      )}

      <RiwayatPeran userId={pengguna.id} penanda={penandaRiwayat} />
    </div>
  );
}

function RiwayatPeran({ userId, penanda }: { userId: string; penanda: number }) {
  const { api } = useSesi();

  const ambil = useCallback(
    (sinyal: AbortSignal) => riwayatPeran(api, userId, { ukuran: 20 }, sinyal),
    [api, userId],
  );

  const { data, memuat, galat, muatUlang } = gunakanMuat(ambil);

  // Riwayat dimuat ulang setiap `penanda` berubah, yaitu setiap kali perubahan peran baru
  // berhasil disimpan. `muatUlang` sengaja tidak dimasukkan ke daftar dependensi: ia
  // dibuat ulang setiap render oleh gunakanMuat, dan memasukkannya akan memicu pengambilan
  // setiap render, bukan cuma saat penandanya berganti.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (penanda > 0) muatUlang();
  }, [penanda]);

  return (
    <div className="riwayat-peran">
      <h3>Riwayat perubahan</h3>

      {galat !== null && <KotakGalat galat={galat} cobaLagi={muatUlang} />}
      {memuat && data === null && <Memuat />}
      {data !== null && data.isi.length === 0 && (
        <Kosong keterangan="Belum ada perubahan peran untuk akun ini." />
      )}

      {data !== null && data.isi.length > 0 && (
        <ol className="riwayat-peran__daftar">
          {data.isi.map((baris) => (
            <li key={baris.id}>
              <p className="riwayat-peran__perubahan">
                {baris.sebelum.join(', ') || 'tanpa peran'} &rarr;{' '}
                {baris.sesudah.join(', ') || 'tanpa peran'}
              </p>
              <p className="riwayat-peran__alasan">{baris.alasan}</p>
              <time dateTime={baris.diubahPada}>{formatTanggalJam(baris.diubahPada)}</time>
            </li>
          ))}
        </ol>
      )}
    </div>
  );
}
