using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using UpnvjSuruh.Api.Auth;

namespace UpnvjSuruh.Api.Hubs;

/// <summary>
/// Saluran realtime tempat runner dan admin menunggu. Kode sisi server mengirim
/// "OrderBroadcast" ketika order berbayar butuh runner, dan "OrderTaken" begitu ada yang
/// menerimanya, ini yang menghapus langkah relay admin lewat WA di Jalur A (rencana
/// capstone bagian 2 dan 4). "OrderChanged" dikirim ke grup admin setiap kali status sebuah
/// order berubah (rencana capstone bagian 40), menggantikan sebagian pengambilan ulang
/// berkala 15 detik di dashboard dengan kabar seketika, mengikuti pola yang sama.
///
/// Siaran runner membawa nama klien beserta alamat jemput dan alamat tujuan. Karena itu hub
/// ini tertutup untuk yang belum masuk, dan grup runner hanya diisi akun yang memang
/// memegang peran runner. Sebelumnya setiap koneksi anonim langsung dimasukkan ke grup itu,
/// yang artinya siapa pun yang bisa menjangkau alamat servernya akan menerima alamat rumah
/// pelanggan.
///
/// Satu akun boleh masuk ke kedua grup sekaligus (founder mitra yang merangkap admin dan
/// runner, bagian 14.2), karena keanggotaan grup di sini murni soal siaran mana yang ingin
/// didengar, bukan soal siapa boleh apa — penjagaan sungguhan tetap di endpoint HTTP yang
/// dipanggil sesudah kabar ini diterima.
/// </summary>
[Authorize]
public class OrderHub : Hub
{
    public const string RunnersGroup = "runners";
    public const string AdminsGroup = "admins";

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
}
