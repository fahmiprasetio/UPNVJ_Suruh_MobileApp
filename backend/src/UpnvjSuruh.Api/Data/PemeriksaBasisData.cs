using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace UpnvjSuruh.Api.Data;

/// <summary>
/// Memeriksa apakah server masih bisa menghubungi basis datanya.
/// </summary>
/// <remarks>
/// Ini satu-satunya hal yang perlu diperiksa dari luar. Tanpa basis data, server ini tidak
/// bisa melayani satu pun permintaan yang berguna, sementara prosesnya tetap menyala dan
/// tetap menjawab permintaan TCP. Pemeriksa yang cuma menanyakan "prosesnya hidup?" akan
/// melaporkannya sehat sepanjang mati listrik di sisi basis data.
///
/// Sebab kegagalannya sengaja tidak ikut di jawaban. Yang memanggil alamat ini bisa siapa
/// saja, dan pesan galat koneksi memuat nama host beserta nama basis data.
/// </remarks>
public class PemeriksaBasisData(AppDbContext db) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext konteks,
        CancellationToken batal = default)
    {
        try
        {
            return await db.Database.CanConnectAsync(batal)
                ? HealthCheckResult.Healthy()
                : HealthCheckResult.Unhealthy("Basis data tidak menjawab.");
        }
        catch (Exception galat)
        {
            // Galatnya diserahkan ke pemeriksa sebagai exception, yang masuk log server,
            // bukan sebagai teks di badan jawaban.
            return HealthCheckResult.Unhealthy("Basis data tidak menjawab.", galat);
        }
    }
}
