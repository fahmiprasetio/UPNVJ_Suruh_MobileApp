using System.Net;
using System.Net.Http.Json;
using UpnvjSuruh.Api.Auth;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Batas laju endpoint yang boleh dipanggil tanpa token.
///
/// Kelasnya sendiri, dengan pabriknya sendiri, dan itu bukan kerapian: tesnya menghabiskan
/// jatah satu pemanggil sampai habis, jadi kalau ia berbagi server dengan tes lain, tes yang
/// kebetulan berjalan sesudahnya akan gagal karena jatahnya sudah dipakai tes ini.
///
/// Basis datanya tidak dipakai sama sekali. Permintaannya sengaja dibuat bernomor HP salah
/// bentuk supaya ditolak validasi sebelum satu pun kueri berjalan; yang diperiksa cuma
/// apakah pembatasnya benar-benar terpasang di pipeline, dan pembatas berjalan sebelum
/// validasi maupun basis data.
/// </summary>
public class BatasLajuTamuTests(ApiFactory pabrik) : IClassFixture<ApiFactory>
{
    [Fact]
    public async Task JatahTamuHabisSetelahBatasnyaTercapai()
    {
        var klien = pabrik.CreateClient();

        async Task<HttpResponseMessage> Coba() =>
            await klien.PostAsJsonAsync("/api/auth/daftar", new { Nama = "Uji", NoHp = "bukan-nomor" });

        for (var i = 0; i < BatasLaju.TamuPerJendela; i++)
        {
            var dalamJatah = await Coba();
            Assert.Equal(HttpStatusCode.BadRequest, dalamJatah.StatusCode);
        }

        var lewatJatah = await Coba();

        Assert.Equal(HttpStatusCode.TooManyRequests, lewatJatah.StatusCode);
        Assert.NotNull(lewatJatah.Headers.RetryAfter);
    }
}
