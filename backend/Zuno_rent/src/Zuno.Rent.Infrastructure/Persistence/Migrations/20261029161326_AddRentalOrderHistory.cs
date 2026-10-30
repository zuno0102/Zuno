using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Rent.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddRentalOrderHistory : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ref_rental_order_event_kinds",
                columns: table => new
                {
                    code = table.Column<short>(type: "smallint", nullable: false),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ref_rental_order_event_kinds", x => x.code);
                });

            migrationBuilder.CreateTable(
                name: "rental_order_events",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    rental_order_id = table.Column<Guid>(type: "uuid", nullable: false),
                    kind = table.Column<short>(type: "smallint", nullable: false),
                    to_status = table.Column<short>(type: "smallint", nullable: true),
                    quantity = table.Column<int>(type: "integer", nullable: false),
                    related_order_id = table.Column<Guid>(type: "uuid", nullable: true),
                    actor_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_rental_order_events", x => x.id);
                    table.CheckConstraint("ck_rental_order_events_quantity", "quantity >= 0");
                    table.ForeignKey(
                        name: "fk_rental_order_events_rental_orders_rental_order_id",
                        column: x => x.rental_order_id,
                        principalTable: "rental_orders",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.InsertData(
                table: "ref_rental_order_event_kinds",
                columns: new[] { "code", "name" },
                values: new object[,]
                {
                    { (short)1, "Booked" },
                    { (short)2, "Status changed" },
                    { (short)3, "Extra pieces added" }
                });

            migrationBuilder.CreateIndex(
                name: "ix_rental_order_events_rental_order_id_created_date",
                table: "rental_order_events",
                columns: new[] { "rental_order_id", "created_date" });

            // Orders made before history existed get their "Booked" step, at the time they were made.
            // Later steps are not invented: when they happened was never recorded.
            migrationBuilder.Sql(
                """
                INSERT INTO rental_order_events (id, rental_order_id, kind, to_status, quantity, related_order_id, actor_user_id, created_date, is_deleted)
                SELECT gen_random_uuid(), o.id, 1, NULL, o.quantity, NULL, o.owner_user_id, o.created_date, false
                FROM rental_orders o;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ref_rental_order_event_kinds");

            migrationBuilder.DropTable(
                name: "rental_order_events");
        }
    }
}
