using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Pengujian batas laju penulisan data (KebijakanTulis).
///
/// Memastikan bahwa pemanggil terautentikasi yang melakukan mutasi data
/// dibatasi oleh BatasLaju.TulisPerMenit (30 per menit), sehingga permintaan
/// ke-31 ditolak dengan status 429 TooManyRequests.
/// </summary>
public class BatasLajuTulisTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private async Task<HttpClient> BuatKlienAsync(Guid userId, params UserRole[] roles)
    {
        var user = new User
        {
            Id = userId,
            Name = "Uji Tulis",
            Phone = "08" + Random.Shared.NextInt64(100000000, 999999999),
            Roles = [.. roles],
        };

        using (var lingkup = pabrik.Services.CreateScope())
        {
            var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Users.Add(user);
            await db.SaveChangesAsync();
        }

        var (token, _) = new TokenService(Options.Create(new JwtOptions
        {
            Issuer = ApiFactory.Issuer,
            Audience = ApiFactory.Audience,
            SigningKey = ApiFactory.SigningKey,
            MasaBerlakuMenit = 60,
        })).Terbitkan(user);

        var klien = pabrik.CreateClient();
        klien.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return klien;
    }

    [Fact]
    public async Task PenulisanDataMelebihiBatasTulisPerMenitDitolak429()
    {
        var userId = Guid.NewGuid();
        var klien = await BuatKlienAsync(userId, UserRole.Runner);

        var orderId = Guid.NewGuid();

        async Task<HttpResponseMessage> Coba() =>
            await klien.PostAsJsonAsync($"/api/orders/{orderId}/penawaran", new
            {
                Harga = 25000m,
                EstimasiDurasiMenit = 30,
                JadwalMulai = DateTime.UtcNow.AddHours(2),
            });

        // 30 permintaan pertama diizinkan oleh rate limiter
        for (var i = 0; i < BatasLaju.TulisPerMenit; i++)
        {
            var respon = await Coba();
            Assert.NotEqual(HttpStatusCode.TooManyRequests, respon.StatusCode);
        }

        // Permintaan ke-31 harus ditolak dengan 429 TooManyRequests
        var lewatBatas = await Coba();
        Assert.Equal(HttpStatusCode.TooManyRequests, lewatBatas.StatusCode);
        Assert.NotNull(lewatBatas.Headers.RetryAfter);

        // Klien lain dengan user ID berbeda tidak terpengaruh batas laju pemanggil pertama
        var klienLain = await BuatKlienAsync(Guid.NewGuid(), UserRole.Runner);
        var responKlienLain = await klienLain.PostAsJsonAsync($"/api/orders/{orderId}/penawaran", new
        {
            Harga = 25000m,
            EstimasiDurasiMenit = 30,
            JadwalMulai = DateTime.UtcNow.AddHours(2),
        });
        Assert.NotEqual(HttpStatusCode.TooManyRequests, responKlienLain.StatusCode);
    }
}
