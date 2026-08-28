using System.Text;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Hubs;
using UpnvjSuruh.Api.Payments;
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

builder.Services.AddSingleton<IKalkulatorTarif, KalkulatorTarif>();
builder.Services.AddScoped<PenyelesaiPembayaran>();

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

// Urutannya wajib begini: UseAuthentication membaca siapa pemanggilnya, UseAuthorization
// memutuskan apakah ia boleh. Terbalik, atau yang pertama hilang seperti sebelumnya,
// membuat setiap [Authorize] gagal dengan "No authenticationScheme was specified".
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<OrderHub>("/hubs/orders");

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
