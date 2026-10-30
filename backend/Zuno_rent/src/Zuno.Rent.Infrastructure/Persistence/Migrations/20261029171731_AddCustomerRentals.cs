using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Rent.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddCustomerRentals : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<short>(
                name: "source",
                table: "rental_orders",
                type: "smallint",
                nullable: false,

                // Every order before this was taken by the business: Offline.
                defaultValue: (short)1);

            migrationBuilder.AddColumn<bool>(
                name: "business_may",
                table: "ref_rental_order_transitions",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "customer_may",
                table: "ref_rental_order_transitions",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "ref_rental_home_sections",
                columns: table => new
                {
                    code = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    title = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    layout = table.Column<short>(type: "smallint", nullable: false),
                    size = table.Column<short>(type: "smallint", nullable: false),
                    by_popularity = table.Column<bool>(type: "boolean", nullable: false),
                    display_order = table.Column<short>(type: "smallint", nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ref_rental_home_sections", x => x.code);
                    table.CheckConstraint("ck_ref_rental_home_sections_size", "size BETWEEN 1 AND 50");
                });

            migrationBuilder.CreateTable(
                name: "rental_businesses",
                columns: table => new
                {
                    owner_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    logo_url = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    is_verified = table.Column<bool>(type: "boolean", nullable: false),
                    refreshed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_rental_businesses", x => x.owner_user_id);
                });

            migrationBuilder.CreateTable(
                name: "rental_order_answers",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    rental_order_id = table.Column<Guid>(type: "uuid", nullable: false),
                    question_id = table.Column<Guid>(type: "uuid", nullable: true),
                    prompt = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    answer = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_rental_order_answers", x => x.id);
                    table.ForeignKey(
                        name: "fk_rental_order_answers_rental_orders_rental_order_id",
                        column: x => x.rental_order_id,
                        principalTable: "rental_orders",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.InsertData(
                table: "ref_rental_home_sections",
                columns: new[] { "code", "by_popularity", "display_order", "is_active", "layout", "size", "title" },
                values: new object[,]
                {
                    { "all", false, (short)4, true, (short)2, (short)20, "All rentals" },
                    { "explore", false, (short)2, true, (short)2, (short)6, "Explore" },
                    { "more", false, (short)3, true, (short)1, (short)10, "More to rent" },
                    { "popular", true, (short)1, true, (short)1, (short)10, "Popular near you" }
                });

            migrationBuilder.InsertData(
                table: "ref_rental_order_event_kinds",
                columns: new[] { "code", "name" },
                values: new object[] { (short)4, "Booked by customer" });

            migrationBuilder.UpdateData(
                table: "ref_rental_order_transitions",
                keyColumns: new[] { "from_status", "to_status" },
                keyValues: new object[] { (short)1, (short)2 },
                columns: new[] { "business_may", "customer_may" },
                values: new object[] { true, false });

            migrationBuilder.UpdateData(
                table: "ref_rental_order_transitions",
                keyColumns: new[] { "from_status", "to_status" },
                keyValues: new object[] { (short)1, (short)4 },
                columns: new[] { "business_may", "customer_may" },
                values: new object[] { true, true });

            migrationBuilder.UpdateData(
                table: "ref_rental_order_transitions",
                keyColumns: new[] { "from_status", "to_status" },
                keyValues: new object[] { (short)2, (short)3 },
                columns: new[] { "business_may", "customer_may" },
                values: new object[] { true, false });

            migrationBuilder.CreateIndex(
                name: "ix_rental_order_answers_rental_order_id",
                table: "rental_order_answers",
                column: "rental_order_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ref_rental_home_sections");

            migrationBuilder.DropTable(
                name: "rental_businesses");

            migrationBuilder.DropTable(
                name: "rental_order_answers");

            migrationBuilder.DeleteData(
                table: "ref_rental_order_event_kinds",
                keyColumn: "code",
                keyValue: (short)4);

            migrationBuilder.DropColumn(
                name: "source",
                table: "rental_orders");

            migrationBuilder.DropColumn(
                name: "business_may",
                table: "ref_rental_order_transitions");

            migrationBuilder.DropColumn(
                name: "customer_may",
                table: "ref_rental_order_transitions");
        }
    }
}
