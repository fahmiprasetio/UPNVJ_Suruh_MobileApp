using System.Security.Cryptography;

namespace UpnvjSuruh.Api.Auth;

public interface IPembuatKodeOtp
{
    string Buat();
}

public class PembuatKodeOtp : IPembuatKodeOtp
{
    /// <summary>
    /// Memakai pembangkit acak kriptografis, bukan <c>Random</c>. <c>Random</c> bisa ditebak
    /// dari keluaran sebelumnya, dan yang ditebak di sini adalah kode masuk akun orang.
    /// </summary>
    public string Buat() => RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
}
