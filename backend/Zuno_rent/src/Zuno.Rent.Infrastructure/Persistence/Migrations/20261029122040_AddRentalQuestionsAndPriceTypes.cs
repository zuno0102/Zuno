using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Rent.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddRentalQuestionsAndPriceTypes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ref_rental_price_types",
                columns: table => new
                {
                    code = table.Column<short>(type: "smallint", nullable: false),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    detail = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: false),
                    unit_suffix = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    display_order = table.Column<short>(type: "smallint", nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ref_rental_price_types", x => x.code);
                });

            migrationBuilder.CreateTable(
                name: "rental_item_questions",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    rental_item_id = table.Column<Guid>(type: "uuid", nullable: false),
                    prompt = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    is_required = table.Column<bool>(type: "boolean", nullable: false),
                    sort_order = table.Column<short>(type: "smallint", nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_rental_item_questions", x => x.id);
                    table.ForeignKey(
                        name: "fk_rental_item_questions_rental_items_rental_item_id",
                        column: x => x.rental_item_id,
                        principalTable: "rental_items",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.InsertData(
                table: "ref_rental_price_types",
                columns: new[] { "code", "detail", "display_order", "is_active", "name", "unit_suffix" },
                values: new object[,]
                {
                    { (short)1, "One price for each item", (short)2, true, "Per item", "/item" },
                    { (short)2, "Charged by the hour", (short)3, true, "Per hour", "/hr" },
                    { (short)3, "Charged for each day", (short)1, true, "Per day", "/day" }
                });

            migrationBuilder.CreateIndex(
                name: "ix_rental_item_questions_rental_item_id_sort_order",
                table: "rental_item_questions",
                columns: new[] { "rental_item_id", "sort_order" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ref_rental_price_types");

            migrationBuilder.DropTable(
                name: "rental_item_questions");
        }
    }
}
