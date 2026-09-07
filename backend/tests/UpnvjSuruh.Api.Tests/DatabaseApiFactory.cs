using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Npgsql;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Notifikasi;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// API sungguhan dengan basis data sungguhan, di satu basis data sekali pakai per kelas tes.
///
/// Bukan penyedia in-memory. Yang dijaga di sini justru hal-hal yang tidak dimiliki penyedia
/// itu: index unik pada nomor HP, dan pemetaan peran ke <c>integer[]</c> Postgres. Tes yang
/// lolos karena penyedianya tidak menegakkan apa-apa lebih buruk daripada tidak ada tes.
///
/// Butuh Postgres hidup. Alamatnya bisa diatur lewat environment variable
/// <c>UPNVJ_TEST_DB</c>, bawaannya Postgres lokal.
/// </summary>
public class DatabaseApiFactory : ApiFactory, IAsyncLifetime
{
    /// <summary>
    /// Alamat Postgres untuk tes.
    ///
    /// Bawaannya sengaja memuat kredensial bawaan Postgres lokal, supaya `dotnet test` jalan
    /// tanpa setup. Ini akan selalu tersangkut pemindai rahasia, dan itu memang harganya:
    /// yang tertulis di sini bukan rahasia siapa-siapa, cuma nilai bawaan pemasangan Postgres
    /// di mesin sendiri. Mesin atau CI yang berbeda menimpanya lewat UPNVJ_TEST_DB, dan
    /// kredensial sungguhan tidak boleh menggantikan baris ini.
    /// </summary>
    private static string Induk =>
        Environment.GetEnvironmentVariable("UPNVJ_TEST_DB")
        ?? "Host=localhost;Port=5432;Database=postgres;Username=postgres;Password=postgres";

    private readonly string _namaDb = $"upnvj_suruh_test_{Guid.NewGuid():N}";

    protected override string ConnectionString =>
        new NpgsqlConnectionStringBuilder(Induk) { Database = _namaDb }.ConnectionString;

    /// <summary>Kode OTP terakhir yang "dikirim", supaya tes bisa memakainya untuk masuk.</summary>
    public PengirimOtpPencatat Otp { get; } = new();

    /// <summary>Notifikasi push yang "dikirim", supaya tes bisa memeriksa isinya.</summary>
    public PengirimNotifikasiPencatat Notifikasi { get; } = new();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        // ConfigureTestServices dijamin berjalan setelah seluruh pendaftaran aplikasi, jadi
        // penggantian di sini pasti menang tanpa bergantung pada urutan.
        builder.ConfigureTestServices(services =>
        {
            services.RemoveAll<IPengirimOtp>();
            services.AddSingleton<IPengirimOtp>(Otp);

            services.RemoveAll<IPengirimNotifikasi>();
            services.AddSingleton<IPengirimNotifikasi>(Notifikasi);
        });

        base.ConfigureWebHost(builder);
    }

    async Task IAsyncLifetime.InitializeAsync()
    {
        await using (var koneksi = new NpgsqlConnection(Induk))
        {
            await koneksi.OpenAsync();
            await using var perintah = koneksi.CreateCommand();
            perintah.CommandText = $"CREATE DATABASE \"{_namaDb}\"";
            await perintah.ExecuteNonQueryAsync();
        }

        using var lingkup = Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        await db.Database.MigrateAsync();
    }

    async Task IAsyncLifetime.DisposeAsync()
    {
        await base.DisposeAsync();

        NpgsqlConnection.ClearAllPools();
        await using var koneksi = new NpgsqlConnection(Induk);
        await koneksi.OpenAsync();
        await using var perintah = koneksi.CreateCommand();
        perintah.CommandText = $"DROP DATABASE IF EXISTS \"{_namaDb}\" WITH (FORCE)";
        await perintah.ExecuteNonQueryAsync();
    }
}

/// <summary>
/// Pengganti pengirim OTP yang mencatat kodenya alih-alih mengirim. Tes butuh kode yang
/// sungguhan dipakai sistem, bukan kode yang ditebak tes.
/// </summary>
public class PengirimOtpPencatat : IPengirimOtp
{
    private readonly Dictionary<string, string> _kode = [];

    public Task KirimAsync(string noHp, string kode, CancellationToken batal = default)
    {
        lock (_kode) _kode[noHp] = kode;
        return Task.CompletedTask;
    }

    public string? KodeUntuk(string noHp)
    {
        lock (_kode) return _kode.GetValueOrDefault(noHp);
    }
}

/// <summary>
/// Pengganti pengirim notifikasi yang mencatat kirimannya alih-alih menghubungi Firebase.
///
/// Yang diuji lewat ini bukan Firebase-nya, melainkan seluruh keputusan sebelum Firebase:
/// siapa yang dikirimi, kalimat apa, dan perangkat mana yang dibuang. Itu bagian yang bisa
/// salah tanpa terlihat, dan bagian yang tidak butuh jaringan untuk dibuktikan.
/// </summary>
public class PengirimNotifikasiPencatat : IPengirimNotifikasi
{
    private readonly List<(IReadOnlyCollection<string> Token, PesanNotifikasi Pesan)> _terkirim = [];

    /// <summary>
    /// Token yang akan dijawab "sudah tidak terdaftar", menirukan perangkat yang aplikasinya
    /// sudah dicopot. Diisi tes yang menguji pembuangan token mati.
    /// </summary>
    public HashSet<string> TokenMati { get; } = [];

    public IReadOnlyList<(IReadOnlyCollection<string> Token, PesanNotifikasi Pesan)> Terkirim
    {
        get { lock (_terkirim) return [.. _terkirim]; }
    }

    public Task<IReadOnlyCollection<string>> KirimAsync(
        IReadOnlyCollection<string> token,
        PesanNotifikasi pesan,
        CancellationToken batal = default)
    {
        lock (_terkirim) _terkirim.Add((token, pesan));

        return Task.FromResult<IReadOnlyCollection<string>>(
            [.. token.Where(TokenMati.Contains)]);
    }

    public void Bersihkan()
    {
        lock (_terkirim) _terkirim.Clear();
        TokenMati.Clear();
    }
}
