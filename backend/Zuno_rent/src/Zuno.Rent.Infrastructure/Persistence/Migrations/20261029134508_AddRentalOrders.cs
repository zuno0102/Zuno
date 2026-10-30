using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Rent.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddRentalOrders : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ref_rental_order_statuses",
                columns: table => new
                {
                    code = table.Column<short>(type: "smallint", nullable: false),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    tone = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    counts_as_out = table.Column<bool>(type: "boolean", nullable: false),
                    display_order = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ref_rental_order_statuses", x => x.code);
                });

            migrationBuilder.CreateTable(
                name: "rental_orders",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    rental_item_id = table.Column<Guid>(type: "uuid", nullable: false),
                    owner_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    customer_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    customer_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    customer_phone = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    quantity = table.Column<int>(type: "integer", nullable: false),
                    start_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    end_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    delivery_address = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    district_id = table.Column<Guid>(type: "uuid", nullable: true),
                    status = table.Column<short>(type: "smallint", nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_rental_orders", x => x.id);
                    table.CheckConstraint("ck_rental_orders_dates", "end_date >= start_date");
                    table.CheckConstraint("ck_rental_orders_quantity", "quantity >= 1");
                    table.ForeignKey(
                        name: "fk_rental_orders_districts_district_id",
                        column: x => x.district_id,
                        principalTable: "ref_districts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_rental_orders_rental_items_rental_item_id",
                        column: x => x.rental_item_id,
                        principalTable: "rental_items",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.InsertData(
                table: "ref_rental_order_statuses",
                columns: new[] { "code", "counts_as_out", "display_order", "name", "tone" },
                values: new object[,]
                {
                    { (short)1, false, (short)1, "Booked", "progress" },
                    { (short)2, true, (short)2, "On rent", "danger" },
                    { (short)3, false, (short)3, "Returned", "success" },
                    { (short)4, false, (short)4, "Cancelled", "waiting" }
                });

            migrationBuilder.CreateIndex(
                name: "ix_rental_orders_customer_user_id",
                table: "rental_orders",
                column: "customer_user_id");

            migrationBuilder.CreateIndex(
                name: "ix_rental_orders_district_id",
                table: "rental_orders",
                column: "district_id");

            migrationBuilder.CreateIndex(
                name: "ix_rental_orders_owner_user_id_start_date",
                table: "rental_orders",
                columns: new[] { "owner_user_id", "start_date" });

            migrationBuilder.CreateIndex(
                name: "ix_rental_orders_rental_item_id_start_date",
                table: "rental_orders",
                columns: new[] { "rental_item_id", "start_date" });

            migrationBuilder.CreateIndex(
                name: "ix_rental_orders_rental_item_id_status",
                table: "rental_orders",
                columns: new[] { "rental_item_id", "status" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ref_rental_order_statuses");

            migrationBuilder.DropTable(
                name: "rental_orders");
        }
    }
}
