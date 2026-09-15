using UpnvjSuruh.Api.Auth;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Satu-satunya logika bercabang di <see cref="PengirimOtpWhatsapp"/>: menerjemahkan nomor
/// format lokal yang tersimpan di basis data ke format yang diminta WhatsApp Cloud API.
/// Salah di sini berarti OTP berangkat ke nomor yang salah tanpa satu pun galat terlihat.
/// </summary>
public class PengirimOtpWhatsappTests
{
    [Theory]
    [InlineData("081234567890", "6281234567890")]
    [InlineData("+6281234567890", "6281234567890")]
    [InlineData("6281234567890", "6281234567890")]
    public void NormalisasiNomorWhatsapp_MenghasilkanFormatBerkodeNegara(
        string masukan,
        string diharapkan
    )
    {
        var hasil = PengirimOtpWhatsapp.NormalisasiNomorWhatsapp(masukan);

        Assert.Equal(diharapkan, hasil);
    }

    [Theory]
    [InlineData("081234567890", "0812******90")]
    [InlineData("6281234567890", "6281*******90")]
    [InlineData("0812", "****")]
    public void Samarkan_MenyisakanEmpatAngkaDepanDanDuaBelakang(string masukan, string diharapkan)
    {
        var hasil = PengirimOtpWhatsapp.Samarkan(masukan);

        Assert.Equal(diharapkan, hasil);
    }

    /// <summary>
    /// Twilio menyebut nomor tujuan di dalam pesan galatnya sendiri, jadi menyamarkan nomor
    /// di kalimat log saja masih menyisakannya utuh di bagian yang disalin dari penyedia.
    /// Tes ini yang gagal kalau penyamaran itu dilepas belakangan.
    /// </summary>
    [Theory]
    [InlineData("whatsapp:+6281234567890 is not a valid phone number")]
    [InlineData("To=6281234567890 ditolak")]
    [InlineData("nomor 081234567890 belum join sandbox")]
    public void SamarkanNomorDi_MembuangSeluruhBentukNomorDariIsiJawaban(string teksGalat)
    {
        const string noHp = "081234567890";

        var hasil = PengirimOtpWhatsapp.SamarkanNomorDi(teksGalat, noHp);

        Assert.DoesNotContain("081234567890", hasil, StringComparison.Ordinal);
        Assert.DoesNotContain("6281234567890", hasil, StringComparison.Ordinal);
        Assert.Contains(PengirimOtpWhatsapp.Samarkan(noHp), hasil, StringComparison.Ordinal);
    }

    /// <summary>
    /// Sisa kalimat galat penyedia adalah satu-satunya petunjuk kenapa kodenya tidak sampai.
    /// Penyamaran yang ikut memakan kalimatnya menukar satu masalah dengan masalah lain.
    /// </summary>
    [Fact]
    public void SamarkanNomorDi_MembiarkanSisaPesanGalatnyaUtuh()
    {
        var hasil = PengirimOtpWhatsapp.SamarkanNomorDi(
            "Twilio 21211: whatsapp:+6281234567890 is not a valid phone number",
            "081234567890"
        );

        Assert.Contains("Twilio 21211:", hasil, StringComparison.Ordinal);
        Assert.Contains("is not a valid phone number", hasil, StringComparison.Ordinal);
    }
}
