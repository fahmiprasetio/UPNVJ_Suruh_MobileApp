using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

public class TokenServiceTests
{
    private static TokenService Layanan(int masaBerlakuMenit = 60) =>
        new(Options.Create(new JwtOptions
        {
            Issuer = ApiFactory.Issuer,
            Audience = ApiFactory.Audience,
            SigningKey = ApiFactory.SigningKey,
            MasaBerlakuMenit = masaBerlakuMenit,
        }));

    private static User Pengguna(params UserRole[] roles) => new()
    {
        Name = "Rangga Saputra",
        Phone = "081234567893",
        Roles = [.. roles],
    };

    private static JwtSecurityToken Baca(string token) =>
        new JwtSecurityTokenHandler().ReadJwtToken(token);

    [Fact]
    public void AkunDuaPeranMendapatSatuKlaimUntukMasingMasing()
    {
        // Bukan satu klaim berisi "Klien,Runner". Bentuk itu yang dimengerti
        // [Authorize(Roles = ...)] tanpa penerjemahan tambahan.
        var (token, _) = Layanan().Terbitkan(Pengguna(UserRole.Klien, UserRole.Runner));

        var peran = Baca(token).Claims
            .Where(c => c.Type == ClaimTypes.Role || c.Type == "role")
            .Select(c => c.Value)
            .ToArray();

        Assert.Equal(2, peran.Length);
        Assert.Contains(Peran.Klien, peran);
        Assert.Contains(Peran.Runner, peran);
    }

    [Fact]
    public void PeranYangTidakDimilikiTidakIkutMasuk()
    {
        var (token, _) = Layanan().Terbitkan(Pengguna(UserRole.Klien));

        var peran = Baca(token).Claims
            .Where(c => c.Type == ClaimTypes.Role || c.Type == "role")
            .Select(c => c.Value)
            .ToArray();

        Assert.Equal([Peran.Klien], peran);
        Assert.DoesNotContain(Peran.Runner, peran);
        Assert.DoesNotContain(Peran.Admin, peran);
    }

    [Fact]
    public void PeranKembarTidakMenghasilkanKlaimGanda()
    {
        var user = Pengguna(UserRole.Runner);
        user.Roles.Add(UserRole.Runner);

        var (token, _) = Layanan().Terbitkan(user);

        var runner = Baca(token).Claims
            .Count(c => (c.Type == ClaimTypes.Role || c.Type == "role") && c.Value == Peran.Runner);

        Assert.Equal(1, runner);
    }

    [Fact]
    public void TokenMenyebutkanPemiliknyaLewatKlaimSub()
    {
        var user = Pengguna(UserRole.Klien);

        var (token, _) = Layanan().Terbitkan(user);

        Assert.Equal(user.Id.ToString(), Baca(token).Subject);
    }

    [Fact]
    public void MasaBerlakuMengikutiSetelan()
    {
        var (_, kedaluwarsa) = Layanan(masaBerlakuMenit: 15).Terbitkan(Pengguna(UserRole.Klien));

        var selisih = kedaluwarsa - DateTime.UtcNow;
        Assert.InRange(selisih.TotalMinutes, 14, 15.5);
    }

    [Fact]
    public void DuaTokenUntukOrangYangSamaTetapBerbeda()
    {
        // Klaim jti membuat setiap token bisa dibedakan, yang jadi syarat kalau nanti
        // ada daftar token yang dicabut.
        var layanan = Layanan();
        var user = Pengguna(UserRole.Klien);

        var (a, _) = layanan.Terbitkan(user);
        var (b, _) = layanan.Terbitkan(user);

        Assert.NotEqual(Baca(a).Id, Baca(b).Id);
    }
}
