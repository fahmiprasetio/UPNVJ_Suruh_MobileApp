using UpnvjSuruh.Api.Payments;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Penjagaan tanda tangan sebelum backend memverifikasi status langsung ke Midtrans.
///
/// Nilai tanda tangan yang diharapkan di sini dihitung TERPISAH lewat Python
/// (<c>hashlib.sha512</c>), bukan lewat kode yang sedang diuji -- kalau keduanya memakai
/// rumus yang sama, tes ini akan lolos bahkan kalau rumusnya salah sejak awal.
/// </summary>
public class MidtransOptionsTests
{
    private const string ServerKey = "SB-Mid-server-uji-panjang-sekali";
    private const string OrderId = "order123";
    private const string StatusCode = "200";
    private const string GrossAmount = "50000.00";

    // sha512("order123" + "200" + "50000.00" + ServerKey), dihitung lewat Python, bukan C#.
    private const string TandaTanganSah =
        "f2df323dd7e813d3ca5968c96bae2b0353a85c3d596fcd07eefa67bd7edff0e" +
        "49913c8881140433fedb6ab70726acebe5dc0d30a7ecf3c7740068f13ca49a987";

    private static MidtransOptions Opsi(string serverKey = ServerKey) => new() { ServerKey = serverKey };

    [Fact]
    public void TandaTanganYangDihitungBenarDiterima()
    {
        Assert.True(Opsi().SignatureValid(OrderId, StatusCode, GrossAmount, TandaTanganSah));
    }

    [Fact]
    public void TandaTanganYangSalahSatuAngkaDitolak()
    {
        var rusak = TandaTanganSah[..^1] + (TandaTanganSah[^1] == 'a' ? 'b' : 'a');
        Assert.False(Opsi().SignatureValid(OrderId, StatusCode, GrossAmount, rusak));
    }

    [Fact]
    public void JumlahYangBerbedaDariYangDihitungTandaTanganDitolak()
    {
        // Tanda tangannya sah untuk 50000.00, bukan untuk 1.00 -- kabar yang menyebut jumlah
        // lain harus ikut menggagalkan verifikasinya, bukan cuma isi order_id/status_code.
        Assert.False(Opsi().SignatureValid(OrderId, StatusCode, "1.00", TandaTanganSah));
    }

    [Fact]
    public void ServerKeyKosongMenolakApaPunTermasukTandaTanganSah()
    {
        // Gagal tertutup: mesin yang belum memasang Midtrans (ServerKey kosong) tidak boleh
        // menerima notifikasi apa pun, bahkan yang kebetulan cocok dengan kunci kosong.
        Assert.False(Opsi(serverKey: "").SignatureValid(OrderId, StatusCode, GrossAmount, TandaTanganSah));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    public void TandaTanganKosongAtauNullDitolak(string? tandaTangan)
    {
        Assert.False(Opsi().SignatureValid(OrderId, StatusCode, GrossAmount, tandaTangan));
    }

    [Fact]
    public void PerbandinganTidakPeduliHurufBesarKecil()
    {
        // Midtrans mengirim heksadesimal huruf kecil, tapi verifikasinya tidak boleh gagal
        // cuma karena ada yang mengirim huruf besar.
        Assert.True(Opsi().SignatureValid(OrderId, StatusCode, GrossAmount, TandaTanganSah.ToUpperInvariant()));
    }

    [Theory]
    [InlineData("SB-Mid-server-uji", false, true)]
    [InlineData("Mid-server-uji", true, true)]
    [InlineData("Mid-server-uji", false, false)]
    [InlineData("SB-Mid-server-uji", true, false)]
    [InlineData("SB-Mid-client-uji", false, false)]
    [InlineData(" SB-Mid-server-uji", false, false)]
    [InlineData("SB-Mid-server-uji ", false, false)]
    [InlineData("", false, false)]
    public void ServerKeyHarusSesuaiLingkungan(string key, bool production, bool sah)
    {
        var opsi = new MidtransOptions { ServerKey = key, Production = production };
        Assert.Equal(sah, opsi.ServerKeySesuaiLingkungan());
    }

    [Theory]
    [InlineData("https://uji.contoh/api/webhooks/midtrans", true)]
    [InlineData("http://uji.contoh/api/webhooks/midtrans", false)]
    [InlineData("https://localhost/api/webhooks/midtrans", false)]
    [InlineData("https://127.0.0.1/api/webhooks/midtrans", false)]
    [InlineData("https://pengguna:sandi@uji.contoh/api/webhooks/midtrans", false)]
    [InlineData("https://uji.contoh/api/webhooks/midtrans#fragmen", false)]
    [InlineData("bukan-url", false)]
    public void NotifikasiMemerlukanUrlHttpsPublik(string url, bool sah)
    {
        Assert.Equal(sah, new MidtransOptions { NotificationUrl = url }.NotificationUrlSah());
    }
}
