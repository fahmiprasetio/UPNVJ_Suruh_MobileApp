using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Data;

namespace UpnvjSuruh.Api.Hubs;

/// <summary>
/// Saluran realtime tempat runner, admin, dan klien yang sedang membayar menunggu. Kode
/// sisi server mengirim "OrderBroadcast" ketika order berbayar butuh runner, dan
/// "OrderTaken" begitu ada yang menerimanya, ini yang menghapus langkah relay admin lewat
/// WA di Jalur A (rencana capstone bagian 2 dan 4). "OrderChanged" dikirim ke grup admin
/// setiap kali status sebuah order berubah (rencana capstone bagian 40), menggantikan
/// sebagian pengambilan ulang berkala 15 detik di dashboard dengan kabar seketika.
/// "PaymentChanged" dikirim ke grup satu order tertentu setiap kali tagihannya bergeser
/// dari menunggu (rencana capstone bagian 41), menggantikan sebagian pengambilan ulang
/// berkala 3 detik di layar bayar.
///
/// Siaran runner membawa nama klien beserta alamat jemput dan alamat tujuan. Karena itu hub
/// ini tertutup untuk yang belum masuk, dan grup runner hanya diisi akun yang memang
/// memegang peran runner. Sebelumnya setiap koneksi anonim langsung dimasukkan ke grup itu,
/// yang artinya siapa pun yang bisa menjangkau alamat servernya akan menerima alamat rumah
/// pelanggan.
///
/// Satu akun boleh masuk ke grup runner dan grup admin sekaligus (founder mitra yang
/// merangkap keduanya, bagian 14.2), karena keanggotaan grup di sini murni soal siaran mana
/// yang ingin didengar, bukan soal siapa boleh apa — penjagaan sungguhan tetap di endpoint
/// HTTP yang dipanggil sesudah kabar ini diterima.
///
/// ## Kenapa grup per-order beda dari dua grup di atas
///
/// Grup runner dan grup admin diisi otomatis begitu koneksinya dibuka, ditentukan semata
/// dari peran di token. Grup per-order tidak bisa begitu: klien boleh punya lebih dari satu
/// order yang sama-sama menunggu bayar (memesan dua kali sebelum melunasi salah satunya),
/// dan yang perlu diikuti cuma order yang layarnya sedang dibuka, bukan seluruh order
/// miliknya. Karena itu bergabungnya lewat method <see cref="GabungOrder"/> yang dipanggil
/// klien sendiri saat layar bayar dibuka, bukan diputuskan otomatis dari peran.
///
/// Keanggotaannya diperiksa terhadap kepemilikan order, tidak seperti dua grup di atas.
/// Kabar yang disiarkan ke grup ini cuma menyebut id order dan tidak membawa apa pun yang
/// sensitif (sama seperti dua grup lain), tapi membiarkan siapa pun bergabung ke grup order
/// mana pun tetap membocorkan satu hal: kapan order itu berubah status, informasi yang
/// bukan urusan orang yang bukan pemiliknya.
/// </summary>
[Authorize]
public class OrderHub(AppDbContext db) : Hub
{
    public const string RunnersGroup = "runners";
    public const string AdminsGroup = "admins";

    /// <summary>Nama grup satu order tertentu, dipakai sisi klien maupun sisi server.</summary>
    public static string GrupOrder(Guid orderId) => $"order-{orderId:N}";

    public override async Task OnConnectedAsync()
    {
        if (Context.User?.IsInRole(Peran.Runner) == true)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, RunnersGroup);
        }

        if (Context.User?.IsInRole(Peran.Admin) == true)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, AdminsGroup);
        }

        await base.OnConnectedAsync();
    }

    /// <summary>
    /// Klien meminta didengarkan untuk satu order tertentu, biasanya begitu layar bayar
    /// dibuka.
    /// </summary>
    /// <remarks>
    /// Permintaan bergabung ke order yang bukan miliknya diam-diam diabaikan, tidak
    /// dijawab galat. Method hub ini bisa dipanggil siapa pun yang sudah masuk dengan id
    /// order karangan sendiri, dan menjawabnya beda antara "order ini bukan milikmu" dan
    /// "order ini tidak ada" akan membuatnya alat menebak-nebak id order siapa saja yang
    /// sedang berjalan.
    /// </remarks>
    [Authorize(Roles = Peran.Klien)]
    public async Task GabungOrder(Guid orderId)
    {
        var milikPemanggil = await db.Orders
            .AnyAsync(o => o.Id == orderId && o.ClientId == Context.User!.Id());

        if (!milikPemanggil) return;

        await Groups.AddToGroupAsync(Context.ConnectionId, GrupOrder(orderId));
    }

    /// <summary>
    /// Klien berhenti mendengarkan satu order, begitu layar bayarnya ditutup.
    /// </summary>
    /// <remarks>
    /// Tanpa ini, klien yang membuka beberapa layar bayar berturut-turut dalam satu sesi
    /// (order pertama kedaluwarsa, coba lagi dengan order baru) akan terus menumpuk
    /// keanggotaan grup selama koneksinya hidup — satu koneksi dipakai sepanjang sesi,
    /// bukan dibuka ulang tiap layar (bagian 37.5). Tidak perlu pemeriksaan kepemilikan
    /// seperti <see cref="GabungOrder"/>: keluar dari grup yang tidak pernah diikuti bukan
    /// tindakan yang bisa disalahgunakan untuk mengetahui apa pun.
    /// </remarks>
    public async Task TinggalkanOrder(Guid orderId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, GrupOrder(orderId));
    }
}
