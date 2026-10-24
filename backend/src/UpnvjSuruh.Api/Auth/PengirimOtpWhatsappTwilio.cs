using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace UpnvjSuruh.Api.Auth;

/// <summary>
/// Pengirim OTP lewat WhatsApp Sandbox Twilio -- jalur alternatif dari
/// <see cref="PengirimOtpWhatsapp"/> (Meta Cloud API), dipilih di Program.cs kalau
/// "Whatsapp:Twilio:AccountSid" yang terisi.
///
/// Sandbox Twilio menyediakan template Verification Codes untuk pesan yang dimulai aplikasi.
/// Nomor tujuan harus lebih dulu mengirim "join &lt;kode-sandbox&gt;" ke nomor sandbox dari
/// WhatsApp-nya sendiri. Keanggotaan sandbox berakhir setelah tiga hari.
/// </summary>
public class PengirimOtpWhatsappTwilio(
    HttpClient http,
    IConfiguration konfigurasi,
    ILogger<PengirimOtpWhatsappTwilio> log
) : IPengirimOtp
{
    public async Task KirimAsync(string noHp, string kode, CancellationToken batal = default)
    {
        var accountSid = konfigurasi["Whatsapp:Twilio:AccountSid"];
        var nomorPengirim = konfigurasi["Whatsapp:Twilio:NomorPengirim"];
        var contentSidSandbox = konfigurasi["Whatsapp:Twilio:SandboxContentSid"];

        var isi = new FormUrlEncodedContent(
            BuatParameterPesan(nomorPengirim, noHp, kode, contentSidSandbox)
        );

        var jawaban = await http.PostAsync(
            $"/2010-04-01/Accounts/{accountSid}/Messages.json",
            isi,
            batal
        );

        if (!jawaban.IsSuccessStatusCode)
        {
            var teksGalat = await jawaban.Content.ReadAsStringAsync(batal);
            // Dicatat, tidak dilempar: kegagalan penyedia pihak ketiga tidak boleh bocor
            // sebagai galat mentah ke layar orang yang sedang menunggu kodenya.
            //
            // Nomornya disamarkan, termasuk di dalam isi galat Twilio, yang menyebut nomor
            // tujuannya sendiri di beberapa pesannya. Lihat PengirimOtpWhatsapp.Samarkan.
            log.LogError(
                "Gagal mengirim OTP WhatsApp (Twilio) ke {NoHp}: {Status} {Isi}",
                PengirimOtpWhatsapp.Samarkan(noHp),
                jawaban.StatusCode,
                PengirimOtpWhatsapp.SamarkanNomorDi(teksGalat, noHp)
            );
        }
    }

    /// <summary>
    /// Twilio memakai autentikasi HTTP Basic dengan Account SID sebagai pengguna dan Auth
    /// Token sebagai sandi -- dipasang sekali saat registrasi klien di Program.cs, bukan di
    /// sini, supaya kelas ini tidak perlu tahu dari mana kredensialnya berasal.
    /// </summary>
    public static AuthenticationHeaderValue BuatHeaderOtorisasi(string accountSid, string authToken)
    {
        var gabungan = Convert.ToBase64String(Encoding.ASCII.GetBytes($"{accountSid}:{authToken}"));
        return new AuthenticationHeaderValue("Basic", gabungan);
    }

    /// <summary>
    /// Sandbox hanya mengizinkan pesan bebas selama 24 jam setelah pengguna menghubunginya.
    /// Content SID template "Verification Codes" membuat OTP tetap dapat dikirim setelah
    /// jendela itu; SID-nya tersedia di Twilio Console setelah sandbox diaktifkan.
    /// </summary>
    public static Dictionary<string, string> BuatParameterPesan(
        string? nomorPengirim,
        string noHp,
        string kode,
        string? contentSidSandbox
    )
    {
        var parameter = new Dictionary<string, string>
        {
            ["From"] = $"whatsapp:{nomorPengirim}",
            ["To"] = $"whatsapp:+{PengirimOtpWhatsapp.NormalisasiNomorWhatsapp(noHp)}",
        };

        if (!string.IsNullOrWhiteSpace(contentSidSandbox))
        {
            parameter["ContentSid"] = contentSidSandbox;
            parameter["ContentVariables"] = JsonSerializer.Serialize(
                new Dictionary<string, string> { ["1"] = "UPNVJ Suruh", ["2"] = kode }
            );
        }
        else
        {
            parameter["Body"] = $"Kode masuk UPNVJ Suruh kamu: {kode}. Jangan berikan kode ini ke siapa pun.";
        }

        return parameter;
    }
}
