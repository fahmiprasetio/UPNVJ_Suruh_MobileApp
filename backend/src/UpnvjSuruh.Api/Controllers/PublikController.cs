using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using UpnvjSuruh.Api.Publik;

namespace UpnvjSuruh.Api.Controllers;

/// <summary>
/// Halaman publik yang bisa dibuka siapa pun tanpa masuk: kebijakan privasi, syarat layanan,
/// dan penghapusan akun.
/// </summary>
/// <remarks>
/// Dilayani API, bukan dashboard admin. Dashboard adalah aplikasi satu halaman yang menuntut
/// login admin, sedangkan Google Play meminta URL yang terbuka untuk umum. Menaruhnya di
/// sini juga berarti halaman penghapusan akun memanggil endpoint yang sama, di asal yang
/// sama, tanpa CORS.
///
/// Isinya ada di <see cref="HalamanPublik"/>. Kontak bantuan dibaca dari konfigurasi
/// <c>Publik:KontakBantuan</c>, bukan ditulis di kode: itu keputusan mitra.
/// </remarks>
[ApiController]
[AllowAnonymous]
[ApiExplorerSettings(IgnoreApi = true)]
public class PublikController(IConfiguration konfigurasi) : ControllerBase
{
    private string? Kontak => konfigurasi["Publik:KontakBantuan"];

    [HttpGet("kebijakan-privasi")]
    public ContentResult Privasi() => Halaman(HalamanPublik.Privasi(Kontak));

    [HttpGet("syarat-ketentuan")]
    public ContentResult Syarat() => Halaman(HalamanPublik.Syarat(Kontak));

    [HttpGet("hapus-akun")]
    public ContentResult HapusAkun() => Halaman(HalamanPublik.HapusAkun(Kontak));

    private static ContentResult Halaman(string html) => new()
    {
        Content = html,
        ContentType = "text/html; charset=utf-8",
        StatusCode = StatusCodes.Status200OK,
    };
}
