using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Rent.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddRentalPayments : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "advance_due",
                table: "rental_orders",
                type: "numeric(14,2)",
                precision: 14,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "amount",
                table: "rental_orders",
                type: "numeric(14,2)",
                precision: 14,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "hold_until",
                table: "rental_orders",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<short>(
                name: "price_type",
                table: "rental_orders",
                type: "smallint",
                nullable: false,
                defaultValue: (short)0);

            migrationBuilder.AddColumn<decimal>(
                name: "unit_price",
                table: "rental_orders",
                type: "numeric(12,2)",
                precision: 12,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<int>(
                name: "units",
                table: "rental_orders",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<decimal>(
                name: "amount",
                table: "rental_order_events",
                type: "numeric(14,2)",
                precision: 14,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<short>(
                name: "payment_method",
                table: "rental_order_events",
                type: "smallint",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "advance_amount",
                table: "rental_items",
                type: "numeric(12,2)",
                precision: 12,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<short>(
                name: "advance_type",
                table: "rental_items",
                type: "smallint",
                nullable: false,
                defaultValue: (short)0);

            migrationBuilder.AddColumn<string>(
                name: "upi_id",
                table: "rental_businesses",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "requires_paid",
                table: "ref_rental_order_transitions",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "ref_rental_advance_types",
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
                    table.PrimaryKey("pk_ref_rental_advance_types", x => x.code);
                });

            migrationBuilder.CreateTable(
                name: "ref_rental_payment_methods",
                columns: table => new
                {
                    code = table.Column<short>(type: "smallint", nullable: false),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    business_may_record = table.Column<bool>(type: "boolean", nullable: false),
                    display_order = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ref_rental_payment_methods", x => x.code);
                });

            migrationBuilder.CreateTable(
                name: "ref_rental_payment_statuses",
                columns: table => new
                {
                    code = table.Column<short>(type: "smallint", nullable: false),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    tone = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ref_rental_payment_statuses", x => x.code);
                });

            migrationBuilder.CreateTable(
                name: "rental_order_payments",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    rental_order_id = table.Column<Guid>(type: "uuid", nullable: false),
                    kind = table.Column<short>(type: "smallint", nullable: false),
                    method = table.Column<short>(type: "smallint", nullable: false),
                    amount = table.Column<decimal>(type: "numeric(14,2)", precision: 14, scale: 2, nullable: false),
                    provider_order_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    provider_payment_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    recorded_by_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    recorded_by_role = table.Column<short>(type: "smallint", nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_rental_order_payments", x => x.id);
                    table.CheckConstraint("ck_rental_order_payments_amount", "amount > 0");
                    table.CheckConstraint("ck_rental_order_payments_kind", "kind IN (1, 2, 3)");
                    table.CheckConstraint("ck_rental_order_payments_method", "method IN (1, 2, 3)");
                    table.ForeignKey(
                        name: "fk_rental_order_payments_rental_orders_rental_order_id",
                        column: x => x.rental_order_id,
                        principalTable: "rental_orders",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "rental_payment_checkouts",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    rental_order_id = table.Column<Guid>(type: "uuid", nullable: false),
                    kind = table.Column<short>(type: "smallint", nullable: false),
                    amount = table.Column<decimal>(type: "numeric(14,2)", precision: 14, scale: 2, nullable: false),
                    provider_order_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    completed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_rental_payment_checkouts", x => x.id);
                    table.CheckConstraint("ck_rental_payment_checkouts_amount", "amount > 0");
                    table.ForeignKey(
                        name: "fk_rental_payment_checkouts_rental_orders_rental_order_id",
                        column: x => x.rental_order_id,
                        principalTable: "rental_orders",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.Sql("""
                UPDATE rental_orders o
                SET price_type = i.price_type,
                    unit_price = i.price,
                    units = GREATEST(1, CASE i.price_type
                        WHEN 3 THEN CEIL(EXTRACT(EPOCH FROM (o.end_date - o.start_date)) / 86400.0)
                        WHEN 2 THEN CEIL(EXTRACT(EPOCH FROM (o.end_date - o.start_date)) / 3600.0)
                        ELSE 1 END)::int
                FROM rental_items i
                WHERE i.id = o.rental_item_id;

                UPDATE rental_orders SET amount = ROUND(unit_price * quantity * units, 2);
                """);

            migrationBuilder.InsertData(
                table: "ref_rental_advance_types",
                columns: new[] { "code", "detail", "display_order", "is_active", "name" },
                values: new object[,]
                {
                    { (short)0, "Everything is paid before the pieces come back", (short)1, true, "No advance" },
                    { (short)1, "One amount, e.g. ₹500 for any number of pieces", (short)2, true, "Fixed for the order" },
                    { (short)2, "An amount for each piece, e.g. ₹2 a chair", (short)3, true, "Per piece" }
                });

            migrationBuilder.InsertData(
                table: "ref_rental_order_event_kinds",
                columns: new[] { "code", "name" },
                values: new object[,]
                {
                    { (short)5, "Advance paid" },
                    { (short)6, "Payment received" },
                    { (short)7, "Refunded" },
                    { (short)8, "Advance not paid in time" }
                });

            migrationBuilder.InsertData(
                table: "ref_rental_order_statuses",
                columns: new[] { "code", "counts_as_booked", "counts_as_out", "display_order", "name", "tone" },
                values: new object[] { (short)5, true, false, (short)5, "Awaiting advance", "waiting" });

            migrationBuilder.UpdateData(
                table: "ref_rental_order_transitions",
                keyColumns: new[] { "from_status", "to_status" },
                keyValues: new object[] { (short)1, (short)2 },
                column: "requires_paid",
                value: false);

            migrationBuilder.UpdateData(
                table: "ref_rental_order_transitions",
                keyColumns: new[] { "from_status", "to_status" },
                keyValues: new object[] { (short)1, (short)4 },
                column: "requires_paid",
                value: false);

            migrationBuilder.UpdateData(
                table: "ref_rental_order_transitions",
                keyColumns: new[] { "from_status", "to_status" },
                keyValues: new object[] { (short)2, (short)3 },
                column: "requires_paid",
                value: true);

            migrationBuilder.InsertData(
                table: "ref_rental_order_transitions",
                columns: new[] { "from_status", "to_status", "action_label", "business_may", "confirm_first", "customer_may", "display_order", "requires_paid" },
                values: new object[] { (short)5, (short)4, "Cancel order", true, true, true, (short)1, false });

            migrationBuilder.InsertData(
                table: "ref_rental_payment_methods",
                columns: new[] { "code", "business_may_record", "display_order", "name" },
                values: new object[,]
                {
                    { (short)1, false, (short)3, "Online" },
                    { (short)2, true, (short)1, "UPI QR" },
                    { (short)3, true, (short)2, "Cash" }
                });

            migrationBuilder.InsertData(
                table: "ref_rental_payment_statuses",
                columns: new[] { "code", "name", "tone" },
                values: new object[,]
                {
                    { (short)1, "Unpaid", "waiting" },
                    { (short)2, "Advance due", "danger" },
                    { (short)3, "Advance paid", "progress" },
                    { (short)4, "Part paid", "progress" },
                    { (short)5, "Paid", "success" },
                    { (short)6, "Refund due", "danger" },
                    { (short)7, "Refunded", "success" }
                });

            migrationBuilder.CreateIndex(
                name: "ix_rental_orders_status_hold_until",
                table: "rental_orders",
                columns: new[] { "status", "hold_until" });

            migrationBuilder.AddCheckConstraint(
                name: "ck_rental_orders_amounts",
                table: "rental_orders",
                sql: "amount >= 0 AND advance_due >= 0 AND advance_due <= amount");

            migrationBuilder.AddCheckConstraint(
                name: "ck_rental_orders_units",
                table: "rental_orders",
                sql: "units >= 1");

            migrationBuilder.AddCheckConstraint(
                name: "ck_rental_items_advance",
                table: "rental_items",
                sql: "(advance_type = 0 AND advance_amount IS NULL) OR (advance_type IN (1, 2) AND advance_amount > 0)");

            migrationBuilder.CreateIndex(
                name: "ix_rental_order_payments_provider_payment_id",
                table: "rental_order_payments",
                column: "provider_payment_id",
                unique: true,
                filter: "provider_payment_id IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "ix_rental_order_payments_rental_order_id_created_date",
                table: "rental_order_payments",
                columns: new[] { "rental_order_id", "created_date" });

            migrationBuilder.CreateIndex(
                name: "ix_rental_payment_checkouts_provider_order_id",
                table: "rental_payment_checkouts",
                column: "provider_order_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_rental_payment_checkouts_rental_order_id",
                table: "rental_payment_checkouts",
                column: "rental_order_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ref_rental_advance_types");

            migrationBuilder.DropTable(
                name: "ref_rental_payment_methods");

            migrationBuilder.DropTable(
                name: "ref_rental_payment_statuses");

            migrationBuilder.DropTable(
                name: "rental_order_payments");

            migrationBuilder.DropTable(
                name: "rental_payment_checkouts");

            migrationBuilder.DropIndex(
                name: "ix_rental_orders_status_hold_until",
                table: "rental_orders");

            migrationBuilder.DropCheckConstraint(
                name: "ck_rental_orders_amounts",
                table: "rental_orders");

            migrationBuilder.DropCheckConstraint(
                name: "ck_rental_orders_units",
                table: "rental_orders");

            migrationBuilder.DropCheckConstraint(
                name: "ck_rental_items_advance",
                table: "rental_items");

            migrationBuilder.DeleteData(
                table: "ref_rental_order_event_kinds",
                keyColumn: "code",
                keyValue: (short)5);

            migrationBuilder.DeleteData(
                table: "ref_rental_order_event_kinds",
                keyColumn: "code",
                keyValue: (short)6);

            migrationBuilder.DeleteData(
                table: "ref_rental_order_event_kinds",
                keyColumn: "code",
                keyValue: (short)7);

            migrationBuilder.DeleteData(
                table: "ref_rental_order_event_kinds",
                keyColumn: "code",
                keyValue: (short)8);

            migrationBuilder.DeleteData(
                table: "ref_rental_order_statuses",
                keyColumn: "code",
                keyValue: (short)5);

            migrationBuilder.DeleteData(
                table: "ref_rental_order_transitions",
                keyColumns: new[] { "from_status", "to_status" },
                keyValues: new object[] { (short)5, (short)4 });

            migrationBuilder.DropColumn(
                name: "advance_due",
                table: "rental_orders");

            migrationBuilder.DropColumn(
                name: "amount",
                table: "rental_orders");

            migrationBuilder.DropColumn(
                name: "hold_until",
                table: "rental_orders");

            migrationBuilder.DropColumn(
                name: "price_type",
                table: "rental_orders");

            migrationBuilder.DropColumn(
                name: "unit_price",
                table: "rental_orders");

            migrationBuilder.DropColumn(
                name: "units",
                table: "rental_orders");

            migrationBuilder.DropColumn(
                name: "amount",
                table: "rental_order_events");

            migrationBuilder.DropColumn(
                name: "payment_method",
                table: "rental_order_events");

            migrationBuilder.DropColumn(
                name: "advance_amount",
                table: "rental_items");

            migrationBuilder.DropColumn(
                name: "advance_type",
                table: "rental_items");

            migrationBuilder.DropColumn(
                name: "upi_id",
                table: "rental_businesses");

            migrationBuilder.DropColumn(
                name: "requires_paid",
                table: "ref_rental_order_transitions");
        }
    }
}
