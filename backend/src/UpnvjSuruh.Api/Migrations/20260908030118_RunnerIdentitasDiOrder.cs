using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UpnvjSuruh.Api.Migrations
{
    /// <inheritdoc />
    public partial class RunnerIdentitasDiOrder : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_OrderOffers_CreatedByRunnerId",
                table: "OrderOffers",
                column: "CreatedByRunnerId");

            migrationBuilder.AddForeignKey(
                name: "FK_OrderOffers_Users_CreatedByRunnerId",
                table: "OrderOffers",
                column: "CreatedByRunnerId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_OrderOffers_Users_CreatedByRunnerId",
                table: "OrderOffers");

            migrationBuilder.DropIndex(
                name: "IX_OrderOffers_CreatedByRunnerId",
                table: "OrderOffers");
        }
    }
}
