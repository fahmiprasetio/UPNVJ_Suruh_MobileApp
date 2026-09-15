using System.Net.Http.Headers;
using System.Text;

namespace UpnvjSuruh.Api.Auth;

/// <summary>
/// Pengirim OTP lewat WhatsApp Sandbox Twilio -- jalur alternatif dari
/// <see cref="PengirimOtpWhatsapp"/> (Meta Cloud API), dipilih di Program.cs kalau
/// "Whatsapp:Twilio:AccountSid" yang terisi.
///
/// Bedanya dengan Meta: sandbox Twilio menerima pesan teks bebas tanpa perlu template yang
/// disetujui lebih dulu, cocok untuk mencoba jalurnya sungguhan sebelum mengurus akun bisnis.
/// Syaratnya nomor tujuan harus lebih dulu mengirim "join &lt;kode-sandbox&gt;" ke nomor
/// sandbox dari WhatsApp-nya sendiri -- sekali per 72 jam, dan Twilio yang menentukan
/// kodenya, bukan aplikasi ini.
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

        var isi = new FormUrlEncodedContent(
            new Dictionary<string, string>
            {
                ["From"] = $"whatsapp:{nomorPengirim}",
                ["To"] = $"whatsapp:+{PengirimOtpWhatsapp.NormalisasiNomorWhatsapp(noHp)}",
                ["Body"] = $"Kode masuk UPNVJ Suruh kamu: {kode}. Jangan berikan kode ini ke siapa pun.",
            }
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
}
