using System.Globalization;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Hubs;
using UpnvjSuruh.Api.Media;
using UpnvjSuruh.Api.Payments;
using UpnvjSuruh.Api.Perawatan;
using UpnvjSuruh.Api.Pricing;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers().AddJsonOptions(opsi =>
{
    // Enum dikirim dan diterima sebagai nama, bukan angka. Nama anggota enum di sini sengaja
    // dibuat sama persis dengan enum di aplikasi Flutter, jadi penerjemahannya cukup cocokkan
    // nama. Angka akan bekerja sampai ada yang menyisipkan anggota baru di tengah enum, dan
    // sejak saat itu order lama berubah jenis layanannya tanpa ada yang menyentuhnya.
    opsi.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
});
builder.Services.AddSignalR();

builder.Services.AddDbContext<AppDbContext>(options =>
{
    options.UseNpgsql(builder.Configuration.GetConnectionString("Default"));
    // Nilai parameter ikut tercatat di log, termasuk nomor HP. Sangat menolong saat
    // menelusuri galat basis data yang pesannya menyesatkan, dan justru karena itu harus
    // dikurung ke Development: log yang memuat data orang adalah kebocoran yang menunggu
    // giliran, dan server produksi menulis log ke tempat yang lebih banyak matanya.
    if (builder.Environment.IsDevelopment())
    {
        options.EnableSensitiveDataLogging();
    }
});

// --- Autentikasi ---

builder.Services
    .AddOptions<JwtOptions>()
    .Bind(builder.Configuration.GetSection(JwtOptions.Section))
    .ValidateDataAnnotations()
    // Divalidasi saat start, bukan saat token pertama diterbitkan. Server yang mau hidup
    // tanpa kunci penanda tangan lalu gagal di permintaan login pertama jauh lebih sulit
    // ditelusuri daripada server yang menolak menyala sambil menyebut apa yang kurang.
    .ValidateOnStart();

builder.Services.AddSingleton<ITokenService, TokenService>();

builder.Services
    .AddOptions<WebhookOptions>()
    .Bind(builder.Configuration.GetSection(WebhookOptions.Section))
    .ValidateDataAnnotations()
    .ValidateOnStart();

if (string.IsNullOrWhiteSpace(builder.Configuration[$"{WebhookOptions.Section}:Secret"]))
{
    throw new InvalidOperationException(
        "Webhook:Secret belum diisi. Di mesin pengembang jalankan: " +
        "dotnet user-secrets set \"Webhook:Secret\" \"<rahasia acak minimal 32 karakter>\". " +
        "Tanpa ini, endpoint yang menandai order lunas terbuka untuk siapa saja.");
}

// --- OTP ---

builder.Services.AddMemoryCache();
builder.Services.AddSingleton<IPenyimpanOtp, PenyimpanOtpMemori>();
builder.Services.AddSingleton<IPembuatKodeOtp, PembuatKodeOtp>();

// Jam sistem, didaftarkan sebagai layanan alih-alih dibaca lewat DateTime.UtcNow di dalam
// kelas yang membutuhkannya. Aturan yang berjendela satu jam hanya bisa diuji kalau jamnya
// bisa digeser tes, dan aturan yang tidak pernah diuji baru ketahuan rusaknya saat dipakai.
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddSingleton<IPembatasOtp, PembatasOtpMemori>();

if (builder.Environment.IsDevelopment())
{
    builder.Services.AddSingleton<IPengirimOtp, PengirimOtpLog>();
}
else
{
    // Sengaja tidak ada pengirim bawaan untuk produksi. Menyala tanpa pengirim yang benar
    // lebih berbahaya daripada tidak menyala: pengirim yang menulis kode ke log berarti
    // siapa pun yang bisa membaca log bisa masuk sebagai siapa pun. Begitu mitra memilih
    // penyedia SMS atau WhatsApp (bagian 14.8), daftarkan di sini.
    throw new InvalidOperationException(
        "Belum ada IPengirimOtp untuk lingkungan non-Development. Daftarkan penyedia SMS " +
        "atau WhatsApp sungguhan sebelum menjalankan ini di luar mesin pengembang.");
}

var jwt = builder.Configuration.GetSection(JwtOptions.Section).Get<JwtOptions>();
if (jwt is null || string.IsNullOrWhiteSpace(jwt.SigningKey))
{
    throw new InvalidOperationException(
        "Jwt:SigningKey belum diisi. Di mesin pengembang jalankan: " +
        "dotnet user-secrets set \"Jwt:SigningKey\" \"<kunci acak minimal 32 karakter>\". " +
        "Jangan pernah menuliskannya di appsettings.json.");
}

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwt.Issuer,
            ValidAudience = jwt.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.SigningKey)),
            // Bawaannya 5 menit, artinya token yang sudah kedaluwarsa masih diterima
            // selama itu. Untuk aplikasi yang tokennya berumur satu jam, kelonggaran
            // sebesar itu tidak ada gunanya.
            ClockSkew = TimeSpan.FromSeconds(30),
        };

        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                // WebSocket tidak bisa membawa header Authorization, jadi klien SignalR
                // mengirim tokennya lewat query string. Hanya diterima untuk jalur hub,
                // supaya token tidak ikut tercatat di log akses endpoint biasa.
                var token = context.Request.Query["access_token"];
                if (!string.IsNullOrEmpty(token) &&
                    context.HttpContext.Request.Path.StartsWithSegments("/hubs"))
                {
                    context.Token = token;
                }

                return Task.CompletedTask;
            },
        };
    });

builder.Services.AddAuthorization();

// --- Batas laju ---
//
// Tanpa ini, setiap endpoint di sini boleh dipanggil sesering apa pun oleh siapa pun.
// Yang paling mahal bukan bebannya melainkan endpoint minta kode: satu skrip sederhana
// cukup untuk mengirimi satu nomor ribuan SMS, dan setiap SMS itu ditagihkan penyedia ke
// mitra. Penjagaan per nomor HP untuk hal itu ada di PembatasOtp; yang di sini adalah
// jaring per pemanggil untuk sisanya.
//
// Angkanya semua di BatasLaju, termasuk alasan kenapa batas per alamat IP sengaja longgar.
builder.Services.AddRateLimiter(opsi =>
{
    // Jaring terakhir, berlaku juga untuk permintaan yang tidak menuju controller mana pun,
    // termasuk berkas foto bukti yang dilayani sebagai berkas statis.
    opsi.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(konteks =>
        RateLimitPartition.GetFixedWindowLimiter(
            BatasLaju.Pemanggil(konteks),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = BatasLaju.UmumPerMenit,
                Window = BatasLaju.JendelaUmum,
            }));

    opsi.AddPolicy(BatasLaju.KebijakanTamu, konteks =>
        RateLimitPartition.GetFixedWindowLimiter(
            BatasLaju.Pemanggil(konteks),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = BatasLaju.TamuPerJendela,
                Window = BatasLaju.JendelaTamu,
            }));

    opsi.AddPolicy(BatasLaju.KebijakanTulis, konteks =>
        RateLimitPartition.GetFixedWindowLimiter(
            BatasLaju.Pemanggil(konteks),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = BatasLaju.TulisPerMenit,
                Window = TimeSpan.FromMinutes(1),
            }));

    opsi.AddPolicy(BatasLaju.KebijakanUnggah, konteks =>
        RateLimitPartition.GetFixedWindowLimiter(
            BatasLaju.Pemanggil(konteks),
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = BatasLaju.UnggahPerJam,
                Window = TimeSpan.FromHours(1),
            }));

    // Ditolak dengan bentuk yang sama dengan penolakan lain di API ini, yaitu ProblemDetails,
    // bukan badan kosong. Aplikasi mengambil kalimat yang ditampilkan ke pengguna dari sana,
    // dan 429 berbadan kosong akan muncul di layar sebagai "server sedang bermasalah", yang
    // menyuruh orang mencoba lagi persis pada saat mencoba lagi adalah hal yang salah.
    opsi.OnRejected = async (konteks, batal) =>
    {
        var detik = konteks.Lease.TryGetMetadata(MetadataName.RetryAfter, out var jeda)
            ? (int)Math.Ceiling(jeda.TotalSeconds)
            : (int)BatasLaju.JendelaUmum.TotalSeconds;

        konteks.HttpContext.Response.StatusCode = StatusCodes.Status429TooManyRequests;
        konteks.HttpContext.Response.Headers.RetryAfter =
            detik.ToString(CultureInfo.InvariantCulture);

        await konteks.HttpContext.Response.WriteAsJsonAsync(
            new ProblemDetails
            {
                Title = "Terlalu banyak permintaan",
                Detail = $"Tunggu {detik} detik, lalu coba lagi.",
                Status = StatusCodes.Status429TooManyRequests,
            },
            batal);
    };
});

builder.Services.AddSingleton<IKalkulatorTarif, KalkulatorTarif>();
builder.Services.AddScoped<PenyelesaiPembayaran>();

// --- Foto bukti pekerjaan ---
builder.Services.AddSingleton<PenyimpanFoto>();

// --- Penanganan galat ---
//
// AddProblemDetails membuat galat yang tidak tertangani keluar sebagai ProblemDetails, bentuk
// yang sama dengan seluruh penolakan lain di API ini, alih-alih badan kosong. Isinya tetap
// tidak memuat jejak galat di luar Development.
builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<PenanganGalatKonkurensi>();

// --- Perawatan berkala ---
//
// Sebelum ini tidak ada satu pun pekerja latar di server ini, dan yang tidak ada yang
// menanyakannya tidak pernah dirapikan siapa pun: transaksi yang lewat batas waktu tetap
// berstatus menunggu selamanya, dan foto yang tidak jadi dipakai menutup order tidak pernah
// dihapus.
builder.Services.AddScoped<Penyapu>();
builder.Services.AddHostedService<PenyapuTerjadwal>();

// --- Pemeriksaan kesehatan ---
//
// Ditulis sendiri, bukan lewat AddDbContextCheck, supaya tidak menambah satu paket untuk
// satu panggilan. Yang ditanyakan CanConnectAsync: server yang menyala tapi tidak bisa
// menghubungi basis datanya tidak bisa melayani satu pun permintaan yang berguna, dan
// pemeriksa yang cuma menanyakan "prosesnya hidup?" akan melaporkannya sehat.
builder.Services.AddHealthChecks().AddCheck<PemeriksaBasisData>("basis-data");

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// --- CORS, hanya untuk pengembangan ---
//
// Aplikasi Flutter yang dijalankan di browser tunduk pada aturan asal-usul: halaman di
// localhost:port-acak tidak boleh membaca jawaban dari localhost:5059 kecuali server itu
// mengizinkannya. Di perangkat Android maupun iOS aturan ini tidak berlaku, jadi ini murni
// kebutuhan menjalankan aplikasi di browser saat mengembangkan.
//
// Kebijakannya cuma didaftarkan di Development, dan asalnya dibatasi ke localhost, bukan
// AllowAnyOrigin. Digabung dengan AllowCredentials, izin ke semua asal berarti halaman mana
// pun yang dibuka korban bisa memanggil API ini membawa sesi korban.
if (builder.Environment.IsDevelopment())
{
    builder.Services.AddCors(opsi => opsi.AddDefaultPolicy(kebijakan => kebijakan
        .SetIsOriginAllowed(asal => new Uri(asal).IsLoopback)
        .AllowAnyHeader()
        .AllowAnyMethod()
        .AllowCredentials()));
}

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Dilewati di Development. Aplikasi web dan emulator menembak alamat http biasa, dan
// pengalihan ke https membuat permintaan pertama dijawab 307 ke port yang tidak
// mendengarkan, yang di browser terbaca sebagai galat jaringan tanpa sebab yang jelas.
if (!app.Environment.IsDevelopment())
{
    // Urutannya HSTS dulu, baru pengalihan.
    //
    // Pengalihan menjawab permintaan http dengan "coba lagi di https", dan permintaan
    // pertama itu sudah terlanjur berangkat tanpa sandi: siapa pun di jaringan yang sama
    // sempat melihat alamat yang dituju, dan yang lebih buruk, sempat menjawabnya lebih
    // dulu. HSTS menutup permintaan-permintaan berikutnya dengan menyuruh browser tidak
    // pernah lagi mencoba http untuk host ini.
    //
    // Tidak berlaku untuk aplikasi Android, yang tidak menyimpan daftar HSTS. Yang dijaga
    // di sini pemakaian lewat browser: aplikasi versi web saat mengembangkan, dan
    // dashboard admin yang akan menyusul.
    app.UseHsts();
    app.UseHttpsRedirection();
}
else
{
    app.UseCors();
}

// Urutannya wajib begini: UseAuthentication membaca siapa pemanggilnya, UseAuthorization
// memutuskan apakah ia boleh. Terbalik, atau yang pertama hilang seperti sebelumnya,
// membuat setiap [Authorize] gagal dengan "No authenticationScheme was specified".
// Paling luar, supaya galat yang lolos dari middleware mana pun ikut tertangkap.
app.UseExceptionHandler();

// Satu header untuk semua jawaban: jangan menebak jenis isinya.
//
// Yang paling membutuhkannya berkas foto bukti, dan controller-nya memang memasangnya
// sendiri. Dipasang di sini juga supaya berlaku untuk jawaban mana pun, termasuk yang
// belum ada: penebakan jenis isi pada jawaban JSON yang memuat teks kiriman orang adalah
// cara lama membuat browser memperlakukannya sebagai HTML.
//
// Sengaja cuma satu ini. X-Frame-Options dan Content-Security-Policy menjaga halaman yang
// digambar browser, dan yang keluar dari sini bukan halaman melainkan JSON untuk aplikasi.
// Header yang tidak menjaga apa-apa di sini cuma membuat daftar yang panjang, dan daftar
// panjang yang isinya tidak semuanya berlaku membuat orang berhenti membacanya.
app.Use(async (konteks, berikutnya) =>
{
    konteks.Response.Headers.XContentTypeOptions = "nosniff";
    await berikutnya();
});

app.UseAuthentication();

// Di antara keduanya, bukan sesudah UseAuthorization, dan itu penting di dua arah.
//
// Sesudah UseAuthentication supaya pembatasnya sudah tahu siapa pemanggilnya dan bisa
// memberi jatah per pengguna alih-alih per alamat IP. Sebelum UseAuthorization supaya
// permintaan yang ditolak karena tidak berwenang tetap terhitung: kalau urutannya
// terbalik, endpoint yang butuh token bisa dibanjiri tanpa membawa token sama sekali,
// karena penolakannya terjadi sebelum ada yang menghitung.
app.UseRateLimiter();

app.UseAuthorization();

// Dijalankan sebelum permintaan pertama dilayani, dan tidak melakukan apa-apa kalau
// Admin:NomorHpAwal tidak diisi. Karena itu tes dan pemasangan biasa tidak menyentuhnya
// sama sekali.
await AdminAwal.PastikanAsync(app.Services);

// Foto bukti tidak lagi dilayani sebagai berkas statis.
//
// Dulu folder itu dipasang lewat UseStaticFiles, yang berarti siapa pun yang tahu alamatnya
// bisa membukanya tanpa masuk sama sekali; yang menjaganya cuma sulitnya menebak nama
// berkas. Alamat lengkapnya sendiri dikirim ke aplikasi dan tersimpan permanen di basis
// data, jadi begitu satu alamat keluar ia berlaku selamanya bagi siapa pun yang memegangnya.
//
// Sekarang berkasnya keluar lewat BerkasBuktiController, yang menanyakan hal yang sama
// dengan endpoint order: siapa penanyanya, dan apakah ia berhak melihat order itu. Jalur
// URL-nya tidak berubah, jadi alamat yang sudah tersimpan tetap menunjuk ke tempat yang
// benar.
app.MapControllers();
app.MapHub<OrderHub>("/hubs/orders");

// Dikecualikan dari batas laju, sama alasannya dengan webhook pembayaran: pemeriksa
// kesehatan memanggilnya berulang-ulang menurut jadwalnya sendiri, dan pemeriksa yang
// dijawab 429 akan menyimpulkan servernya mati lalu menyalakan alarm atau memutar lalu
// lintas ke tempat lain.
//
// Terbuka tanpa token karena yang memanggilnya bukan pengguna. Jawabannya cuma satu kata,
// tanpa sebab kegagalannya: yang perlu tahu kenapa membaca log, bukan siapa pun yang
// kebetulan menemukan alamat ini.
app.MapHealthChecks("/health").AllowAnonymous().DisableRateLimiting();

if (app.Environment.IsDevelopment())
{
    // Tiruan gateway, sepadan dengan halaman simulator di sandbox Midtrans.
    //
    // Dipasang sebagai endpoint yang cuma ada di Development, bukan sebagai controller
    // dengan penjagaan di dalamnya. Bedanya penting: controller yang dijaga tetap ada di
    // aplikasi produksi, dan penjagaannya tinggal satu baris yang bisa hilang saat
    // penyuntingan. Yang tidak pernah terdaftar tidak bisa dipanggil, apa pun yang terjadi
    // pada kodenya nanti.
    //
    // Kalau ini sampai hidup di produksi, siapa pun yang tahu alamatnya bisa memesan lalu
    // menandai pesanannya sendiri lunas, dan seluruh aturan bayar di depan jadi hiasan.
    app.MapPost("/api/dev/pembayaran/{orderId:guid}/lunas", async (
        Guid orderId,
        PenyelesaiPembayaran penyelesai,
        AppDbContext db,
        CancellationToken batal) =>
    {
        var order = await db.Orders
            .Include(o => o.Payments)
            .SingleOrDefaultAsync(o => o.Id == orderId, batal);

        if (order is null) return Results.NotFound();

        var pembayaran = order.Payments.SingleOrDefault(p => p.Menunggu);
        if (pembayaran is null)
        {
            return Results.BadRequest(new ProblemDetails
            {
                Title = "Order ini belum punya transaksi yang menunggu",
                Detail = "Buat transaksinya dulu lewat POST /api/orders/{id}/pembayaran.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        var hasil = await penyelesai.SelesaikanAsync(
            orderId,
            pembayaran.GatewayReference,
            PaymentStatus.Berhasil,
            pembayaran.Amount,
            batal);

        return hasil == HasilPenyelesaian.TidakDitemukan ? Results.NotFound() : Results.Ok();
    })
    .AllowAnonymous()
    .WithSummary("ALAT PENGUJI: menirukan gateway mengabarkan uang sudah masuk.");
}

app.Run();

/// <summary>Ditembus tes integrasi lewat WebApplicationFactory.</summary>
public partial class Program;
