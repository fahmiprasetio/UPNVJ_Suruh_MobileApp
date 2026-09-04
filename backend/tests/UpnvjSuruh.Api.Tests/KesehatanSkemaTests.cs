using System.Net;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using UpnvjSuruh.Api.Data;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Basis data yang menjawab tapi skemanya tertinggal migrasi.
/// </summary>
/// <remarks>
/// Basis datanya sungguh dibuat, jadi koneksinya benar-benar berhasil, tapi tidak satu pun
/// migrasi dijalankan. Itulah bedanya dengan <see cref="DatabaseApiFactory"/>, dan itu satu-
/// satunya alasan kelas ini ada: keadaan inilah yang dulu lolos dari pemeriksa kesehatan.
/// </remarks>
public class PabrikTanpaMigrasi : ApiFactory, IAsyncLifetime
{
    private static string Induk =>
        Environment.GetEnvironmentVariable("UPNVJ_TEST_DB")
        ?? "Host=localhost;Port=5432;Database=postgres;Username=postgres;Password=postgres";

    private readonly string _namaDb = $"upnvj_suruh_kosong_{Guid.NewGuid():N}";

    protected override string ConnectionString =>
        new NpgsqlConnectionStringBuilder(Induk) { Database = _namaDb }.ConnectionString;

    async Task IAsyncLifetime.InitializeAsync()
    {
        await using var koneksi = new NpgsqlConnection(Induk);
        await koneksi.OpenAsync();
        await using var perintah = koneksi.CreateCommand();
        perintah.CommandText = $"CREATE DATABASE \"{_namaDb}\"";
        await perintah.ExecuteNonQueryAsync();

        // Sengaja berhenti di sini: tidak ada MigrateAsync.
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
/// Pemeriksa kesehatan terhadap basis data yang skemanya tertinggal.
/// </summary>
/// <remarks>
/// Ditambahkan sesudah keadaan ini terjadi sungguhan, bukan sebagai kemungkinan yang
/// dibayangkan: server dijalankan terhadap basis data pengembangan yang tertinggal satu
/// migrasi, <c>/health</c> menjawab "Healthy", lalu setiap permintaan yang menyentuh tabel
/// baru dijawab 500 tanpa satu pun petunjuk yang menghubungkannya dengan migrasi.
///
/// Ini keadaan yang paling menyesatkan dari semua kegagalan basis data. Server yang mati
/// kelihatan mati; basis data yang mati sudah tertangkap pemeriksaan koneksi. Yang ini
/// kelihatan sehat sepenuhnya dan cuma pecah pada sebagian permintaan, jadi yang dicurigai
/// lebih dulu selalu kode yang baru ditulis, bukan skema yang belum diperbarui.
/// </remarks>
public class KesehatanSkemaTests(PabrikTanpaMigrasi pabrik) : IClassFixture<PabrikTanpaMigrasi>
{
    [Fact]
    public async Task SkemaYangTertinggalDilaporkanTidakSehat()
    {
        var jawaban = await pabrik.CreateClient().GetAsync("/health");

        Assert.Equal(HttpStatusCode.ServiceUnavailable, jawaban.StatusCode);
    }

    [Fact]
    public async Task JawabannyaTetapTidakMenyebutkanIsiDalamnya()
    {
        // Nama migrasi yang kurang ditulis ke log server, bukan ke badan jawaban. Yang
        // memanggil alamat ini bisa siapa saja, dan daftar migrasi menceritakan bentuk
        // basis datanya kepada orang yang belum tentu berhak tahu.
        var jawaban = await pabrik.CreateClient().GetAsync("/health");
        var isi = await jawaban.Content.ReadAsStringAsync();

        Assert.Equal("Unhealthy", isi);
    }

    /// <summary>
    /// Yang membedakan keadaan ini dari basis data yang mati: koneksinya benar-benar bisa
    /// dibuka. Kalau tes ini gagal, yang diuji di atas bukan lagi "skema tertinggal"
    /// melainkan "basis data tidak ada", dan pemeriksaan migrasinya tidak pernah tersentuh.
    /// </summary>
    [Fact]
    public async Task BasisDatanyaMemangBisaDihubungi()
    {
        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();

        Assert.True(await db.Database.CanConnectAsync());
        Assert.NotEmpty(await db.Database.GetPendingMigrationsAsync());
    }
}
