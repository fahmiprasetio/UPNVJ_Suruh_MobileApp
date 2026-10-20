using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace UpnvjSuruh.Api.Migrations
{
    /// <inheritdoc />
    public partial class LiveTrackingRunner : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<double>(
                name: "DestinationLatitude",
                table: "Orders",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "DestinationLongitude",
                table: "Orders",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "PickupLatitude",
                table: "Orders",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "PickupLongitude",
                table: "Orders",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "LastAccuracyMeters",
                table: "OrderRunnerAssignments",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "LastHeadingDegrees",
                table: "OrderRunnerAssignments",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "LastLatitude",
                table: "OrderRunnerAssignments",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "LastLongitude",
                table: "OrderRunnerAssignments",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "LastSpeedMetersPerSecond",
                table: "OrderRunnerAssignments",
                type: "double precision",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LocationReceivedAt",
                table: "OrderRunnerAssignments",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "LocationRecordedAt",
                table: "OrderRunnerAssignments",
                type: "timestamp with time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DestinationLatitude",
                table: "Orders");

            migrationBuilder.DropColumn(
                name: "DestinationLongitude",
                table: "Orders");

            migrationBuilder.DropColumn(
                name: "PickupLatitude",
                table: "Orders");

            migrationBuilder.DropColumn(
                name: "PickupLongitude",
                table: "Orders");

            migrationBuilder.DropColumn(
                name: "LastAccuracyMeters",
                table: "OrderRunnerAssignments");

            migrationBuilder.DropColumn(
                name: "LastHeadingDegrees",
                table: "OrderRunnerAssignments");

            migrationBuilder.DropColumn(
                name: "LastLatitude",
                table: "OrderRunnerAssignments");

            migrationBuilder.DropColumn(
                name: "LastLongitude",
                table: "OrderRunnerAssignments");

            migrationBuilder.DropColumn(
                name: "LastSpeedMetersPerSecond",
                table: "OrderRunnerAssignments");

            migrationBuilder.DropColumn(
                name: "LocationReceivedAt",
                table: "OrderRunnerAssignments");

            migrationBuilder.DropColumn(
                name: "LocationRecordedAt",
                table: "OrderRunnerAssignments");
        }
    }
}
