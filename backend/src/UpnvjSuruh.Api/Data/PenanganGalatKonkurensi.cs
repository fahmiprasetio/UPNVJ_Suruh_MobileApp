using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace UpnvjSuruh.Api.Data;

/// <summary>
/// Menerjemahkan bentrok konkurensi jadi 409, bukan membiarkannya jadi 500.
/// </summary>
/// <remarks>
/// Tabel order memakai kolom sistem Postgres <c>xmin</c> sebagai penanda versi, jadi dua
/// penulisan yang mengenai baris order yang sama pada saat yang sama membuat yang kalah
/// melempar <see cref="DbUpdateConcurrencyException"/>. Sebelum ini tidak ada satu pun tempat
/// yang menangkapnya, dan yang terjadi adalah 500.
///
/// Keadaannya nyata walaupun jarang: kabar lunas dari gateway tiba persis saat pemesannya
/// menekan batal, atau dua admin menjawab permintaan yang sama. Tidak satu pun dari itu galat
/// server. Yang terjadi cuma datanya sudah berubah sejak dibaca, dan yang benar dilakukan
/// pemanggil adalah membaca ulang lalu memutuskan lagi.
///
/// 409, bukan 500, karena bedanya menentukan tindakan. Aplikasi memperlakukan 500 sebagai
/// "server sedang bermasalah, coba lagi sebentar lagi", dan mencoba lagi permintaan yang sama
/// dengan data lama akan bentrok lagi dengan cara yang sama.
///
/// Dipasang sebagai penangan global, bukan try-catch di tiap endpoint. Setiap endpoint yang
/// menulis order adalah tempat ini bisa terjadi, termasuk yang belum ditulis, dan penjagaan
/// yang harus diingat setiap kali menambah endpoint adalah penjagaan yang cepat atau lambat
/// terlupakan.
/// </remarks>
public class PenanganGalatKonkurensi(ILogger<PenanganGalatKonkurensi> log) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext konteks,
        Exception galat,
        CancellationToken batal)
    {
        // Selain bentrok konkurensi tidak disentuh: false berarti penangan berikutnya yang
        // mengurus. Penangan yang menelan segalanya akan menyembunyikan galat sungguhan
        // sebagai 409 yang menyesatkan.
        if (galat is not DbUpdateConcurrencyException) return false;

        log.LogWarning(galat, "Bentrok konkurensi pada {Jalur}.", konteks.Request.Path);

        konteks.Response.StatusCode = StatusCodes.Status409Conflict;
        await konteks.Response.WriteAsJsonAsync(
            new ProblemDetails
            {
                Title = "Data ini baru saja berubah",
                Detail = "Ada perubahan lain yang masuk lebih dulu. Muat ulang, lalu coba lagi.",
                Status = StatusCodes.Status409Conflict,
            },
            batal);

        return true;
    }
}
