import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react';

import { useSesi } from '../auth/sesi';
import { ambilTarif, perbaruiTarif } from '../inti/api_admin';
import { formatTanggalJam } from '../inti/format';
import { buatIdempotencyKey } from '../inti/idempotensi';
import { gunakanMuat } from '../inti/gunakan_muat';
import type { Tarif } from '../inti/tipe';
import { KotakGalat, Memuat, pesanGalat } from '../komponen/keadaan';

/**
 * Kelola tarif Jalur A: satu form, seluruh angka dikirim sekaligus.
 *
 * Mengubah baris ini tidak mengubah harga order yang sudah dibuat — order menyimpan
 * harganya sendiri, dihitung sekali saat dibuat (lihat `Order.Price` di backend). Yang
 * berubah cuma order Jalur A berikutnya. Itu ditulis terang-terangan di layar, bukan
 * dianggap sudah jelas dengan sendirinya: admin yang baru menaikkan tarif dan bingung
 * kenapa order kemarin masih memakai angka lama butuh jawabannya di sini, bukan di
 * catatan kode yang tidak pernah ia baca.
 */
export function HalamanKelolaTarif() {
  const { api } = useSesi();

  const ambil = useCallback((sinyal: AbortSignal) => ambilTarif(api, sinyal), [api]);
  const { data: tarif, memuat, galat, muatUlang } = gunakanMuat(ambil);

  return (
    <section className="kelola-tarif">
      <header>
        <h1>Kelola Tarif</h1>
        <p className="kelola-tarif__keterangan">
          Enam layanan utama memakai tarif Jalur A. Hanya Permintaan Lain yang memakai
          tawar-menawar Jalur B dan tidak diatur dari sini.
        </p>
      </header>

      {galat !== null && <KotakGalat galat={galat} cobaLagi={muatUlang} />}
      {memuat && tarif === null && <Memuat />}
      {tarif !== null && <FormTarif key={tarif.diubahPada ?? 'awal'} tarif={tarif} onDisimpan={muatUlang} />}
    </section>
  );
}

function FormTarif({ tarif, onDisimpan }: { tarif: Tarif; onDisimpan: () => void }) {
  const { api } = useSesi();

  const [nilai, setNilai] = useState(tarif);
  const [sibuk, setSibuk] = useState(false);
  const [galat, setGalat] = useState<unknown>(null);
  const [tersimpan, setTersimpan] = useState(false);
  const key = useRef(buatIdempotencyKey());

  // Form ikut mengikuti tarif yang baru dimuat ulang (dipicu `key` di pemanggil saat
  // `diubahPada` berganti sesudah disimpan), bukan menyisakan angka lama di layar.
  useEffect(() => {
    setNilai(tarif);
  }, [tarif]);

  function ubah(kolom: keyof Omit<Tarif, 'diubahPada'>, teks: string) {
    const angka = Number(teks);
    setNilai((sebelumnya) => ({ ...sebelumnya, [kolom]: Number.isFinite(angka) ? angka : 0 }));
    setTersimpan(false);
  }

  async function simpan(peristiwa: FormEvent) {
    peristiwa.preventDefault();
    setSibuk(true);
    setGalat(null);
    setTersimpan(false);
    try {
      const { diubahPada: _diubahPada, ...badan } = nilai;
      await perbaruiTarif(api, badan, key.current);
      key.current = buatIdempotencyKey();
      setTersimpan(true);
      onDisimpan();
    } catch (salah) {
      setGalat(salah);
    } finally {
      setSibuk(false);
    }
  }

  return (
    <form className="kartu kelola-tarif__form" onSubmit={simpan}>
      <fieldset>
        <legend>Anter Jemput</legend>
        <Kolom
          label="Tarif dasar (Rp)"
          nilai={nilai.anjemTarifDasar}
          disabled={sibuk}
          onChange={(t) => ubah('anjemTarifDasar', t)}
        />
        <Kolom
          label="Tarif per km (Rp)"
          nilai={nilai.anjemTarifPerKm}
          disabled={sibuk}
          onChange={(t) => ubah('anjemTarifPerKm', t)}
        />
        <Kolom
          label="Jarak minimal (km)"
          nilai={nilai.anjemJarakMinimalKm}
          disabled={sibuk}
          step="0.1"
          onChange={(t) => ubah('anjemJarakMinimalKm', t)}
        />
        <Kolom
          label="Jarak maksimal (km)"
          nilai={nilai.anjemJarakMaksimalKm}
          disabled={sibuk}
          step="0.1"
          onChange={(t) => ubah('anjemJarakMaksimalKm', t)}
        />
      </fieldset>

      <fieldset>
        <legend>Jastip Makanan</legend>
        <Kolom
          label="Ongkos jasa titip (Rp)"
          nilai={nilai.jastipMakananFee}
          disabled={sibuk}
          onChange={(t) => ubah('jastipMakananFee', t)}
        />
      </fieldset>

      <fieldset>
        <legend>Jastip Barang</legend>
        <p className="kelola-tarif__catatan">
          {/* Batasan yang harus dikatakan, bukan dianggap sudah jelas: jarak minimal dan
              maksimalnya memakai angka Anter Jemput di atas, bukan angka sendiri. Mitra
              belum memberi batas terpisah untuk jastip barang. */}
          Jarak minimal dan maksimalnya memakai angka Anter Jemput di atas.
        </p>
        <Kolom
          label="Ongkos jasa titip (Rp)"
          nilai={nilai.jastipBarangFee}
          disabled={sibuk}
          onChange={(t) => ubah('jastipBarangFee', t)}
        />
        <Kolom
          label="Tarif per km (Rp)"
          nilai={nilai.jastipBarangTarifPerKm}
          disabled={sibuk}
          onChange={(t) => ubah('jastipBarangTarifPerKm', t)}
        />
      </fieldset>

      <fieldset>
        <legend>Bantu Pindah Kos</legend>
        <p className="kelola-tarif__catatan">
          Jarak minimal dan maksimal memakai batas Anter Jemput. Runner menyediakan kendaraan.
        </p>
        <Kolom label="Tarif dasar (Rp)" nilai={nilai.pindahKosTarifDasar} disabled={sibuk} onChange={(t) => ubah('pindahKosTarifDasar', t)} />
        <Kolom label="Tarif per km (Rp)" nilai={nilai.pindahKosTarifPerKm} disabled={sibuk} onChange={(t) => ubah('pindahKosTarifPerKm', t)} />
        <Kolom label="Tambahan per runner (Rp)" nilai={nilai.pindahKosTambahanRunner} disabled={sibuk} onChange={(t) => ubah('pindahKosTambahanRunner', t)} />
        <Kolom label="Tambahan mobil (Rp)" nilai={nilai.pindahKosTambahanMobil} disabled={sibuk} onChange={(t) => ubah('pindahKosTambahanMobil', t)} />
        <Kolom label="Tambahan pickup (Rp)" nilai={nilai.pindahKosTambahanPickup} disabled={sibuk} onChange={(t) => ubah('pindahKosTambahanPickup', t)} />
      </fieldset>

      <fieldset>
        <legend>Bersih-Bersih Kos</legend>
        <Kolom label="Tarif jasa (Rp)" nilai={nilai.bersihKosFee} disabled={sibuk} onChange={(t) => ubah('bersihKosFee', t)} />
      </fieldset>

      <fieldset>
        <legend>Bersih Kamar Mandi</legend>
        <Kolom label="Tarif jasa (Rp)" nilai={nilai.bersihKamarMandiFee} disabled={sibuk} onChange={(t) => ubah('bersihKamarMandiFee', t)} />
      </fieldset>

      <div className="kelola-tarif__kaki">
        <p className="kelola-tarif__diubah">
          {tarif.diubahPada
            ? `Terakhir diubah ${formatTanggalJam(tarif.diubahPada)}`
            : 'Belum pernah diubah sejak dipasang'}
        </p>
        <button type="submit" className="tombol" disabled={sibuk}>
          {sibuk ? 'Menyimpan...' : 'Simpan tarif'}
        </button>
      </div>

      {tersimpan && !sibuk && galat === null && (
        <p className="kelola-tarif__berhasil" role="status">
          Tersimpan. Order Jalur A berikutnya memakai tarif ini; order yang sudah ada
          tidak berubah.
        </p>
      )}

      {galat !== null && (
        <p className="keadaan keadaan--galat" role="alert">
          {pesanGalat(galat)}
        </p>
      )}
    </form>
  );
}

function Kolom({
  label,
  nilai,
  disabled,
  step = '1',
  onChange,
}: {
  label: string;
  nilai: number;
  disabled: boolean;
  step?: string;
  onChange: (teks: string) => void;
}) {
  return (
    <label className="kelola-tarif__kolom">
      <span>{label}</span>
      <input
        type="number"
        inputMode="decimal"
        min="0"
        step={step}
        required
        value={nilai}
        disabled={disabled}
        onChange={(e) => onChange(e.target.value)}
      />
    </label>
  );
}
