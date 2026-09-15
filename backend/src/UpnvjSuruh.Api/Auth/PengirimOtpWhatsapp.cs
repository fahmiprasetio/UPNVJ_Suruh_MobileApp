using System.Net.Http.Json;

namespace UpnvjSuruh.Api.Auth;

/// <summary>
/// Pengirim OTP sungguhan lewat WhatsApp Cloud API (Meta), dipakai begitu kredensialnya
/// terisi lewat konfigurasi -- lihat pendaftarannya di Program.cs, yang memilih kelas ini
/// alih-alih <see cref="PengirimOtpLog"/> kalau "Whatsapp:AccessToken" sudah diisi.
///
/// Kode OTP tidak bisa dikirim sebagai pesan bebas: WhatsApp menolak pesan dari bisnis ke
/// nomor yang belum punya sesi percakapan berjalan, kecuali lewat template pesan yang sudah
/// disetujui Meta lebih dulu (kategori "Authentication" di WhatsApp Manager). Nama dan bahasa
/// template-nya karena itu ikut dikonfigurasi, bukan ditulis mati -- keduanya baru ada setelah
/// template dibuat dan disetujui, dan bisa berbeda tiap akun.
/// </summary>
public class PengirimOtpWhatsapp(
    HttpClient http,
    IConfiguration konfigurasi,
    ILogger<PengirimOtpWhatsapp> log
) : IPengirimOtp
{
    public async Task KirimAsync(string noHp, string kode, CancellationToken batal = default)
    {
        var idNomorPengirim = konfigurasi["Whatsapp:PhoneNumberId"];
        var namaTemplate = konfigurasi["Whatsapp:NamaTemplate"] ?? "otp_login";
        var bahasaTemplate = konfigurasi["Whatsapp:BahasaTemplate"] ?? "id";

        var permintaan = new
        {
            messaging_product = "whatsapp",
            to = NormalisasiNomorWhatsapp(noHp),
            type = "template",
            template = new
            {
                name = namaTemplate,
                language = new { code = bahasaTemplate },
                components = new object[]
                {
                    new
                    {
                        type = "body",
                        parameters = new object[] { new { type = "text", text = kode } },
                    },
                },
            },
        };

        var jawaban = await http.PostAsJsonAsync(
            $"/v21.0/{idNomorPengirim}/messages",
            permintaan,
            batal
        );

        if (!jawaban.IsSuccessStatusCode)
        {
            var isi = await jawaban.Content.ReadAsStringAsync(batal);
            // Dicatat, tidak dilempar: orang yang menunggu kode di layarnya tidak boleh
            // melihat galat mentah penyedia pihak ketiga, tapi yang menelusuri kenapa
            // kodenya tidak sampai butuh isi galat sungguhannya, bukan cuma "gagal".
            //
            // Nomornya disamarkan, di kalimatnya sendiri maupun di dalam isi jawaban
            // penyedia. Lihat Samarkan dan SamarkanNomorDi di bawah.
            log.LogError(
                "Gagal mengirim OTP WhatsApp ke {NoHp}: {Status} {Isi}",
                Samarkan(noHp),
                jawaban.StatusCode,
                SamarkanNomorDi(isi, noHp)
            );
        }
    }

    /// <summary>
    /// WhatsApp Cloud API minta nomor lengkap berkode negara tanpa "+" atau "0" di depan
    /// (mis. "6281234567890"), sedangkan nomor di basis data ditulis format lokal
    /// ("081234567890") mengikuti cara orang mengetiknya sendiri saat daftar.
    /// </summary>
    public static string NormalisasiNomorWhatsapp(string noHp)
    {
        var bersih = noHp.Trim();
        if (bersih.StartsWith('+')) return bersih[1..];
        if (bersih.StartsWith('0')) return "62" + bersih[1..];
        return bersih;
    }

    /// <summary>
    /// Nomor HP dalam bentuk yang aman ditulis ke log: empat angka pertama dan dua terakhir,
    /// sisanya bintang.
    /// </summary>
    /// <remarks>
    /// Log server produksi dibaca lebih banyak mata daripada basis datanya sendiri: operator
    /// hosting, pengumpul log pihak ketiga, dan siapa pun yang pernah memegang salinannya.
    /// Gagal kirim OTP bukan kejadian langka yang pantas dibayar dengan satu nomor HP per
    /// baris, melainkan kejadian yang memang diharapkan berulang (saldo sandbox habis, nomor
    /// tujuan belum "join", template belum disetujui), jadi tanpa penyamaran ini berkas log
    /// pelan-pelan berubah jadi daftar nomor pengguna yang sedang berusaha masuk.
    ///
    /// Prinsipnya sama dengan EnableSensitiveDataLogging yang sudah dikurung ke Development
    /// di Program.cs. Yang berbeda cuma jalan keluarnya: baris ini justru harus tetap
    /// berguna di produksi, karena di situlah kredensial WhatsApp sungguhan pertama kali
    /// hidup dan kegagalannya pertama kali perlu ditelusuri.
    ///
    /// Empat angka depan dibiarkan supaya operator selulernya masih terbaca, dan dua angka
    /// belakang supaya satu keluhan tetap bisa dicocokkan ke satu baris log tertentu. Yang
    /// dibuang persis bagian yang membuat nomornya bisa dihubungi.
    /// </remarks>
    public static string Samarkan(string noHp)
    {
        var bersih = noHp.Trim();

        return bersih.Length <= 6
            ? new string('*', bersih.Length)
            : string.Concat(bersih[..4], new string('*', bersih.Length - 6), bersih[^2..]);
    }

    /// <summary>
    /// Isi jawaban penyedia dengan setiap bentuk nomor tujuan di dalamnya ikut disamarkan.
    /// </summary>
    /// <remarks>
    /// Menyamarkan nomor di kalimat log saja tidak cukup, dan ini bukan kehati-hatian
    /// berlebihan: Twilio menyebut nomor tujuan di dalam pesan galatnya sendiri ("The 'To'
    /// number ... is not a valid phone number"), jadi nomor yang baru saja disamarkan di awal
    /// baris muncul lagi utuh beberapa karakter kemudian, di bagian yang disalin apa adanya
    /// dari penyedia.
    ///
    /// Isi galatnya tetap dicatat, bukan dibuang. Di situlah sebab sungguhannya berada, dan
    /// membuangnya berarti menukar satu masalah keamanan dengan kegagalan yang tidak bisa
    /// ditelusuri sama sekali.
    ///
    /// Ketiga bentuknya diganti berurutan dari yang terpanjang, karena bentuk yang pendek
    /// adalah bagian dari yang panjang: "+6281..." memuat "6281..." di dalamnya, dan
    /// mengganti yang pendek lebih dulu menyisakan tanda plus beserta potongan nomornya.
    /// </remarks>
    public static string SamarkanNomorDi(string teks, string noHp)
    {
        var samaran = Samarkan(noHp);
        var internasional = NormalisasiNomorWhatsapp(noHp);

        return teks
            .Replace("+" + internasional, samaran, StringComparison.Ordinal)
            .Replace(internasional, samaran, StringComparison.Ordinal)
            .Replace(noHp.Trim(), samaran, StringComparison.Ordinal);
    }
}
