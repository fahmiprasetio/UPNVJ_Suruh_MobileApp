namespace UpnvjSuruh.Api.Pricing;

/// <summary>
/// Tarif Jalur A. Kembaran <c>lib/core/config/tarif_config.dart</c> di aplikasi mobile,
/// dan angkanya wajib sama, dijaga tes.
///
/// PERINGATAN: seluruh angka ini masih placeholder. Rencana capstone bagian 14.8 menandai
/// tarif persis Jalur A sebagai pertanyaan pengunci yang jawabannya harus datang dari mitra.
/// </summary>
public static class TarifConfig
{
    public const decimal AnjemTarifDasar = 5000m;
    public const decimal AnjemTarifPerKm = 2000m;
    public const double AnjemJarakMinimalKm = 0.5;
    public const double AnjemJarakMaksimalKm = 15;

    public const decimal JastipMakananFee = 8000m;

    public const decimal JastipBarangFee = 10000m;
    public const decimal JastipBarangTarifPerKm = 2000m;

    public static readonly TimeSpan BatasWaktuBayar = TimeSpan.FromMinutes(30);
}
