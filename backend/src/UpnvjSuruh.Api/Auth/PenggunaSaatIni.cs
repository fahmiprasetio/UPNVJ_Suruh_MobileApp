using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;

namespace UpnvjSuruh.Api.Auth;

public static class PenggunaSaatIni
{
    /// <summary>
    /// Id pemanggil, diambil dari token, tidak pernah dari badan permintaan atau dari
    /// parameter rute.
    ///
    /// Ini bedanya dengan kontrak tiruan di aplikasi, yang menerima id pemanggil sebagai
    /// argumen biasa. Apa pun yang datang dari klien bisa diganti klien, jadi otorisasi yang
    /// bersandar padanya tidak menjaga apa-apa: cukup kirim id orang lain.
    /// </summary>
    public static Guid Id(this ClaimsPrincipal pengguna)
    {
        var sub = pengguna.FindFirstValue(JwtRegisteredClaimNames.Sub)
                  ?? pengguna.FindFirstValue(ClaimTypes.NameIdentifier);

        return Guid.TryParse(sub, out var id)
            ? id
            : throw new InvalidOperationException("Token tanpa klaim sub yang sah.");
    }

    public static bool Punya(this ClaimsPrincipal pengguna, string peran) => pengguna.IsInRole(peran);
}
