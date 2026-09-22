using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UpnvjSuruh.Api.Migrations
{
    /// <inheritdoc />
    public partial class IdempotensiPembuatanPenawaran : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "IdempotensiPembuatanPenawaran",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Key = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    RunnerId = table.Column<Guid>(type: "uuid", nullable: false),
                    OrderId = table.Column<Guid>(type: "uuid", nullable: false),
                    RequestHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    OfferId = table.Column<Guid>(type: "uuid", nullable: false),
                    ResponseJson = table.Column<string>(type: "text", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_IdempotensiPembuatanPenawaran", x => x.Id);
                    table.ForeignKey(
                        name: "FK_IdempotensiPembuatanPenawaran_OrderOffers_OfferId",
                        column: x => x.OfferId,
                        principalTable: "OrderOffers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_IdempotensiPembuatanPenawaran_Orders_OrderId",
                        column: x => x.OrderId,
                        principalTable: "Orders",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_IdempotensiPembuatanPenawaran_Users_RunnerId",
                        column: x => x.RunnerId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_IdempotensiPembuatanPenawaran_OfferId",
                table: "IdempotensiPembuatanPenawaran",
                column: "OfferId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_IdempotensiPembuatanPenawaran_OrderId",
                table: "IdempotensiPembuatanPenawaran",
                column: "OrderId");

            migrationBuilder.CreateIndex(
                name: "IX_IdempotensiPembuatanPenawaran_RunnerId_Key",
                table: "IdempotensiPembuatanPenawaran",
                columns: new[] { "RunnerId", "Key" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "IdempotensiPembuatanPenawaran");
        }
    }
}
