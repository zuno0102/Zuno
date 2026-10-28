using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddMultiWorkerBookingAssignments : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_bookings_worker_profiles_worker_profile_id",
                table: "bookings");

            migrationBuilder.DropIndex(
                name: "ix_bookings_worker_profile_id",
                table: "bookings");

            migrationBuilder.DropColumn(
                name: "assigned_role",
                table: "bookings");

            migrationBuilder.DropColumn(
                name: "worker_profile_id",
                table: "bookings");

            migrationBuilder.AddColumn<int>(
                name: "required_worker_count",
                table: "business_services",
                type: "integer",
                nullable: false,
                defaultValue: 1);

            migrationBuilder.AddColumn<int>(
                name: "required_worker_count",
                table: "bookings",
                type: "integer",
                nullable: false,
                defaultValue: 1);

            migrationBuilder.CreateTable(
                name: "booking_worker_assignments",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    booking_id = table.Column<Guid>(type: "uuid", nullable: false),
                    worker_profile_id = table.Column<Guid>(type: "uuid", nullable: false),
                    role = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    assignment_status = table.Column<short>(type: "smallint", nullable: false),
                    responded_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    completed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_booking_worker_assignments", x => x.id);
                    table.ForeignKey(
                        name: "fk_booking_worker_assignments_bookings_booking_id",
                        column: x => x.booking_id,
                        principalTable: "bookings",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_booking_worker_assignments_worker_profiles_worker_profile_id",
                        column: x => x.worker_profile_id,
                        principalTable: "worker_profiles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "ix_booking_worker_assignments_booking_id",
                table: "booking_worker_assignments",
                column: "booking_id");

            migrationBuilder.CreateIndex(
                name: "ix_booking_worker_assignments_worker_profile_id",
                table: "booking_worker_assignments",
                column: "worker_profile_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "booking_worker_assignments");

            migrationBuilder.DropColumn(
                name: "required_worker_count",
                table: "business_services");

            migrationBuilder.DropColumn(
                name: "required_worker_count",
                table: "bookings");

            migrationBuilder.AddColumn<string>(
                name: "assigned_role",
                table: "bookings",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "worker_profile_id",
                table: "bookings",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "ix_bookings_worker_profile_id",
                table: "bookings",
                column: "worker_profile_id");

            migrationBuilder.AddForeignKey(
                name: "fk_bookings_worker_profiles_worker_profile_id",
                table: "bookings",
                column: "worker_profile_id",
                principalTable: "worker_profiles",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);
        }
    }
}
