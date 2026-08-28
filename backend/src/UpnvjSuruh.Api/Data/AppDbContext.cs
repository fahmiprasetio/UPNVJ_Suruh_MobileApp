using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<OrderOffer> OrderOffers => Set<OrderOffer>();
    public DbSet<OrderMessage> OrderMessages => Set<OrderMessage>();
    public DbSet<OrderRunnerAssignment> OrderRunnerAssignments => Set<OrderRunnerAssignment>();
    public DbSet<Payment> Payments => Set<Payment>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<User>(entity =>
        {
            // Satu nomor HP satu akun. Ditegakkan basis data, bukan cuma dicek sebelum
            // menyimpan, karena dua pendaftaran yang tiba bersamaan lolos pemeriksaan
            // yang cuma membaca.
            entity.HasIndex(u => u.Phone).IsUnique();

            entity.Property(u => u.Name).HasMaxLength(BatasMasukan.Nama);
            entity.Property(u => u.Phone).HasMaxLength(BatasMasukan.NomorHp);
            entity.Property(u => u.Address).HasMaxLength(BatasMasukan.Alamat);

            // Disimpan sebagai integer[] Postgres, bukan JSON, supaya "cari semua runner"
            // tetap bisa dijawab satu query berindeks nanti.
            entity.Property(u => u.Roles).HasColumnType("integer[]");
        });

        modelBuilder.Entity<Order>(entity =>
        {
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
        });

        modelBuilder.Entity<OrderOffer>(entity =>
        {
            entity.Property(f => f.Note).HasMaxLength(BatasMasukan.Deskripsi);

            // Satu order tidak boleh punya dua penawaran yang sama-sama menunggu jawaban.
            // Tanpa ini, penawaran kedua diam-diam menimpa yang sedang dibaca klien, dan
            // klien menekan setuju untuk harga yang berbeda dari yang tampil di layarnya.
            entity.HasIndex(f => f.OrderId)
                .IsUnique()
                .HasFilter($"\"Status\" = {(int)OfferStatus.Pending}");

            entity.HasOne(f => f.Order)
                .WithMany(o => o.Offers)
                .HasForeignKey(f => f.OrderId)
                .OnDelete(DeleteBehavior.Cascade);
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

        modelBuilder.Entity<Payment>()
            .Property(p => p.GatewayReference)
            .HasMaxLength(BatasMasukan.ReferensiGateway);

        modelBuilder.Entity<Payment>()
            .HasOne(p => p.Order)
            .WithOne(o => o.Payment)
            .HasForeignKey<Payment>(p => p.OrderId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
