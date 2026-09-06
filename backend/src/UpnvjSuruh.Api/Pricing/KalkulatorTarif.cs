using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Pricing;

/// <summary>
/// Menghitung harga Jalur A di server.
///
/// Aplikasi punya kalkulator yang sama supaya klien melihat rinciannya sebelum memesan,
/// tapi angka itu tidak pernah dipercaya. Yang mengikat adalah hasil hitungan di sini.
/// Server yang menerima harga jadi dari badan permintaan berarti siapa pun bisa memesan
/// seharga satu rupiah, dan yang seperti itu tidak ketahuan sampai uangnya dihitung.
///
/// Yang diterima dari klien cuma jaraknya, dan itu pun dijepit ke rentang yang wajar.
/// Jarak diisi sendiri karena alamatnya teks bebas, bukan pin peta (bagian 14.8), jadi
/// tanpa peta sistem memang tidak punya cara menghitungnya sendiri.
///
/// <see cref="TarifSetting"/> diterima sebagai parameter, bukan dibaca dari konstanta
/// statis: angkanya sekarang bisa diubah admin lewat dashboard, dan kalkulator ini tetap
/// murni dan gampang diuji kalau tidak perlu tahu dari mana angkanya datang. Tidak ada
/// nilai bawaan untuk parameter ini dengan sengaja — pemanggil yang lupa memuat tarif
/// sekarang dari basis data akan gagal saat kompilasi, bukan diam-diam menghitung dengan
/// angka yang salah.
/// </summary>
public class KalkulatorTarif
{
    public HasilTarif Hitung(ServiceType serviceType, double? jarakKm, TarifSetting tarif)
    {
        if (serviceType.Track() != OrderTrack.JalurA)
        {
            throw new ArgumentException(
                $"{serviceType} adalah Jalur B, harganya ditentukan admin lewat penawaran.",
                nameof(serviceType));
        }

        return serviceType switch
        {
            ServiceType.AnterJemput => AnterJemput(WajibJarak(serviceType, jarakKm), tarif),
            ServiceType.JastipBarang => JastipBarang(WajibJarak(serviceType, jarakKm), tarif),
            ServiceType.JastipMakanan => JastipMakanan(tarif),
            _ => throw new ArgumentOutOfRangeException(nameof(serviceType), serviceType, null),
        };
    }

    private static double WajibJarak(ServiceType serviceType, double? jarakKm)
    {
        if (jarakKm is null)
        {
            throw new ArgumentException($"{serviceType} butuh jarak untuk dihitung.", nameof(jarakKm));
        }

        if (double.IsNaN(jarakKm.Value) || double.IsInfinity(jarakKm.Value))
        {
            throw new ArgumentException("Jarak bukan angka yang sah.", nameof(jarakKm));
        }

        return jarakKm.Value;
    }

    private static HasilTarif AnterJemput(double jarakDiminta, TarifSetting tarif)
    {
        // Dijepit, bukan ditolak. Jarak di bawah minimal tetap order yang wajar, dan jarak
        // di atas maksimal sudah di luar wilayah layanan sehingga ditagih pada batasnya
        // lalu diselesaikan admin. Yang penting angka apa pun yang dikirim tidak bisa
        // membuat harganya nol atau meledak.
        var jarakDipakai = Math.Clamp(jarakDiminta, tarif.AnjemJarakMinimalKm, tarif.AnjemJarakMaksimalKm);
        var ongkosJarak = Math.Round((decimal)jarakDipakai * tarif.AnjemTarifPerKm, MidpointRounding.AwayFromZero);

        return new HasilTarif(
            [
                new RincianTarif("Tarif dasar", tarif.AnjemTarifDasar),
                new RincianTarif($"Jarak {FormatJarak(jarakDipakai)} km", ongkosJarak),
            ],
            tarif.AnjemTarifDasar + ongkosJarak);
    }

    private static HasilTarif JastipBarang(double jarakDiminta, TarifSetting tarif)
    {
        // Batas jarak jastip barang sengaja memakai batas anter jemput yang sama, mengikuti
        // KalkulatorTarif.jastipBarang di aplikasi mobile: mitra belum memberi angka batas
        // sendiri untuk jastip (rencana bagian 14.7a).
        var jarakDipakai = Math.Clamp(jarakDiminta, tarif.AnjemJarakMinimalKm, tarif.AnjemJarakMaksimalKm);
        var ongkosJarak = Math.Round((decimal)jarakDipakai * tarif.JastipBarangTarifPerKm, MidpointRounding.AwayFromZero);

        return new HasilTarif(
            [
                new RincianTarif("Ongkos jasa titip", tarif.JastipBarangFee),
                new RincianTarif($"Jarak {FormatJarak(jarakDipakai)} km", ongkosJarak),
            ],
            tarif.JastipBarangFee + ongkosJarak);
    }

    private static HasilTarif JastipMakanan(TarifSetting tarif) =>
        new([new RincianTarif("Ongkos jasa titip", tarif.JastipMakananFee)], tarif.JastipMakananFee);

    private static string FormatJarak(double jarak) =>
        jarak == Math.Round(jarak)
            ? jarak.ToString("0")
            : jarak.ToString("0.0").Replace('.', ',');
}
