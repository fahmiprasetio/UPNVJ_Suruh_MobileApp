using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Auth;

/// <summary>
/// Mengangkat admin pertama.
///
/// Peran hanya bisa diberikan admin, yang berarti sistem yang belum punya admin sama sekali
/// tidak punya jalan mengangkat siapa pun. Jalan keluarnya harus ada, dan harus berada di
/// tempat yang lebih sulit dijangkau daripada API: konfigurasi server. Yang bisa mengangkat
/// admin pertama adalah orang yang memegang user-secrets atau environment variable mesinnya,
/// bukan siapa pun yang bisa mengirim permintaan HTTP.
///
/// Sengaja tidak membuat akunnya. Orangnya mendaftar sendiri lewat aplikasi seperti orang
/// lain, lalu nomornya dicantumkan di sini. Membuat akun dari konfigurasi berarti ada jalan
/// kedua melahirkan akun, dan jalan kedua adalah jalan yang lupa diperiksa.
/// </summary>
public static class AdminAwal
{
    public const string KunciKonfigurasi = "Admin:NomorHpAwal";

    public static async Task PastikanAsync(IServiceProvider penyedia, CancellationToken batal = default)
    {
        using var lingkup = penyedia.CreateScope();
        var konfigurasi = lingkup.ServiceProvider.GetRequiredService<IConfiguration>();
        var log = lingkup.ServiceProvider
            .GetRequiredService<ILoggerFactory>()
            .CreateLogger(nameof(AdminAwal));

        var noHp = konfigurasi[KunciKonfigurasi]?.Trim();
        if (string.IsNullOrEmpty(noHp)) return;

        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var user = await db.Users.SingleOrDefaultAsync(u => u.Phone == noHp, batal);

        if (user is null)
        {
            log.LogWarning(
                "{Kunci} menunjuk {NoHp}, tapi belum ada akun dengan nomor itu. "
                + "Daftarkan dulu lewat aplikasi, lalu jalankan ulang server ini.",
                KunciKonfigurasi, noHp);
            return;
        }

        if (user.Roles.Contains(UserRole.Admin)) return;

        var sebelum = user.Roles.Distinct().OrderBy(r => r).ToList();
        user.Roles = [.. sebelum.Append(UserRole.Admin).Distinct().OrderBy(r => r)];

        // Ikut dicatat seperti perubahan peran lainnya, dengan dirinya sendiri sebagai yang
        // mengubah. Perubahan peran yang tidak meninggalkan jejak justru yang paling menarik
        // bagi orang yang memeriksa belakangan.
        db.UserRoleChanges.Add(new UserRoleChange
        {
            UserId = user.Id,
            ChangedByAdminId = user.Id,
            RolesBefore = sebelum,
            RolesAfter = user.Roles,
            Reason = $"Admin pertama, diangkat lewat konfigurasi server ({KunciKonfigurasi}).",
        });

        await db.SaveChangesAsync(batal);
        log.LogWarning("{NoHp} diangkat jadi admin lewat {Kunci}.", noHp, KunciKonfigurasi);
    }
}
