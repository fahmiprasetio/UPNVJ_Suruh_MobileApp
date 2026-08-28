namespace UpnvjSuruh.Api.Auth;

public interface IPengirimOtp
{
    Task KirimAsync(string noHp, string kode, CancellationToken batal = default);
}

/// <summary>
/// Pengirim OTP untuk masa pengembangan: kodenya ditulis ke log, bukan dikirim ke mana pun.
///
/// Cara masuk akun masih pertanyaan pengunci menunggu mitra (rencana capstone bagian 14.8),
/// jadi penyedia SMS atau WhatsApp-nya belum bisa dipilih. Begitu dipilih, yang berubah
/// cuma kelas ini, karena tidak ada satu pun kode lain yang tahu bagaimana kode itu sampai.
///
/// Hanya boleh didaftarkan di lingkungan Development. Di produksi, pengirim yang menulis
/// kode masuk ke log sama saja dengan tidak punya OTP sama sekali: siapa pun yang bisa
/// membaca log bisa masuk sebagai siapa pun.
/// </summary>
public class PengirimOtpLog(ILogger<PengirimOtpLog> log) : IPengirimOtp
{
    public Task KirimAsync(string noHp, string kode, CancellationToken batal = default)
    {
        log.LogWarning("[ALAT PENGUJI] Kode OTP untuk {NoHp} adalah {Kode}", noHp, kode);
        return Task.CompletedTask;
    }
}
