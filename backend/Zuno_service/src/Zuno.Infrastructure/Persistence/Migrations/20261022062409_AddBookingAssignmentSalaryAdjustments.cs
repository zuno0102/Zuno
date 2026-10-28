using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations;

/// <inheritdoc />
public partial class AddBookingAssignmentSalaryAdjustments : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "booking_assignment_salary_adjustments",
            columns: table => new
            {
                id = table.Column<Guid>(type: "uuid", nullable: false),
                booking_worker_assignment_id = table.Column<Guid>(type: "uuid", nullable: false),
                previous_amount = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                new_amount = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                reason = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                created_by = table.Column<Guid>(type: "uuid", nullable: true),
                modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                status = table.Column<short>(type: "smallint", nullable: false)
            },
            constraints: table =>
            {
                table.PrimaryKey("pk_booking_assignment_salary_adjustments", x => x.id);
                table.ForeignKey(
                    name: "fk_booking_assignment_salary_adjustments_booking_worker_assign",
                    column: x => x.booking_worker_assignment_id,
                    principalTable: "booking_worker_assignments",
                    principalColumn: "id",
                    onDelete: ReferentialAction.Cascade);
            });

        migrationBuilder.CreateIndex(
            name: "ix_booking_assignment_salary_adjustments_assignment_id",
            table: "booking_assignment_salary_adjustments",
            column: "booking_worker_assignment_id");
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(
            name: "booking_assignment_salary_adjustments");
    }
}
