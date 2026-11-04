using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Rent.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddRentalPaymentUpiReference : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "payee_upi_id",
                table: "rental_order_payments",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "reference",
                table: "rental_order_payments",
                type: "character varying(50)",
                maxLength: 50,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "payee_upi_id",
                table: "rental_order_payments");

            migrationBuilder.DropColumn(
                name: "reference",
                table: "rental_order_payments");
        }
    }
}
