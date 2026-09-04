using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace UpnvjSuruh.Api.Data;

/// <summary>
/// Memeriksa apakah server masih bisa melayani: basis datanya menjawab, dan skemanya sudah
/// selengkap yang dituntut kode yang sedang berjalan.
/// </summary>
/// <remarks>
/// Keduanya diperiksa, bukan yang pertama saja, dan yang kedua ditambahkan sesudah
/// kekurangannya terbukti sungguhan: server dijalankan terhadap basis data pengembangan yang
/// tertinggal satu migrasi, alamat ini menjawab sehat, lalu setiap permintaan yang menyentuh
/// tabel baru dijawab 500 tanpa satu pun petunjuk yang menghubungkannya dengan migrasi.
///
/// Basis data yang menjawab tapi skemanya tertinggal adalah keadaan yang paling menyesatkan
/// dari ketiganya. Server yang mati kelihatan mati, basis data yang mati sudah tertangkap
/// pemeriksaan pertama; yang ini kelihatan sehat sepenuhnya dan baru pecah pada permintaan
/// tertentu saja, sehingga yang dicurigai lebih dulu selalu kodenya, bukan skemanya.
///
/// Sebab kegagalannya sengaja tidak ikut di badan jawaban. Yang memanggil alamat ini bisa
/// siapa saja, dan pesan galat koneksi memuat nama host beserta nama basis data. Yang perlu
/// tahu justru orang yang memegang servernya, dan ia membacanya dari log.
/// </remarks>
public class PemeriksaBasisData(AppDbContext db, ILogger<PemeriksaBasisData> log) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext konteks,
        CancellationToken batal = default)
    {
        try
        {
            if (!await db.Database.CanConnectAsync(batal))
            {
                return HealthCheckResult.Unhealthy("Basis data tidak menjawab.");
            }

            var tertunda = (await db.Database.GetPendingMigrationsAsync(batal)).ToList();
            if (tertunda.Count > 0)
            {
                // Nama migrasinya ditulis ke log, bukan ke jawaban, dan justru inilah bagian
                // yang paling menolong: yang membacanya langsung tahu perintah apa yang
                // kurang, tanpa menebak dari galat 500 di layar yang sama sekali lain.
                log.LogError(
                    "Basis data tertinggal {Jumlah} migrasi: {Migrasi}. "
                    + "Jalankan `dotnet ef database update` sebelum memakai server ini.",
                    tertunda.Count,
                    string.Join(", ", tertunda));

                return HealthCheckResult.Unhealthy("Skema basis data belum sesuai.");
            }

            return HealthCheckResult.Healthy();
        }
        catch (Exception galat)
        {
            // Galatnya diserahkan ke pemeriksa sebagai exception, yang masuk log server,
            // bukan sebagai teks di badan jawaban.
            return HealthCheckResult.Unhealthy("Basis data tidak menjawab.", galat);
        }
    }
}
