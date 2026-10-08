using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UpnvjSuruh.Api.Migrations
{
    /// <inheritdoc />
    public partial class IdempotensiPermintaanPembatalanOrder : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "IdempotensiPermintaanPembatalanOrder",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Key = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    OrderId = table.Column<Guid>(type: "uuid", nullable: false),
                    RequestHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    ResponseJson = table.Column<string>(type: "text", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_IdempotensiPermintaanPembatalanOrder", x => x.Id);
                    table.ForeignKey(
                        name: "FK_IdempotensiPermintaanPembatalanOrder_Orders_OrderId",
                        column: x => x.OrderId,
                        principalTable: "Orders",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_IdempotensiPermintaanPembatalanOrder_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_IdempotensiPermintaanPembatalanOrder_OrderId",
                table: "IdempotensiPermintaanPembatalanOrder",
                column: "OrderId");

            migrationBuilder.CreateIndex(
                name: "IX_IdempotensiPermintaanPembatalanOrder_UserId_Key",
                table: "IdempotensiPermintaanPembatalanOrder",
                columns: new[] { "UserId", "Key" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "IdempotensiPermintaanPembatalanOrder");
        }
    }
}
