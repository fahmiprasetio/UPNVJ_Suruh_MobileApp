using Microsoft.Extensions.Caching.Memory;

namespace UpnvjSuruh.Api.Auth;

/// <summary>Jawaban atas "nomor ini boleh minta kode lagi sekarang?".</summary>
/// <param name="Boleh">Benar kalau permintaannya boleh dilayani.</param>
/// <param name="TungguLagi">
/// Berapa lama lagi sampai nomor ini boleh mencoba. Nol kalau boleh sekarang. Dipakai
/// mengisi header <c>Retry-After</c>, supaya aplikasi bisa menyebut angka yang benar
/// alih-alih menyuruh pengguna menebak.
/// </param>
public readonly record struct IzinOtp(bool Boleh, TimeSpan TungguLagi)
{
    public static IzinOtp Silakan => new(true, TimeSpan.Zero);
}

/// <summary>
/// Pembatas permintaan kode masuk, dihitung per nomor HP.
///
/// Ini penjagaan terhadap satu serangan yang sangat konkret: mengirimkan permintaan kode
/// berulang-ulang untuk nomor orang lain. Korbannya menerima SMS bertubi-tubi, dan setiap
/// SMS itu ditagihkan penyedia ke mitra. Tidak ada akun yang dibobol, tapi ada tagihan yang
/// membengkak dan ada orang yang ponselnya tidak bisa dipakai.
///
/// Kuncinya nomor HP, bukan alamat IP, karena nomor itulah yang menerima akibatnya.
/// Penyerang bisa berganti IP semudah berganti jaringan; ia tidak bisa mengubah nomor
/// korban yang ingin ia banjiri.
///
/// Berlaku untuk nomor yang terdaftar maupun tidak, dan itu penting: kalau hanya nomor
/// terdaftar yang dibatasi, jawaban 429 yang muncul cuma untuk sebagian nomor akan
/// mengembalikan persis kebocoran yang ditutup dengan menjawab 202 untuk semua orang di
/// <c>MintaKode</c>, yaitu cara memeriksa siapa saja yang punya akun.
///
/// BATASNYA sama dengan <see cref="PenyimpanOtpMemori"/>: hitungannya hidup di memori satu
/// proses. Dengan dua instansi di belakang load balancer, jatahnya menjadi dua kali lipat.
/// Kalau sampai ke sana, yang diganti cukup kelas ini, dengan Redis atau satu tabel.
/// </summary>
public class PembatasOtpMemori(IMemoryCache cache, TimeProvider waktu)
{
    private sealed class Jejak
    {
        public DateTimeOffset MulaiJendela { get; set; }
        public DateTimeOffset Terakhir { get; set; }
        public int Jumlah { get; set; }
    }

    /// <summary>
    /// Satu kunci untuk seluruh pembatas, bukan satu kunci per nomor.
    ///
    /// Bagian yang dikunci cuma beberapa perbandingan dan satu penambahan, jadi biayanya
    /// tidak terasa bahkan pada laju yang jauh di atas yang akan dilihat aplikasi ini.
    /// Kunci per nomor akan lebih cepat di atas kertas dan menambah satu kamus yang harus
    /// dibersihkan sendiri, yaitu kerumitan yang dibayar untuk masalah yang belum ada.
    /// </summary>
    private readonly Lock _gembok = new();

    /// <summary>
    /// Mencatat satu permintaan kode untuk nomor ini, dan mengatakan apakah ia boleh.
    ///
    /// Mencatat sekaligus memutuskan, bukan dua panggilan terpisah. Pemeriksaan yang
    /// terpisah dari pencatatannya berarti dua permintaan yang tiba bersamaan sama-sama
    /// lolos, yaitu persis keadaan yang sedang dijaga di sini.
    /// </summary>
    public IzinOtp Catat(string noHp)
    {
        var sekarang = waktu.GetUtcNow();
        var kunci = $"batas-otp:{noHp}";

        lock (_gembok)
        {
            if (!cache.TryGetValue(kunci, out Jejak? jejak) || jejak is null)
            {
                Simpan(kunci, new Jejak { MulaiJendela = sekarang, Terakhir = sekarang, Jumlah = 1 });
                return IzinOtp.Silakan;
            }

            // Jendelanya dihitung dari jejak yang tersimpan, bukan diserahkan pada masa
            // berlaku entri cache. Masa berlaku cache memakai jam sistem sungguhan, jadi
            // menyandarkan aturannya ke sana berarti aturan ini mustahil diuji tanpa
            // benar-benar menunggu satu jam.
            if (sekarang - jejak.MulaiJendela >= BatasLaju.JendelaOtp)
            {
                Simpan(kunci, new Jejak { MulaiJendela = sekarang, Terakhir = sekarang, Jumlah = 1 });
                return IzinOtp.Silakan;
            }

            var sejakTerakhir = sekarang - jejak.Terakhir;
            if (sejakTerakhir < BatasLaju.JedaAntarOtp)
            {
                return new IzinOtp(false, BatasLaju.JedaAntarOtp - sejakTerakhir);
            }

            if (jejak.Jumlah >= BatasLaju.OtpPerNomor)
            {
                return new IzinOtp(false, jejak.MulaiJendela + BatasLaju.JendelaOtp - sekarang);
            }

            jejak.Jumlah++;
            jejak.Terakhir = sekarang;
            Simpan(kunci, jejak);
            return IzinOtp.Silakan;
        }
    }

    /// <summary>
    /// Menyimpan jejaknya, dengan masa berlaku sebagai kebersihan memori semata.
    ///
    /// Dua kali panjang jendela, bukan satu, supaya entri tidak pernah hilang lebih dulu
    /// daripada jendela yang sedang dihitungnya. Yang menentukan aturannya tetap
    /// <see cref="Jejak.MulaiJendela"/>; ini cuma memastikan nomor yang tidak pernah
    /// kembali tidak menumpuk di memori selamanya.
    /// </summary>
    private void Simpan(string kunci, Jejak jejak) =>
        cache.Set(kunci, jejak, BatasLaju.JendelaOtp * 2);
}
