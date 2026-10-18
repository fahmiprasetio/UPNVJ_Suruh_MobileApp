using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UpnvjSuruh.Api.Migrations
{
    /// <inheritdoc />
    public partial class RemoveQrisPaymentFallback : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Transaksi lama yang dibuat oleh QRIS/simulator tidak punya checkout Snap.
            // Jangan biarkan ia tetap Pending setelah UI QR dibuang: klien harus dapat
            // menerbitkan transaksi Snap baru, bukan melihat tombol checkout kosong.
            migrationBuilder.Sql(
                """
                UPDATE \"Payments\"
                SET \"Status\" = 2
                WHERE \"Status\" = 0
                  AND (\"CheckoutUrl\" IS NULL OR btrim(\"CheckoutUrl\") = '');
                """);

            migrationBuilder.DropColumn(
                name: "QrPayload",
                table: "Payments");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "QrPayload",
                table: "Payments",
                type: "character varying(1000)",
                maxLength: 1000,
                nullable: false,
                defaultValue: "");
        }
    }
}
