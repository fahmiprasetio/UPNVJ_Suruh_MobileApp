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

            // Disimpan sebagai integer[] Postgres, bukan JSON, supaya "cari semua runner"
            // tetap bisa dijawab satu query berindeks nanti.
            entity.Property(u => u.Roles).HasColumnType("integer[]");
        });

        modelBuilder.Entity<Order>(entity =>
        {
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

        modelBuilder.Entity<OrderOffer>()
            .HasOne(f => f.Order)
            .WithMany(o => o.Offers)
            .HasForeignKey(f => f.OrderId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<OrderMessage>()
            .HasOne(m => m.Order)
            .WithMany(o => o.Messages)
            .HasForeignKey(m => m.OrderId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<Payment>()
            .HasOne(p => p.Order)
            .WithOne(o => o.Payment)
            .HasForeignKey<Payment>(p => p.OrderId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
