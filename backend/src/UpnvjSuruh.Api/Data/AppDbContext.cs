using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Pricing;

namespace UpnvjSuruh.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<OrderOffer> OrderOffers => Set<OrderOffer>();
    public DbSet<OrderMessage> OrderMessages => Set<OrderMessage>();
    public DbSet<OrderMessageRead> OrderMessageReads => Set<OrderMessageRead>();
    public DbSet<OrderRunnerAssignment> OrderRunnerAssignments => Set<OrderRunnerAssignment>();
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<UserRoleChange> UserRoleChanges => Set<UserRoleChange>();
    public DbSet<OrderRelease> OrderReleases => Set<OrderRelease>();
    public DbSet<UserSuspensionChange> UserSuspensionChanges => Set<UserSuspensionChange>();
    public DbSet<OrderStatusChange> OrderStatusChanges => Set<OrderStatusChange>();
    public DbSet<PerangkatNotifikasi> PerangkatNotifikasi => Set<PerangkatNotifikasi>();
    public DbSet<TarifSetting> TarifSettings => Set<TarifSetting>();
    public DbSet<PayoutSetting> PayoutSettings => Set<PayoutSetting>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<User>(entity =>
        {
            // Satu nomor HP satu akun. Ditegakkan basis data, bukan cuma dicek sebelum
            // menyimpan, karena dua pendaftaran yang tiba bersamaan lolos pemeriksaan
            // yang cuma membaca.
            entity.HasIndex(u => u.Phone).IsUnique();

            entity.Property(u => u.SuspendedReason).HasMaxLength(BatasMasukan.Deskripsi);

            entity.Property(u => u.Name).HasMaxLength(BatasMasukan.Nama);
            entity.Property(u => u.Phone).HasMaxLength(BatasMasukan.NomorHp);
            entity.Property(u => u.Address).HasMaxLength(BatasMasukan.Alamat);
            entity.Property(u => u.PasswordHash).HasMaxLength(BatasMasukan.HashPassword);

            // Disimpan sebagai integer[] Postgres, bukan JSON, supaya "cari semua runner"
            // tetap bisa dijawab satu query berindeks nanti.
            entity.Property(u => u.Roles).HasColumnType("integer[]");
        });

        modelBuilder.Entity<UserRoleChange>(entity =>
        {
            entity.Property(p => p.RolesBefore).HasColumnType("integer[]");
            entity.Property(p => p.RolesAfter).HasColumnType("integer[]");
            entity.Property(p => p.Reason).HasMaxLength(BatasMasukan.Deskripsi);

            entity.HasIndex(p => p.UserId);

            entity.HasOne(p => p.User)
                .WithMany()
                .HasForeignKey(p => p.UserId)
                // Catatan audit tidak ikut hilang bersama akunnya. Justru akun yang dihapus
                // adalah akun yang paling mungkin dipertanyakan belakangan.
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<UserSuspensionChange>(entity =>
        {
            entity.Property(p => p.Reason).HasMaxLength(BatasMasukan.Deskripsi);

            entity.HasIndex(p => p.UserId);

            entity.HasOne(p => p.User)
                .WithMany()
                .HasForeignKey(p => p.UserId)
                // Sama seperti dua catatan audit lainnya: justru akun yang dihapus adalah
                // akun yang paling mungkin dipertanyakan belakangan.
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<OrderRelease>(entity =>
        {
            entity.Property(p => p.Reason).HasMaxLength(BatasMasukan.Deskripsi);

            // Diindeks lewat runnernya, bukan lewat ordernya: pertanyaan yang dijawab tabel
            // ini "berapa sering orang ini melepas", bukan "siapa saja yang pernah melepas
            // order ini" — order yang dilepas dua kali oleh dua orang berbeda sudah cukup
            // aneh untuk diperiksa satu per satu.
            entity.HasIndex(p => p.RunnerId);

            entity.HasOne(p => p.Order)
                .WithMany()
                .HasForeignKey(p => p.OrderId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(p => p.Runner)
                .WithMany()
                .HasForeignKey(p => p.RunnerId)
                // Sama seperti catatan peran: justru akun yang dihapus adalah akun yang
                // paling mungkin dipertanyakan belakangan.
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<OrderStatusChange>(entity =>
        {
            // Diindeks lewat ordernya: pertanyaan yang dijawab tabel ini "apa saja yang
            // pernah terjadi pada order ini", bukan "seberapa sering orang ini memicu
            // perpindahan status".
            entity.HasIndex(p => p.OrderId);

            entity.HasOne(p => p.Order)
                .WithMany()
                .HasForeignKey(p => p.OrderId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(p => p.ChangedByUser)
                .WithMany()
                .HasForeignKey(p => p.ChangedByUserId)
                // Sama seperti tiga catatan audit lainnya: justru akun yang dihapus adalah
                // akun yang paling mungkin dipertanyakan belakangan.
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<PerangkatNotifikasi>(entity =>
        {
            entity.Property(p => p.Token).HasMaxLength(BatasMasukan.TokenPerangkat);

            // Unik pada tokennya saja, bukan pada pasangan (akun, token). Alasannya lengkap
            // di PerangkatNotifikasi: token itu milik pemasangan aplikasi, dan HP yang
            // dipakai bergantian dua orang akan menyodorkan token yang sama untuk akun yang
            // berbeda. Baris ini yang membuat pendaftaran ulang jadi pemindahan.
            entity.HasIndex(p => p.Token).IsUnique();

            entity.HasOne(p => p.User)
                .WithMany()
                .HasForeignKey(p => p.UserId)
                // Berbeda dari tabel-tabel catatan audit, yang sengaja menahan penghapusan
                // akun: ini bukan catatan, cuma alamat kirim yang berlaku selama akunnya
                // ada. Akun yang hilang tidak meninggalkan pertanyaan yang bisa dijawab
                // barisnya.
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Order>(entity =>
        {
            // Nomornya dibangkitkan basis data, bukan dihitung di kode. Menghitungnya di
            // kode berarti membaca nomor terakhir lalu menambah satu, dan dua order yang
            // dibuat bersamaan akan membaca angka yang sama.
            entity.Property(o => o.OrderCode)
                .HasMaxLength(BatasMasukan.KodeOrder)
                .HasDefaultValueSql("'SRH-' || lpad(nextval('order_code_seq')::text, 4, '0')")
                .ValueGeneratedOnAdd();

            entity.HasIndex(o => o.OrderCode).IsUnique();

            // Status diindeks karena dua kueri menyaring dengannya, dan keduanya jalan
            // berulang-ulang: daftar siaran runner, yang diambil ulang aplikasi setiap lima
            // belas detik selama layar order masuk terbuka, dan antrean penawaran admin.
            //
            // Tanpa indeks, keduanya memindai seluruh tabel order untuk menemukan segelintir
            // baris yang sedang berstatus itu. Biayanya tumbuh seiring seluruh riwayat,
            // sementara yang dicari justru cuma yang sedang berjalan, yaitu bagian yang tidak
            // ikut tumbuh.
            entity.HasIndex(o => o.Status);

            // Indeks parsial: yang dicari dashboard admin cuma order yang sedang meminta
            // dibatalkan, dan itu segelintir baris di antara seluruh riwayat. Indeks penuh
            // di kolom yang hampir selalu null cuma menyimpan daftar null yang tidak pernah
            // dibaca siapa pun.
            entity.HasIndex(o => o.CancellationRequestedAt)
                .HasFilter("\"CancellationRequestedAt\" IS NOT NULL");

            entity.Property(o => o.Description).HasMaxLength(BatasMasukan.Deskripsi);
            entity.Property(o => o.PickupAddress).HasMaxLength(BatasMasukan.Alamat);
            entity.Property(o => o.DestinationAddress).HasMaxLength(BatasMasukan.Alamat);
            entity.Property(o => o.HandoverNote).HasMaxLength(BatasMasukan.CatatanSerahTerima);
            entity.Property(o => o.PhotoUrl).HasMaxLength(BatasMasukan.Url);
            entity.Property(o => o.VoiceNoteUrl).HasMaxLength(BatasMasukan.Url);

            // Postgres system column used as optimistic-concurrency token: a runner-accept
            // that races against a stale read of Order fails instead of silently overwriting.
            entity.Property<uint>("xmin").HasColumnName("xmin").IsRowVersion();
            entity.HasOne(o => o.Client)
                .WithMany()
                .HasForeignKey(o => o.ClientId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<OrderRunnerAssignment>(entity =>
        {
            // A runner can only accept the same order once, the DB, not just the UI, enforces this.
            entity.HasIndex(a => new { a.OrderId, a.RunnerId }).IsUnique();

            entity.HasOne(a => a.Order)
                .WithMany(o => o.RunnerAssignments)
                .HasForeignKey(a => a.OrderId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(a => a.Runner)
                .WithMany()
                .HasForeignKey(a => a.RunnerId)
                .OnDelete(DeleteBehavior.Restrict);

            // Sengaja tidak ada indeks tambahan untuk rekap pembayaran. Indeks yang dibuat EF
            // sendiri untuk kunci asing RunnerId sudah menjawab pertanyaan yang ditanyakan
            // rekap dan layar pendapatan ("penugasan milik runner ini"), dan indeks kedua di
            // kolom yang sama, disaring pada yang belum lunas, justru menggantikan indeks itu
            // alih-alih menambahnya: yang tersaring tidak bisa dipakai kueri yang membaca
            // riwayat lengkap seorang runner, termasuk yang sudah lunas.
        });

        modelBuilder.Entity<OrderOffer>(entity =>
        {
            entity.Property(f => f.Note).HasMaxLength(BatasMasukan.Deskripsi);

            // Satu runner tidak boleh punya dua penawaran yang sama-sama menunggu jawaban
            // pada order yang sama. Tanpa ini, penawaran kedua dari runner itu sendiri diam-
            // diam menimpa yang sedang dibaca klien, dan klien menekan setuju untuk harga
            // yang berbeda dari yang tampil di layarnya. Runner LAIN tetap boleh punya
            // penawaran pending miliknya sendiri pada order yang sama persis pada saat
            // bersamaan, itu bukan tabrakan, itu memang tawar-menawar; makanya kuncinya
            // pasangan (OrderId, CreatedByRunnerId), bukan OrderId sendirian seperti dulu.
            entity.HasIndex(f => new { f.OrderId, f.CreatedByRunnerId })
                .IsUnique()
                .HasFilter($"\"Status\" = {(int)OfferStatus.Pending}");

            entity.HasOne(f => f.Order)
                .WithMany(o => o.Offers)
                .HasForeignKey(f => f.OrderId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(f => f.CreatedByRunner)
                .WithMany()
                .HasForeignKey(f => f.CreatedByRunnerId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<OrderMessage>(entity =>
        {
            entity.Property(m => m.Text).HasMaxLength(BatasMasukan.PesanChat);
            entity.Property(m => m.PhotoUrl).HasMaxLength(BatasMasukan.Url);
            entity.Property(m => m.VoiceNoteUrl).HasMaxLength(BatasMasukan.Url);

            entity.HasOne(m => m.Order)
                .WithMany(o => o.Messages)
                .HasForeignKey(m => m.OrderId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<OrderMessageRead>(entity =>
        {
            // Satu baris per (order, pengguna, jalur). Menandai ulang jalur yang sama
            // menimpa penanda waktunya, bukan menambah baris -- lihat OrderMessageRead
            // soal kenapa jalur umum memakai Guid.Empty, bukan null, di kolom ini.
            entity.HasIndex(r => new { r.OrderId, r.UserId, r.RunnerPenawarId }).IsUnique();

            entity.HasOne(r => r.Order)
                .WithMany()
                .HasForeignKey(r => r.OrderId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(r => r.User)
                .WithMany()
                .HasForeignKey(r => r.UserId)
                // Sama seperti PerangkatNotifikasi: penanda baca bukan catatan yang perlu
                // bertahan sesudah akunnya hilang, cuma keadaan yang berlaku selama akunnya
                // ada.
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<Payment>(entity =>
        {
            entity.Property(p => p.GatewayReference).HasMaxLength(BatasMasukan.ReferensiGateway);
            entity.Property(p => p.QrPayload).HasMaxLength(BatasMasukan.QrPayload);
            entity.Property(p => p.RefundReason).HasMaxLength(BatasMasukan.Deskripsi);

            // Satu order tidak boleh punya dua transaksi yang sama-sama menunggu. Membuka
            // ulang layar bayar tidak melahirkan QR baru, dan dua QR untuk satu order berarti
            // klien bisa membayar dua kali untuk pekerjaan yang sama.
            entity.HasIndex(p => p.OrderId)
                .IsUnique()
                .HasFilter($"\"Status\" = {(int)PaymentStatus.Pending}");

            // Dan satu order tidak boleh punya dua transaksi dengan referensi gateway yang
            // sama. Penyelesai pembayaran mencari transaksi lewat referensi itu dengan
            // SingleOrDefault, jadi dua baris berreferensi sama tidak menghasilkan pilihan
            // yang salah melainkan lemparan, pada jalur yang menangani kabar uang masuk.
            //
            // Jalur yang ada sekarang tidak bisa melahirkannya, dan justru itu alasannya
            // dijadikan aturan basis data: yang mustahil hari ini cuma mustahil selama tidak
            // ada yang menambah jalan masuk baru.
            entity.HasIndex(p => new { p.OrderId, p.GatewayReference }).IsUnique();
        });

        modelBuilder.Entity<Payment>()
            .HasOne(p => p.Order)
            .WithMany(o => o.Payments)
            .HasForeignKey(p => p.OrderId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<TarifSetting>(entity =>
        {
            // Baris awalnya persis angka Pricing.TarifConfig, dijaga tetap sama dengan
            // aplikasi mobile oleh TarifSelarasDenganMobileTests. Sesudah baris ini ada,
            // yang berikutnya menyunting isinya, bukan menambah baris baru, jadi migrasi
            // ini satu-satunya tempat HasData untuk entitas ini akan pernah muncul.
            entity.HasData(new TarifSetting
            {
                Id = TarifSetting.SatuSatunyaId,
                AnjemTarifDasar = TarifConfig.AnjemTarifDasar,
                AnjemTarifPerKm = TarifConfig.AnjemTarifPerKm,
                AnjemJarakMinimalKm = TarifConfig.AnjemJarakMinimalKm,
                AnjemJarakMaksimalKm = TarifConfig.AnjemJarakMaksimalKm,
                JastipMakananFee = TarifConfig.JastipMakananFee,
                JastipBarangFee = TarifConfig.JastipBarangFee,
                JastipBarangTarifPerKm = TarifConfig.JastipBarangTarifPerKm,
            });
        });

        modelBuilder.Entity<PayoutSetting>(entity =>
        {
            // Barisnya disemai kosong: mode bawaan, nol persen, dan DiaturPada tetap null.
            //
            // Nilai awalnya sengaja bukan tebakan bagi hasil yang masuk akal. Angka yang
            // kelihatan wajar akan dipakai diam-diam oleh setiap order yang selesai, dan tidak
            // ada yang akan menyadarinya sampai ada runner yang menghitung sendiri bayarannya.
            // Selama DiaturPada masih null, tidak ada bayaran yang dibekukan sama sekali
            // (lihat PayoutSetting), jadi keadaan "mitra belum menjawab" tetap terlihat sebagai
            // keadaan yang belum dijawab, bukan menyamar jadi jawaban.
            entity.HasData(new PayoutSetting { Id = PayoutSetting.SatuSatunyaId });
        });
    }
}
