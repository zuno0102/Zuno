using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Rent.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddRentalOrderStepsAndMessages : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "counts_as_booked",
                table: "ref_rental_order_statuses",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "ref_rental_order_transitions",
                columns: table => new
                {
                    from_status = table.Column<short>(type: "smallint", nullable: false),
                    to_status = table.Column<short>(type: "smallint", nullable: false),
                    action_label = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    confirm_first = table.Column<bool>(type: "boolean", nullable: false),
                    display_order = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ref_rental_order_transitions", x => new { x.from_status, x.to_status });
                });

            migrationBuilder.CreateTable(
                name: "rental_order_messages",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    rental_order_id = table.Column<Guid>(type: "uuid", nullable: false),
                    sender_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    sender_role = table.Column<short>(type: "smallint", nullable: false),
                    body = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                    read_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_rental_order_messages", x => x.id);
                    table.ForeignKey(
                        name: "fk_rental_order_messages_rental_orders_rental_order_id",
                        column: x => x.rental_order_id,
                        principalTable: "rental_orders",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.UpdateData(
                table: "ref_rental_order_statuses",
                keyColumn: "code",
                keyValue: (short)1,
                column: "counts_as_booked",
                value: true);

            migrationBuilder.UpdateData(
                table: "ref_rental_order_statuses",
                keyColumn: "code",
                keyValue: (short)2,
                column: "counts_as_booked",
                value: false);

            migrationBuilder.UpdateData(
                table: "ref_rental_order_statuses",
                keyColumn: "code",
                keyValue: (short)3,
                column: "counts_as_booked",
                value: false);

            migrationBuilder.UpdateData(
                table: "ref_rental_order_statuses",
                keyColumn: "code",
                keyValue: (short)4,
                column: "counts_as_booked",
                value: false);

            migrationBuilder.InsertData(
                table: "ref_rental_order_transitions",
                columns: new[] { "from_status", "to_status", "action_label", "confirm_first", "display_order" },
                values: new object[,]
                {
                    { (short)1, (short)2, "Send out", false, (short)1 },
                    { (short)1, (short)4, "Cancel order", true, (short)2 },
                    { (short)2, (short)3, "Mark returned", false, (short)1 }
                });

            migrationBuilder.CreateIndex(
                name: "ix_rental_order_messages_rental_order_id_created_date",
                table: "rental_order_messages",
                columns: new[] { "rental_order_id", "created_date" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ref_rental_order_transitions");

            migrationBuilder.DropTable(
                name: "rental_order_messages");

            migrationBuilder.DropColumn(
                name: "counts_as_booked",
                table: "ref_rental_order_statuses");
        }
    }
}
