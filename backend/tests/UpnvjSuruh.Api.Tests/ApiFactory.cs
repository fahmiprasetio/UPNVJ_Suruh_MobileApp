using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Menyalakan API sungguhan di dalam proses tes, lengkap dengan pipeline autentikasinya.
///
/// Rahasianya diisi di sini, bukan diambil dari user-secrets mesin yang menjalankan,
/// supaya tes memberi hasil yang sama di laptop siapa pun dan di CI yang tidak punya
/// rahasia apa-apa. Tidak ada kueri yang menyentuh basis data di tes ini, jadi connection
/// string cukup diisi sesuatu yang berbentuk benar.
/// </summary>
public class ApiFactory : WebApplicationFactory<Program>
{
    public const string SigningKey = "kunci-uji-yang-cukup-panjang-untuk-hmac-sha256";
    public const string Issuer = "UpnvjSuruh.Api";
    public const string Audience = "UpnvjSuruh.Mobile";

    protected override IHost CreateHost(IHostBuilder builder)
    {
        builder.ConfigureHostConfiguration(config =>
        {
            config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Jwt:SigningKey"] = SigningKey,
                ["Jwt:Issuer"] = Issuer,
                ["Jwt:Audience"] = Audience,
                ["Jwt:MasaBerlakuMenit"] = "60",
                // Sengaja tanpa kredensial. Tidak ada kueri yang dijalankan tes ini, jadi
                // yang dibutuhkan cuma string yang bentuknya sah supaya DbContext bisa
                // dibangun. Menaruh password sungguhan di sini membuat pemindai rahasia
                // berbunyi setiap kali, dan pemindai yang selalu berbunyi akan diabaikan
                // justru saat menemukan yang asli.
                ["ConnectionStrings:Default"] = "Host=localhost;Database=upnvj_suruh_test",
            });
        });

        return base.CreateHost(builder);
    }
}
