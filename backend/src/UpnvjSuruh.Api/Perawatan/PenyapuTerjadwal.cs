namespace UpnvjSuruh.Api.Perawatan;

/// <summary>
/// Menjalankan <see cref="Penyapu"/> berkala selama server hidup.
/// </summary>
/// <remarks>
/// Sengaja setipis mungkin: pewaktu, lingkup, dan penanganan galat. Seluruh pekerjaannya ada
/// di Penyapu, yang bisa dipanggil langsung oleh tes. Pekerja latar yang logikanya menempel
/// pada pewaktu cuma bisa diuji dengan menunggu, dan yang seperti itu berakhir tidak diuji.
///
/// Lingkupnya dibuat baru setiap putaran. DbContext berumur scoped, dan pekerja latar hidup
/// selama proses: menyuntikkannya langsung berarti satu DbContext dipakai berjam-jam,
/// menumpuk seluruh entitas yang pernah ia sentuh di pelacaknya sampai memorinya habis.
///
/// Galat ditangkap dan dicatat, tidak dibiarkan naik. Pengecualian yang lolos dari
/// ExecuteAsync menghentikan pekerjanya untuk selamanya tanpa menjatuhkan servernya, jadi
/// yang terjadi adalah penyapu yang diam-diam berhenti bekerja sementara semuanya tampak
/// baik-baik saja.
/// </remarks>
public class PenyapuTerjadwal(
    IServiceScopeFactory pembuatLingkup,
    ILogger<PenyapuTerjadwal> log) : BackgroundService
{
    /// <summary>
    /// Selang antar sapuan.
    ///
    /// Sepadan dengan batas waktu bayar, yaitu tiga puluh menit: transaksi yang kedaluwarsa
    /// tidak perlu ditandai lebih cepat daripada ia bisa kedaluwarsa. Lebih rapat cuma
    /// menambah kueri yang tidak menemukan apa-apa.
    /// </summary>
    public static readonly TimeSpan Selang = TimeSpan.FromMinutes(30);

    protected override async Task ExecuteAsync(CancellationToken batal)
    {
        using var pewaktu = new PeriodicTimer(Selang);

        while (await pewaktu.WaitForNextTickAsync(batal))
        {
            try
            {
                using var lingkup = pembuatLingkup.CreateScope();
                var penyapu = lingkup.ServiceProvider.GetRequiredService<Penyapu>();
                await penyapu.SapuAsync(batal);
            }
            catch (OperationCanceledException) when (batal.IsCancellationRequested)
            {
                // Server sedang berhenti. Bukan galat.
                return;
            }
            catch (Exception galat)
            {
                log.LogError(galat, "Sapuan perawatan gagal. Dicoba lagi putaran berikutnya.");
            }
        }
    }
}
