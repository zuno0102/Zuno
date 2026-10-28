using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddBookingConfirmedAndAssignedRole : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "worker_role",
                table: "bookings");

            migrationBuilder.AddColumn<string>(
                name: "assigned_role",
                table: "bookings",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "assigned_role",
                table: "bookings");

            migrationBuilder.AddColumn<short>(
                name: "worker_role",
                table: "bookings",
                type: "smallint",
                nullable: true);
        }
    }
}
