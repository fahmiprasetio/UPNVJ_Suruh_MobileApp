import type { FormEvent, ReactNode } from 'react';

import { pesanGalat } from './keadaan';

/**
 * Markup form "tulis alasan lalu kirim", dipasangkan dengan `gunakanPanelKonfirmasi`
 * (lihat `inti/gunakan_panel_konfirmasi.ts`) di ketiga panel yang memakainya. Cuma
 * dirender selagi panelnya terbuka; tombol pembukanya sendiri tetap milik masing-masing
 * pemanggil, karena teks dan konteks di sekitarnya berbeda-beda.
 */
export function FormAlasan({
  idAlasan,
  labelAlasan,
  alasan,
  onUbahAlasan,
  maxPanjangAlasan,
  placeholderAlasan,
  sibuk,
  labelKirim,
  labelSedangKirim,
  onKirim,
  onUrungkan,
  galat,
  catatanBawah,
}: {
  idAlasan: string;
  labelAlasan: string;
  alasan: string;
  onUbahAlasan: (nilai: string) => void;
  maxPanjangAlasan: number;
  placeholderAlasan: string;
  sibuk: boolean;
  labelKirim: string;
  labelSedangKirim: string;
  onKirim: (peristiwa: FormEvent) => void;
  onUrungkan: () => void;
  galat: unknown;
  /** Kalimat tambahan sebelum galat, misal ke mana alasannya pergi atau peringatan efeknya. */
  catatanBawah?: ReactNode;
}) {
  return (
    <form onSubmit={onKirim}>
      <label htmlFor={idAlasan}>{labelAlasan}</label>
      <textarea
        id={idAlasan}
        rows={2}
        maxLength={maxPanjangAlasan}
        required
        autoFocus
        value={alasan}
        disabled={sibuk}
        placeholder={placeholderAlasan}
        onChange={(e) => onUbahAlasan(e.target.value)}
      />
      <div className="pembatalan__tombol">
        <button type="submit" className="tombol" disabled={sibuk || alasan.trim().length === 0}>
          {sibuk ? labelSedangKirim : labelKirim}
        </button>
        <button
          type="button"
          className="tombol tombol--halus"
          disabled={sibuk}
          onClick={onUrungkan}
        >
          Urungkan
        </button>
      </div>
      {catatanBawah}
      {galat !== null && (
        <p className="keadaan keadaan--galat" role="alert">
          {pesanGalat(galat)}
        </p>
      )}
    </form>
  );
}
