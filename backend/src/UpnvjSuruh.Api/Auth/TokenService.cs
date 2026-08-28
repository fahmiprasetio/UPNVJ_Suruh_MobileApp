using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Auth;

public interface ITokenService
{
    (string Token, DateTime KedaluwarsaPada) Terbitkan(User user);
}

/// <summary>
/// Menerbitkan token untuk satu user.
///
/// Peran ikut masuk sebagai klaim supaya endpoint bisa memutuskan tanpa menyentuh basis
/// data setiap permintaan. Konsekuensinya: peran yang dicabut admin baru benar-benar
/// hilang setelah token lamanya kedaluwarsa. Karena itu masa berlakunya sengaja pendek,
/// bukan berhari-hari.
/// </summary>
public class TokenService(IOptions<JwtOptions> options) : ITokenService
{
    private readonly JwtOptions _opsi = options.Value;

    public (string Token, DateTime KedaluwarsaPada) Terbitkan(User user)
    {
        var sekarang = DateTime.UtcNow;
        var kedaluwarsa = sekarang.AddMinutes(_opsi.MasaBerlakuMenit);

        var klaim = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new(ClaimTypes.Name, user.Name),
        };

        // Satu klaim per peran, bukan satu klaim berisi daftar dipisah koma. Bentuk inilah
        // yang dimengerti [Authorize(Roles = ...)] tanpa penerjemahan tambahan.
        klaim.AddRange(user.Roles.Distinct().Select(r => new Claim(ClaimTypes.Role, r.ToString())));

        var kunci = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_opsi.SigningKey));
        var token = new JwtSecurityToken(
            issuer: _opsi.Issuer,
            audience: _opsi.Audience,
            claims: klaim,
            notBefore: sekarang,
            expires: kedaluwarsa,
            signingCredentials: new SigningCredentials(kunci, SecurityAlgorithms.HmacSha256));

        return (new JwtSecurityTokenHandler().WriteToken(token), kedaluwarsa);
    }
}
