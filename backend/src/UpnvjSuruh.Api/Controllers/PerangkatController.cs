using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Controllers;

/// <summary>Token perangkat yang dikirim aplikasi, sebagaimana diterbitkan Firebase.</summary>
public record PerangkatRequest
{
    [Required(AllowEmptyStrings = false)]
    [MaxLength(BatasMasukan.TokenPerangkat)]
    public string Token { get; init; } = string.Empty;
}

/// <summary>
/// Perangkat mana yang boleh dikirimi notifikasi push untuk akun yang sedang masuk.
/// </summary>
/// <remarks>
/// Tidak ada endpoint yang membaca daftarnya, dan itu disengaja. Daftar token perangkat
/// seseorang tidak menjawab pertanyaan apa pun yang dipunyai aplikasi maupun dashboard: yang
/// mendaftarkan sudah memegang tokennya sendiri, dan yang mengirim notifikasi membacanya
/// langsung dari basis data. Endpoint yang tidak ada tidak bisa dipakai memetakan berapa
/// perangkat yang dipakai seseorang.
///
/// Kedua aksinya menyebut akun pemanggil dari tokennya, tidak pernah dari badan permintaan,
/// jadi tidak ada bentuk permintaan yang bisa dipakai mendaftarkan perangkat atas nama orang
/// lain -- yang berarti mengalihkan notifikasi order orang itu ke perangkat sendiri.
/// </remarks>
[ApiController]
[Route("api/perangkat")]
[Authorize]
[EnableRateLimiting(BatasLaju.KebijakanTulis)]
public class PerangkatController(AppDbContext db) : ControllerBase
{
    /// <summary>
    /// Mendaftarkan perangkat ini, atau memindahkannya ke akun yang sedang masuk.
    /// </summary>
    /// <remarks>
    /// Dipanggil aplikasi setiap kali sesi dimulai dan setiap kali Firebase memutar tokennya,
    /// jadi ia harus tahan dipanggil berulang dengan token yang sama. Token yang sudah dikenal
    /// dipindahkan ke pemanggil sekarang, bukan ditolak sebagai duplikat: satu pemasangan
    /// aplikasi cuma boleh menempel pada satu akun, dan kalau tidak dipindahkan, notifikasi
    /// milik akun sebelumnya tetap sampai ke layar orang yang sekarang memakainya.
    /// </remarks>
    [HttpPost]
    public async Task<IActionResult> Daftarkan(PerangkatRequest permintaan, CancellationToken batal)
    {
        var token = permintaan.Token.Trim();
        var pemanggil = User.Id();

        var perangkat = await db.PerangkatNotifikasi
            .SingleOrDefaultAsync(p => p.Token == token, batal);

        if (perangkat is null)
        {
            db.PerangkatNotifikasi.Add(new PerangkatNotifikasi
            {
                UserId = pemanggil,
                Token = token,
            });
        }
        else
        {
            perangkat.UserId = pemanggil;
            perangkat.UpdatedAt = DateTime.UtcNow;
        }

        await db.SaveChangesAsync(batal);
        return NoContent();
    }

    /// <summary>
    /// Melepas perangkat ini, dipanggil aplikasi saat penggunanya keluar.
    /// </summary>
    /// <remarks>
    /// Menghapus barisnya lewat token, tanpa menyaring pemiliknya, dan itu bukan kelalaian:
    /// yang memegang tokennya adalah pemasangan aplikasi itu sendiri, dan yang dimintanya
    /// justru "berhenti mengirim apa pun ke sini". Menolak permintaan itu karena barisnya
    /// terlanjur berpindah ke akun lain berarti notifikasi tetap dikirim ke perangkat yang
    /// sudah minta berhenti.
    ///
    /// Menjawab 204 sekalipun tidak ada baris yang terhapus. Aplikasi yang keluar sebelum
    /// sempat mendaftar tidak sedang melakukan kesalahan, dan galat di jalur keluar cuma
    /// membuat orang gagal keluar.
    ///
    /// POST dengan jalur bernama, bukan DELETE berbadan permintaan. Bukan soal selera:
    /// seluruh API ini belum punya satu pun DELETE, dan klien HTTP di sisi mobile karena itu
    /// juga belum punya kata kerjanya. Menambah keduanya sekaligus demi satu endpoint berarti
    /// jalur baru yang tidak dilewati apa pun yang sudah ada, sementara pola "/lepas" persis
    /// yang sudah dipakai runner melepas order.
    /// </remarks>
    [HttpPost("lepas")]
    public async Task<IActionResult> Lepas(PerangkatRequest permintaan, CancellationToken batal)
    {
        var token = permintaan.Token.Trim();

        await db.PerangkatNotifikasi
            .Where(p => p.Token == token)
            .ExecuteDeleteAsync(batal);

        return NoContent();
    }
}
