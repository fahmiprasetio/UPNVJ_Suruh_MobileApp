namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Tarif Jalur A yang sedang berlaku, satu baris untuk seluruh sistem.
/// </summary>
/// <remarks>
/// Dulu ini konstanta di <see cref="Pricing.TarifConfig"/>, ditulis mati di kode dan cuma
/// bisa diubah lewat commit baru. Sekarang admin bisa mengubahnya lewat dashboard, jadi
/// angkanya harus hidup di basis data, bukan di kode.
///
/// Sengaja cuma satu baris, bukan riwayat tarif per tanggal. Order yang sudah dibuat
/// menyimpan harganya sendiri di <see cref="Order.Price"/> (dihitung sekali saat dibuat,
/// tidak pernah dihitung ulang), jadi mengubah baris ini tidak mengubah harga order lama
/// yang sudah berjalan, cuma harga order baru sejak perubahan itu tersimpan. Riwayat siapa
/// mengubah apa kapan tetap ada, lewat <see cref="UpdatedAt"/> dan
/// <see cref="UpdatedByAdminId"/>, tapi cuma perubahan terakhir, bukan seluruh riwayatnya.
///
/// <see cref="Id"/> dipatok ke <see cref="SatuSatunyaId"/> dan disemai sekali lewat migrasi
/// (nilai awalnya persis <see cref="Pricing.TarifConfig"/>, dijaga tetap sama oleh
/// <c>TarifSelarasDenganMobileTests</c>). Tidak ada endpoint yang membuat baris kedua;
/// yang ada cuma membaca dan menimpa baris yang sudah ada.
/// </remarks>
public class TarifSetting
{
    /// <summary>
    /// Id tetap satu-satunya baris ini. Bukan dibangkitkan acak, supaya kode yang membacanya
    /// tidak perlu menebak-nebak baris mana yang "yang aktif" kalau suatu saat ada yang salah
    /// menyisipkan baris kedua.
    /// </summary>
    public static readonly Guid SatuSatunyaId = Guid.Parse("00000000-0000-0000-0000-00000000face");

    public Guid Id { get; set; } = SatuSatunyaId;

    public decimal AnjemTarifDasar { get; set; }
    public decimal AnjemTarifPerKm { get; set; }
    public double AnjemJarakMinimalKm { get; set; }
    public double AnjemJarakMaksimalKm { get; set; }

    public decimal JastipMakananFee { get; set; }

    public decimal JastipBarangFee { get; set; }
    public decimal JastipBarangTarifPerKm { get; set; }

    public DateTime? UpdatedAt { get; set; }
    public Guid? UpdatedByAdminId { get; set; }
}
