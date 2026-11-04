using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Rent.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddRentalCancellationCharges : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "max_cancel_percent",
                table: "rental_sub_categories",
                type: "numeric(5,2)",
                precision: 5,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "cancel_steps",
                table: "rental_orders",
                type: "jsonb",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "cancellation_charge",
                table: "rental_orders",
                type: "numeric(14,2)",
                precision: 14,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<short>(
                name: "cancelled_by",
                table: "rental_orders",
                type: "smallint",
                nullable: true);

            migrationBuilder.AddColumn<short>(
                name: "refund_mode",
                table: "rental_orders",
                type: "smallint",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "cancel_steps",
                table: "rental_items",
                type: "jsonb",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "max_cancel_percent",
                table: "rental_categories",
                type: "numeric(5,2)",
                precision: 5,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.CreateTable(
                name: "ref_rental_refund_modes",
                columns: table => new
                {
                    code = table.Column<short>(type: "smallint", nullable: false),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    customer_text = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    business_text = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    display_order = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ref_rental_refund_modes", x => x.code);
                    table.CheckConstraint("ck_ref_rental_refund_modes_code", "code IN (1, 2)");
                });

            migrationBuilder.InsertData(
                table: "ref_rental_order_event_kinds",
                columns: new[] { "code", "name" },
                values: new object[,]
                {
                    { (short)9, "Cancellation charge" },
                    { (short)10, "Refund method chosen" }
                });

            migrationBuilder.InsertData(
                table: "ref_rental_payment_statuses",
                columns: new[] { "code", "name", "tone" },
                values: new object[] { (short)8, "Cancellation charge kept", "waiting" });

            migrationBuilder.InsertData(
                table: "ref_rental_refund_modes",
                columns: new[] { "code", "business_text", "customer_text", "display_order", "is_active", "name" },
                values: new object[,]
                {
                    { (short)1, "Zuno sends it back to the customer's card or UPI. Nothing for you to hand over.", "Your refund goes back to the card or UPI you paid with, in 1 to 5 working days.", (short)1, true, "Online" },
                    { (short)2, "You give it back yourself, in cash or by UPI, then record it here.", "Collect your refund directly from the business.", (short)2, true, "In hand" }
                });

            migrationBuilder.UpdateData(
                table: "rental_categories",
                keyColumn: "id",
                keyValue: new Guid("b2222222-0000-0000-0000-000000000001"),
                column: "max_cancel_percent",
                value: 5m);

            migrationBuilder.UpdateData(
                table: "rental_categories",
                keyColumn: "id",
                keyValue: new Guid("b2222222-0000-0000-0000-000000000002"),
                column: "max_cancel_percent",
                value: 10m);

            migrationBuilder.UpdateData(
                table: "rental_categories",
                keyColumn: "id",
                keyValue: new Guid("b2222222-0000-0000-0000-000000000003"),
                column: "max_cancel_percent",
                value: 10m);

            migrationBuilder.UpdateData(
                table: "rental_categories",
                keyColumn: "id",
                keyValue: new Guid("b2222222-0000-0000-0000-000000000004"),
                column: "max_cancel_percent",
                value: 10m);

            migrationBuilder.UpdateData(
                table: "rental_categories",
                keyColumn: "id",
                keyValue: new Guid("b2222222-0000-0000-0000-000000000005"),
                column: "max_cancel_percent",
                value: 5m);

            migrationBuilder.UpdateData(
                table: "rental_categories",
                keyColumn: "id",
                keyValue: new Guid("b2222222-0000-0000-0000-000000000006"),
                column: "max_cancel_percent",
                value: 5m);

            migrationBuilder.UpdateData(
                table: "rental_categories",
                keyColumn: "id",
                keyValue: new Guid("b2222222-0000-0000-0000-000000000007"),
                column: "max_cancel_percent",
                value: 10m);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0001-000000000001"),
                column: "max_cancel_percent",
                value: 2m);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0001-000000000002"),
                column: "max_cancel_percent",
                value: 2m);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0001-000000000003"),
                column: "max_cancel_percent",
                value: 5m);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0001-000000000004"),
                column: "max_cancel_percent",
                value: 10m);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0002-000000000001"),
                column: "max_cancel_percent",
                value: null);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0002-000000000002"),
                column: "max_cancel_percent",
                value: null);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0002-000000000003"),
                column: "max_cancel_percent",
                value: null);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0003-000000000001"),
                column: "max_cancel_percent",
                value: null);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0003-000000000002"),
                column: "max_cancel_percent",
                value: null);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0003-000000000003"),
                column: "max_cancel_percent",
                value: null);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0003-000000000004"),
                column: "max_cancel_percent",
                value: null);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0004-000000000001"),
                column: "max_cancel_percent",
                value: null);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0004-000000000002"),
                column: "max_cancel_percent",
                value: null);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0004-000000000003"),
                column: "max_cancel_percent",
                value: null);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0005-000000000001"),
                column: "max_cancel_percent",
                value: null);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0005-000000000002"),
                column: "max_cancel_percent",
                value: null);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0005-000000000003"),
                column: "max_cancel_percent",
                value: null);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0006-000000000001"),
                column: "max_cancel_percent",
                value: null);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0006-000000000002"),
                column: "max_cancel_percent",
                value: null);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0006-000000000003"),
                column: "max_cancel_percent",
                value: null);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0006-000000000004"),
                column: "max_cancel_percent",
                value: null);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0007-000000000001"),
                column: "max_cancel_percent",
                value: null);

            migrationBuilder.UpdateData(
                table: "rental_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c3333333-0000-0000-0007-000000000002"),
                column: "max_cancel_percent",
                value: null);

            // Items and orders from before keep free cancellation: no steps, rather than none read back as null.
            migrationBuilder.Sql("UPDATE rental_items SET cancel_steps = '[]' WHERE cancel_steps IS NULL;");
            migrationBuilder.Sql("UPDATE rental_orders SET cancel_steps = '[]' WHERE cancel_steps IS NULL;");

            migrationBuilder.AddCheckConstraint(
                name: "ck_rental_sub_categories_max_cancel_percent",
                table: "rental_sub_categories",
                sql: "max_cancel_percent IS NULL OR (max_cancel_percent >= 0 AND max_cancel_percent <= 100)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_rental_orders_cancellation_charge",
                table: "rental_orders",
                sql: "cancellation_charge >= 0 AND cancellation_charge <= amount");

            migrationBuilder.AddCheckConstraint(
                name: "ck_rental_orders_cancelled_by",
                table: "rental_orders",
                sql: "cancelled_by IS NULL OR cancelled_by IN (1, 2)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_rental_orders_refund_mode",
                table: "rental_orders",
                sql: "refund_mode IS NULL OR refund_mode IN (1, 2)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_rental_categories_max_cancel_percent",
                table: "rental_categories",
                sql: "max_cancel_percent >= 0 AND max_cancel_percent <= 100");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ref_rental_refund_modes");

            migrationBuilder.DropCheckConstraint(
                name: "ck_rental_sub_categories_max_cancel_percent",
                table: "rental_sub_categories");

            migrationBuilder.DropCheckConstraint(
                name: "ck_rental_orders_cancellation_charge",
                table: "rental_orders");

            migrationBuilder.DropCheckConstraint(
                name: "ck_rental_orders_cancelled_by",
                table: "rental_orders");

            migrationBuilder.DropCheckConstraint(
                name: "ck_rental_orders_refund_mode",
                table: "rental_orders");

            migrationBuilder.DropCheckConstraint(
                name: "ck_rental_categories_max_cancel_percent",
                table: "rental_categories");

            migrationBuilder.DeleteData(
                table: "ref_rental_order_event_kinds",
                keyColumn: "code",
                keyValue: (short)9);

            migrationBuilder.DeleteData(
                table: "ref_rental_order_event_kinds",
                keyColumn: "code",
                keyValue: (short)10);

            migrationBuilder.DeleteData(
                table: "ref_rental_payment_statuses",
                keyColumn: "code",
                keyValue: (short)8);

            migrationBuilder.DropColumn(
                name: "max_cancel_percent",
                table: "rental_sub_categories");

            migrationBuilder.DropColumn(
                name: "cancel_steps",
                table: "rental_orders");

            migrationBuilder.DropColumn(
                name: "cancellation_charge",
                table: "rental_orders");

            migrationBuilder.DropColumn(
                name: "cancelled_by",
                table: "rental_orders");

            migrationBuilder.DropColumn(
                name: "refund_mode",
                table: "rental_orders");

            migrationBuilder.DropColumn(
                name: "cancel_steps",
                table: "rental_items");

            migrationBuilder.DropColumn(
                name: "max_cancel_percent",
                table: "rental_categories");
        }
    }
}
