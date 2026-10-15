using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddAssignmentWages : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "agreed_salary_amount",
                table: "booking_worker_assignments",
                type: "numeric(10,2)",
                precision: 10,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<short>(
                name: "agreed_salary_unit",
                table: "booking_worker_assignments",
                type: "smallint",
                nullable: true);

            // 1 = PaymentStatus.Unpaid, not the 0 EF defaults to. This enum starts at 1, so 0 is
            // not a member of it at all — every row already in the table would carry a value that
            // reads back as nothing. Harmless for them in practice (no salary means the rollup
            // ignores them), but an invalid enum in a column is a trap for whoever reads it next.
            migrationBuilder.AddColumn<short>(
                name: "payment_status",
                table: "booking_worker_assignments",
                type: "smallint",
                nullable: false,
                defaultValue: (short)1);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "agreed_salary_amount",
                table: "booking_worker_assignments");

            migrationBuilder.DropColumn(
                name: "agreed_salary_unit",
                table: "booking_worker_assignments");

            migrationBuilder.DropColumn(
                name: "payment_status",
                table: "booking_worker_assignments");
        }
    }
}
