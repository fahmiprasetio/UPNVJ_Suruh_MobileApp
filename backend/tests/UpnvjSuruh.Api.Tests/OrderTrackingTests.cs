using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

public sealed class OrderTrackingTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private async Task<(HttpClient Klien, User User)> AkunAsync(UserRole role)
    {
        var user = new User
        {
            Name = $"Tracking {role} {Guid.NewGuid():N}"[..30],
            Phone = "08" + Random.Shared.NextInt64(100000000, 999999999),
            Roles = [role],
        };
        using (var lingkup = pabrik.Services.CreateScope())
        {
            var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Users.Add(user);
            await db.SaveChangesAsync();
        }

        var (token, _) = new TokenService(Microsoft.Extensions.Options.Options.Create(new JwtOptions
        {
            Issuer = ApiFactory.Issuer,
            Audience = ApiFactory.Audience,
            SigningKey = ApiFactory.SigningKey,
            MasaBerlakuMenit = 60,
        })).Terbitkan(user);
        var client = pabrik.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return (client, user);
    }

    private async Task<(HttpClient Klien, HttpClient Runner, Order Order)> PerjalananAsync()
    {
        var (klien, pemesan) = await AkunAsync(UserRole.Klien);
        var (runner, pelaksana) = await AkunAsync(UserRole.Runner);
        var order = new Order
        {
            ClientId = pemesan.Id,
            ServiceType = ServiceType.AnterJemput,
            Status = OrderStatus.Dikerjakan,
            Price = 15000,
            PickupAddress = "Kampus UPNVJ",
            DestinationAddress = "Lenteng Agung",
            PickupLatitude = -6.316,
            PickupLongitude = 106.794,
            DestinationLatitude = -6.331,
            DestinationLongitude = 106.833,
        };
        order.RunnerAssignments.Add(new OrderRunnerAssignment
        {
            OrderId = order.Id,
            Order = order,
            RunnerId = pelaksana.Id,
        });
        using (var lingkup = pabrik.Services.CreateScope())
        {
            var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Orders.Add(order);
            await db.SaveChangesAsync();
        }
        return (klien, runner, order);
    }

    private static object Lokasi(DateTime direkam) => new
    {
        Latitude = -6.3201,
        Longitude = 106.8012,
        AkurasiMeter = 8.0,
        ArahDerajat = 120.0,
        KecepatanMeterPerDetik = 5.5,
        DirekamPada = direkam,
    };

    [Fact]
    public async Task RunnerPemegangMengirimDanKlienMembacaLokasi()
    {
        var (klien, runner, order) = await PerjalananAsync();
        var waktu = DateTime.UtcNow;

        (await runner.PutAsJsonAsync($"/api/orders/{order.Id}/tracking", Lokasi(waktu)))
            .EnsureSuccessStatusCode();
        var lokasi = await klien.GetFromJsonAsync<LokasiRunnerResponse>(
            $"/api/orders/{order.Id}/tracking");

        Assert.NotNull(lokasi);
        Assert.Equal(order.Id, lokasi.OrderId);
        Assert.Equal(-6.3201, lokasi.Latitude, 4);
        Assert.Equal(106.8012, lokasi.Longitude, 4);
    }

    [Fact]
    public async Task RunnerLainTidakBisaMenulisLokasi()
    {
        var (_, _, order) = await PerjalananAsync();
        var (runnerLain, _) = await AkunAsync(UserRole.Runner);

        var respons = await runnerLain.PutAsJsonAsync(
            $"/api/orders/{order.Id}/tracking", Lokasi(DateTime.UtcNow));

        Assert.Equal(HttpStatusCode.NotFound, respons.StatusCode);
    }

    [Fact]
    public async Task PaketLebihLamaTidakMenimpaPosisiTerbaru()
    {
        var (klien, runner, order) = await PerjalananAsync();
        var terbaru = DateTime.UtcNow;
        (await runner.PutAsJsonAsync($"/api/orders/{order.Id}/tracking", Lokasi(terbaru)))
            .EnsureSuccessStatusCode();

        (await runner.PutAsJsonAsync($"/api/orders/{order.Id}/tracking", new
        {
            Latitude = -6.1,
            Longitude = 106.1,
            DirekamPada = terbaru.AddSeconds(-20),
        })).EnsureSuccessStatusCode();

        var lokasi = await klien.GetFromJsonAsync<LokasiRunnerResponse>(
            $"/api/orders/{order.Id}/tracking");
        Assert.Equal(-6.3201, lokasi!.Latitude, 4);
    }

    [Fact]
    public async Task KoordinatTidakValidDitolak()
    {
        var (_, runner, order) = await PerjalananAsync();

        var respons = await runner.PutAsJsonAsync($"/api/orders/{order.Id}/tracking", new
        {
            Latitude = 91,
            Longitude = 106,
            DirekamPada = DateTime.UtcNow,
        });

        Assert.Equal(HttpStatusCode.BadRequest, respons.StatusCode);
    }
}
