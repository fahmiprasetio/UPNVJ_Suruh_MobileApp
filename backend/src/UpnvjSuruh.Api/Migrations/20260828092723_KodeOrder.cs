using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UpnvjSuruh.Api.Migrations
{
    /// <inheritdoc />
    public partial class KodeOrder : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Sequence-nya dibuat lebih dulu, karena nilai bawaan kolomnya memanggilnya.
            // Dimulai dari 412 supaya menyambung dengan kode contoh yang sudah dipakai
            // di aplikasi selama pengembangan, jadi tangkapan layar dan catatan lama
            // tidak tiba-tiba menyebut nomor yang tidak pernah ada.
            migrationBuilder.Sql("CREATE SEQUENCE IF NOT EXISTS order_code_seq START 412;");

            migrationBuilder.AddColumn<string>(
                name: "OrderCode",
                table: "Orders",
                type: "character varying(20)",
                maxLength: 20,
                nullable: false,
                defaultValueSql: "'SRH-' || lpad(nextval('order_code_seq')::text, 4, '0')");

            migrationBuilder.CreateIndex(
                name: "IX_Orders_OrderCode",
                table: "Orders",
                column: "OrderCode",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql("DROP SEQUENCE IF EXISTS order_code_seq;");

            migrationBuilder.DropIndex(
                name: "IX_Orders_OrderCode",
                table: "Orders");

            migrationBuilder.DropColumn(
                name: "OrderCode",
                table: "Orders");
        }
    }
}
