using System.ComponentModel.DataAnnotations;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Contracts;

/// <summary>
/// Tarif Jalur A yang sedang berlaku.
/// </summary>
/// <remarks>
/// Dibaca siapa pun yang sudah masuk (klien untuk pratinjau harga, admin untuk mengisi
/// form sebelum mengubahnya), bukan cuma admin. Angka tarif bukan data rahasia; yang
/// rahasia justru kalau klien tidak tahu berapa yang akan ditagih sebelum menekan pesan.
/// </remarks>
public record TarifResponse(
    decimal AnjemTarifDasar,
    decimal AnjemTarifPerKm,
    double AnjemJarakMinimalKm,
    double AnjemJarakMaksimalKm,
    decimal JastipMakananFee,
    decimal JastipBarangFee,
    decimal JastipBarangTarifPerKm,
    DateTime? DiubahPada)
{
    public static TarifResponse Dari(TarifSetting t) => new(
        t.AnjemTarifDasar,
        t.AnjemTarifPerKm,
        t.AnjemJarakMinimalKm,
        t.AnjemJarakMaksimalKm,
        t.JastipMakananFee,
        t.JastipBarangFee,
        t.JastipBarangTarifPerKm,
        t.UpdatedAt);
}

/// <summary>
/// Admin mengubah tarif Jalur A.
/// </summary>
/// <remarks>
/// Seluruh tujuh angka dikirim sekaligus, bukan satu per satu: layar admin menampilkan
/// keadaan sekarang lalu mengirim keadaan yang diinginkan, sama seperti
/// <see cref="TetapkanPeranRequest"/>. Batas atasnya sengaja longgar tapi tetap ada — tanpa
/// batas, satu salah ketik (menambah nol) membuat setiap order Jalur A berikutnya ditagih
/// jutaan rupiah sampai ada yang menyadarinya.
/// </remarks>
public record PerbaruiTarifRequest : IValidatableObject
{
    [Range(1, 10_000_000)]
    public decimal AnjemTarifDasar { get; init; }

    [Range(0, 100_000)]
    public decimal AnjemTarifPerKm { get; init; }

    [Range(0, 100)]
    public double AnjemJarakMinimalKm { get; init; }

    [Range(0.1, 1000)]
    public double AnjemJarakMaksimalKm { get; init; }

    [Range(1, 10_000_000)]
    public decimal JastipMakananFee { get; init; }

    [Range(1, 10_000_000)]
    public decimal JastipBarangFee { get; init; }

    [Range(0, 100_000)]
    public decimal JastipBarangTarifPerKm { get; init; }

    /// <summary>
    /// Batas bawah harus lebih kecil dari batas atas. <c>[Range]</c> memeriksa tiap kolom
    /// sendiri-sendiri dan tidak bisa membandingkan dua kolom, jadi pemeriksaannya menyusul
    /// di sini. Tanpa ini, jarak minimal yang salah ketik lebih besar dari jarak maksimal
    /// membuat <see cref="Math.Clamp{T}(T, T, T)"/> di <c>KalkulatorTarif</c> melempar
    /// <c>ArgumentException</c> untuk setiap order Jalur A berikutnya, bukan cuma ditolak
    /// sekali di sini saat admin menyimpannya.
    /// </summary>
    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (AnjemJarakMinimalKm >= AnjemJarakMaksimalKm)
        {
            yield return new ValidationResult(
                "Jarak minimal harus lebih kecil dari jarak maksimal.",
                [nameof(AnjemJarakMinimalKm), nameof(AnjemJarakMaksimalKm)]);
        }
    }
}
