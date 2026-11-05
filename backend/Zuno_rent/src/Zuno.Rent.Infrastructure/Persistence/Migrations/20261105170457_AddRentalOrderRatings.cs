using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Rent.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddRentalOrderRatings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "rental_order_ratings",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    rental_order_id = table.Column<Guid>(type: "uuid", nullable: false),
                    rental_item_id = table.Column<Guid>(type: "uuid", nullable: false),
                    owner_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    customer_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    score = table.Column<short>(type: "smallint", nullable: false),
                    comment = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_rental_order_ratings", x => x.id);
                    table.CheckConstraint("ck_rental_order_ratings_score", "score BETWEEN 1 AND 5");
                    table.ForeignKey(
                        name: "fk_rental_order_ratings_rental_items_rental_item_id",
                        column: x => x.rental_item_id,
                        principalTable: "rental_items",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_rental_order_ratings_rental_orders_rental_order_id",
                        column: x => x.rental_order_id,
                        principalTable: "rental_orders",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "ix_rental_order_ratings_owner_user_id",
                table: "rental_order_ratings",
                column: "owner_user_id");

            migrationBuilder.CreateIndex(
                name: "ix_rental_order_ratings_rental_item_id",
                table: "rental_order_ratings",
                column: "rental_item_id");

            migrationBuilder.CreateIndex(
                name: "ix_rental_order_ratings_rental_order_id",
                table: "rental_order_ratings",
                column: "rental_order_id",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "rental_order_ratings");
        }
    }
}
