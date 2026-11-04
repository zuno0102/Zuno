using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Rent.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddRentalCancelPerRentalDay : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<short>(
                name: "cancel_charge_type",
                table: "rental_orders",
                type: "smallint",
                nullable: false,
                defaultValue: (short)1);

            migrationBuilder.AddColumn<decimal>(
                name: "cancel_percent_cap",
                table: "rental_orders",
                type: "numeric(5,2)",
                precision: 5,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "cancel_percent_per_day",
                table: "rental_orders",
                type: "numeric(5,2)",
                precision: 5,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<short>(
                name: "cancel_charge_type",
                table: "rental_items",
                type: "smallint",
                nullable: false,
                defaultValue: (short)1);

            migrationBuilder.AddColumn<decimal>(
                name: "cancel_percent_per_day",
                table: "rental_items",
                type: "numeric(5,2)",
                precision: 5,
                scale: 2,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "ref_rental_cancel_charge_types",
                columns: table => new
                {
                    code = table.Column<short>(type: "smallint", nullable: false),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    detail = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    display_order = table.Column<short>(type: "smallint", nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ref_rental_cancel_charge_types", x => x.code);
                    table.CheckConstraint("ck_ref_rental_cancel_charge_types_code", "code IN (1, 2)");
                });

            migrationBuilder.InsertData(
                table: "ref_rental_cancel_charge_types",
                columns: new[] { "code", "detail", "display_order", "is_active", "name" },
                values: new object[,]
                {
                    { (short)1, "More as the start comes closer, e.g. 5+ days 0.5%, on the day 2%", (short)1, true, "By time left" },
                    { (short)2, "A percent for each day rented, e.g. 1% a day: a 2-day order costs 2%", (short)2, true, "Per rental day" }
                });

            migrationBuilder.AddCheckConstraint(
                name: "ck_rental_orders_cancel_charge_type",
                table: "rental_orders",
                sql: "cancel_charge_type IN (1, 2)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_rental_orders_cancel_percents",
                table: "rental_orders",
                sql: "cancel_percent_cap >= 0 AND cancel_percent_cap <= 100 AND (cancel_percent_per_day IS NULL OR (cancel_percent_per_day > 0 AND cancel_percent_per_day <= 100))");

            migrationBuilder.AddCheckConstraint(
                name: "ck_rental_items_cancel_charge",
                table: "rental_items",
                sql: "(cancel_charge_type = 1 AND cancel_percent_per_day IS NULL) OR (cancel_charge_type = 2 AND cancel_percent_per_day > 0 AND cancel_percent_per_day <= 100)");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ref_rental_cancel_charge_types");

            migrationBuilder.DropCheckConstraint(
                name: "ck_rental_orders_cancel_charge_type",
                table: "rental_orders");

            migrationBuilder.DropCheckConstraint(
                name: "ck_rental_orders_cancel_percents",
                table: "rental_orders");

            migrationBuilder.DropCheckConstraint(
                name: "ck_rental_items_cancel_charge",
                table: "rental_items");

            migrationBuilder.DropColumn(
                name: "cancel_charge_type",
                table: "rental_orders");

            migrationBuilder.DropColumn(
                name: "cancel_percent_cap",
                table: "rental_orders");

            migrationBuilder.DropColumn(
                name: "cancel_percent_per_day",
                table: "rental_orders");

            migrationBuilder.DropColumn(
                name: "cancel_charge_type",
                table: "rental_items");

            migrationBuilder.DropColumn(
                name: "cancel_percent_per_day",
                table: "rental_items");
        }
    }
}
