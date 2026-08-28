using Npgsql;

namespace UpnvjSuruh.Api.Data;

/// <summary>
/// Membaca arti galat basis data.
///
/// Kenapa perlu menelusuri seluruh rantai, bukan cuma <c>InnerException</c> satu lapis:
/// EF membungkus ulang galatnya sebanyak yang ia perlukan, dan dalamnya berubah menurut
/// keadaan. Kegagalan serialisasi yang sama bisa datang sebagai <c>PostgresException</c>
/// telanjang, atau terbungkus <c>DbUpdateException</c>, atau terbungkus lagi oleh
/// <c>InvalidOperationException</c> dari strategi eksekusi yang menganggapnya kegagalan
/// sementara.
///
/// Pemeriksaan satu lapis akan bekerja hari ini lalu berhenti bekerja setelah perubahan
/// yang sama sekali tidak berhubungan, dan bentuk gagalnya paling buruk: galat yang
/// seharusnya berarti "kamu kalah cepat" muncul sebagai aplikasi rusak.
/// </summary>
public static class GalatDb
{
    /// <summary>
    /// Benar kalau galat ini berarti pemanggilnya kalah lomba, bukan ada yang rusak.
    ///
    /// 40001 adalah kegagalan serialisasi, yaitu dua transaksi yang tidak bisa diurutkan.
    /// 23505 adalah pelanggaran index unik, yaitu baris yang sama diselipkan dua kali.
    /// Keduanya hasil yang wajar dalam perebutan, dan tidak boleh muncul sebagai galat
    /// server.
    /// </summary>
    public static bool KalahCepat(Exception galat) => Punya(
        galat,
        PostgresErrorCodes.SerializationFailure,
        PostgresErrorCodes.UniqueViolation);

    /// <summary>Benar kalau ada pelanggaran index unik di dalam rantai galatnya.</summary>
    public static bool Bentrok(Exception galat) => Punya(galat, PostgresErrorCodes.UniqueViolation);

    private static bool Punya(Exception galat, params string[] kode)
    {
        for (Exception? lapis = galat; lapis is not null; lapis = lapis.InnerException)
        {
            if (lapis is PostgresException pg && kode.Contains(pg.SqlState)) return true;
        }

        return false;
    }
}
