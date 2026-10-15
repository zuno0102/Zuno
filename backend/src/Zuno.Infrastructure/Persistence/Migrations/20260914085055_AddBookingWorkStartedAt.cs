using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddBookingWorkStartedAt : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "work_started_at",
                table: "bookings",
                type: "timestamp with time zone",
                nullable: true);

            // Staffing is a separate, derived track now, so "Assigned" (2) no longer belongs on
            // the order itself. Every such row was a confirmed order that happened to have crew
            // on it — leaving them alone would show those orders as never confirmed.
            migrationBuilder.Sql(
                "UPDATE bookings SET booking_status = 6 WHERE booking_status = 2;");

            // In-progress orders predate the explicit start action, so date them from their
            // schedule rather than leaving the order track with a hole in it.
            migrationBuilder.Sql(
                "UPDATE bookings SET work_started_at = scheduled_date "
                + "WHERE booking_status = 3 AND work_started_at IS NULL;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "work_started_at",
                table: "bookings");
        }
    }
}
