namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Rumus bagi hasil runner vs organisasi yang sedang berlaku, satu baris untuk seluruh
/// sistem.
/// </summary>
/// <remarks>
/// ## Kenapa angkanya tidak ditulis di kode
///
/// Rumus bagi hasil adalah satu dari delapan pertanyaan pengunci ke mitra (rencana capstone
/// bagian 14.8), dan sampai sekarang belum dijawab. Selama ini itu dicatat sebagai alasan
/// rekap pembayaran runner belum bisa dikerjakan sama sekali.
///
/// Itu ternyata bukan penghalang yang sebenarnya. Yang tidak diketahui cuma <em>angkanya</em>,
/// bukan bentuk fiturnya, dan angka yang belum diketahui justru tidak boleh ditulis di kode
/// sekalipun sudah diketahui — persis pelajaran dari tarif Jalur A, yang sempat hidup sebagai
/// konstanta kompilasi sampai admin perlu mengubahnya. Jadi angkanya tinggal di sini, diisi
/// admin lewat dashboard, dan yang menunggu mitra tinggal satu kali pengisian form, bukan
/// satu fitur utuh.
///
/// ## Keadaan "belum diatur" adalah keadaan yang sah
///
/// <see cref="DiaturPada"/> bernilai null selama belum ada admin yang mengisinya, dan itu
/// dibedakan dengan tegas dari "diatur ke nol persen". Selama masih null, order yang selesai
/// tidak dihitung bayarannya sama sekali (<see cref="OrderRunnerAssignment.PayoutAmount"/>
/// tetap null), bukan dihitung memakai nol.
///
/// Bedanya bukan soal rapi-rapian: bayaran yang diam-diam dibekukan sebagai nol tidak bisa
/// dibedakan lagi dari bayaran yang memang nol, dan runner yang mengerjakan order selama masa
/// itu akan kehilangan haknya tanpa ada yang menyadarinya. Yang null menunggu; begitu admin
/// menyimpan rumusnya pertama kali, yang menunggu itu ikut dihitung (lihat
/// <c>AdminPayoutController.PerbaruiSetting</c>).
///
/// ## Sengaja satu baris, bukan riwayat rumus per tanggal
///
/// Sama seperti <see cref="TarifSetting"/>: bayaran yang sudah dihitung dibekukan di
/// <see cref="OrderRunnerAssignment.PayoutAmount"/> masing-masing dan tidak pernah dihitung
/// ulang, jadi mengubah baris ini tidak mengutak-atik bayaran yang sudah terlanjur dijanjikan
/// ke runner. Yang berubah cuma order yang selesai sesudahnya.
/// </remarks>
public class PayoutSetting
{
    /// <summary>
    /// Id tetap satu-satunya baris ini, mengikuti pola <see cref="TarifSetting.SatuSatunyaId"/>:
    /// yang membacanya tidak perlu menebak baris mana yang "sedang berlaku" kalau suatu saat
    /// ada yang salah menyisipkan baris kedua.
    /// </summary>
    public static readonly Guid SatuSatunyaId = Guid.Parse("00000000-0000-0000-0000-00000000ba91");

    public Guid Id { get; set; } = SatuSatunyaId;

    /// <summary>Bentuk potongan organisasi: persen dari harga, atau rupiah tetap per order.</summary>
    public ModeKomisi Mode { get; set; } = ModeKomisi.Persen;

    /// <summary>Persen yang diambil organisasi kalau <see cref="Mode"/> adalah persen. 0 sampai 100.</summary>
    public decimal KomisiPersen { get; set; }

    /// <summary>Rupiah yang diambil organisasi tiap order kalau <see cref="Mode"/> adalah tetap.</summary>
    public decimal KomisiTetap { get; set; }

    /// <summary>
    /// Kapan rumusnya terakhir disimpan admin, dan null selama belum pernah sama sekali.
    ///
    /// Nilai null-nya bukan sekadar keterangan: itulah yang membedakan "belum diatur" dari
    /// "diatur ke nol", dan yang menahan perhitungan bayaran supaya tidak membekukan angka
    /// yang belum berhak dibekukan.
    /// </summary>
    public DateTime? DiaturPada { get; set; }

    public Guid? DiaturOlehAdminId { get; set; }

    /// <summary>Benar kalau rumusnya sudah pernah disimpan admin, jadi bayaran boleh dihitung.</summary>
    public bool SudahDiatur => DiaturPada is not null;
}
