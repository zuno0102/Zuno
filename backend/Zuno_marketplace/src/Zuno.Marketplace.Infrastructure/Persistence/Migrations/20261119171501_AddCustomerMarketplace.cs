using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Marketplace.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddCustomerMarketplace : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "customer_name",
                table: "ref_marketplace_order_statuses",
                type: "character varying(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "customer_tone",
                table: "ref_marketplace_order_statuses",
                type: "character varying(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.AddColumn<short>(
                name: "track_step",
                table: "ref_marketplace_order_statuses",
                type: "smallint",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "marketplace_favourites",
                columns: table => new
                {
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    post_id = table.Column<Guid>(type: "uuid", nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_marketplace_favourites", x => new { x.user_id, x.post_id });
                    table.ForeignKey(
                        name: "fk_marketplace_favourites_posts_post_id",
                        column: x => x.post_id,
                        principalTable: "marketplace_posts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ref_marketplace_order_track_steps",
                columns: table => new
                {
                    code = table.Column<short>(type: "smallint", nullable: false),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    display_order = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ref_marketplace_order_track_steps", x => x.code);
                });

            migrationBuilder.UpdateData(
                table: "ref_marketplace_order_statuses",
                keyColumn: "code",
                keyValue: (short)1,
                columns: new[] { "customer_name", "customer_tone", "track_step" },
                values: new object[] { null, null, (short)1 });

            migrationBuilder.UpdateData(
                table: "ref_marketplace_order_statuses",
                keyColumn: "code",
                keyValue: (short)2,
                columns: new[] { "customer_name", "customer_tone", "track_step" },
                values: new object[] { "Ordered", "progress", (short)1 });

            migrationBuilder.UpdateData(
                table: "ref_marketplace_order_statuses",
                keyColumn: "code",
                keyValue: (short)3,
                columns: new[] { "customer_name", "customer_tone", "track_step" },
                values: new object[] { null, null, (short)2 });

            migrationBuilder.UpdateData(
                table: "ref_marketplace_order_statuses",
                keyColumn: "code",
                keyValue: (short)4,
                columns: new[] { "customer_name", "customer_tone", "track_step" },
                values: new object[] { null, null, (short)3 });

            migrationBuilder.UpdateData(
                table: "ref_marketplace_order_statuses",
                keyColumn: "code",
                keyValue: (short)5,
                columns: new[] { "customer_name", "customer_tone", "track_step" },
                values: new object[] { null, null, (short)4 });

            migrationBuilder.UpdateData(
                table: "ref_marketplace_order_statuses",
                keyColumn: "code",
                keyValue: (short)6,
                columns: new[] { "customer_name", "customer_tone", "track_step" },
                values: new object[] { null, null, (short)5 });

            migrationBuilder.UpdateData(
                table: "ref_marketplace_order_statuses",
                keyColumn: "code",
                keyValue: (short)7,
                columns: new[] { "customer_name", "customer_tone", "track_step" },
                values: new object[] { "Completed", null, (short)5 });

            migrationBuilder.UpdateData(
                table: "ref_marketplace_order_statuses",
                keyColumn: "code",
                keyValue: (short)8,
                columns: new[] { "customer_name", "customer_tone", "track_step" },
                values: new object[] { null, null, null });

            migrationBuilder.InsertData(
                table: "ref_marketplace_order_track_steps",
                columns: new[] { "code", "display_order", "name" },
                values: new object[,]
                {
                    { (short)1, (short)1, "Ordered" },
                    { (short)2, (short)2, "Confirmed" },
                    { (short)3, (short)3, "Shipped" },
                    { (short)4, (short)4, "Out for delivery" },
                    { (short)5, (short)5, "Delivered" }
                });

            migrationBuilder.UpdateData(
                table: "ref_marketplace_payment_methods",
                keyColumn: "code",
                keyValue: (short)1,
                column: "detail",
                value: "Paid in cash to the courier or the seller when it arrives.");

            migrationBuilder.CreateIndex(
                name: "ix_ref_marketplace_order_statuses_track_step",
                table: "ref_marketplace_order_statuses",
                column: "track_step");

            migrationBuilder.CreateIndex(
                name: "ix_marketplace_favourites_post_id",
                table: "marketplace_favourites",
                column: "post_id");

            migrationBuilder.CreateIndex(
                name: "ix_marketplace_favourites_user_id_created_date",
                table: "marketplace_favourites",
                columns: new[] { "user_id", "created_date" });

            migrationBuilder.AddForeignKey(
                name: "fk_ref_marketplace_order_statuses_ref_marketplace_order_track_",
                table: "ref_marketplace_order_statuses",
                column: "track_step",
                principalTable: "ref_marketplace_order_track_steps",
                principalColumn: "code",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_ref_marketplace_order_statuses_ref_marketplace_order_track_",
                table: "ref_marketplace_order_statuses");

            migrationBuilder.DropTable(
                name: "marketplace_favourites");

            migrationBuilder.DropTable(
                name: "ref_marketplace_order_track_steps");

            migrationBuilder.DropIndex(
                name: "ix_ref_marketplace_order_statuses_track_step",
                table: "ref_marketplace_order_statuses");

            migrationBuilder.DropColumn(
                name: "customer_name",
                table: "ref_marketplace_order_statuses");

            migrationBuilder.DropColumn(
                name: "customer_tone",
                table: "ref_marketplace_order_statuses");

            migrationBuilder.DropColumn(
                name: "track_step",
                table: "ref_marketplace_order_statuses");

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0001-000000000001"),
                column: "options",
                value: new List<string>());

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0001-000000000002"),
                column: "options",
                value: new List<string>());

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0001-000000000003"),
                column: "options",
                value: new List<string>());

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0001-000000000004"),
                column: "options",
                value: new List<string> { "Petrol", "Diesel", "CNG", "Electric" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0001-000000000005"),
                column: "options",
                value: new List<string>());

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0002-000000000001"),
                column: "options",
                value: new List<string> { "Land", "House", "Flat", "Shop / commercial" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0002-000000000002"),
                column: "options",
                value: new List<string> { "Sale", "Rent", "Lease" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0002-000000000003"),
                column: "options",
                value: new List<string>());

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0002-000000000004"),
                column: "options",
                value: new List<string>());

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000001"),
                column: "options",
                value: new List<string> { "New", "Used" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000002"),
                column: "options",
                value: new List<string>());

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000003"),
                column: "options",
                value: new List<string> { "Silk", "Cotton", "Georgette", "Chiffon", "Crepe", "Other" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000004"),
                column: "options",
                value: new List<string> { "Cotton", "Polyester", "Linen", "Denim", "Wool", "Other" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000005"),
                column: "options",
                value: new List<string> { "Men", "Women", "Kids", "Unisex" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000006"),
                column: "options",
                value: new List<string> { "Genuine leather", "Synthetic leather", "Canvas", "Rubber", "Other" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000007"),
                column: "options",
                value: new List<string> { "Men", "Women", "Kids", "Unisex" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000008"),
                column: "options",
                value: new List<string>());

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000009"),
                column: "options",
                value: new List<string> { "Wood", "Metal", "Plastic", "Glass", "Other" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0004-000000000001"),
                column: "options",
                value: new List<string> { "Vegetables", "Fruits", "Grains", "Coconut", "Spices", "Dairy", "Other" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0004-000000000002"),
                column: "options",
                value: new List<string> { "Yes", "No" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0005-000000000001"),
                column: "options",
                value: new List<string> { "Veg", "Non-veg" });

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0006-000000000001"),
                column: "options",
                value: new List<string> { "Sale / offer", "Sports tournament", "Event", "Shop opening" });

            migrationBuilder.UpdateData(
                table: "ref_marketplace_payment_methods",
                keyColumn: "code",
                keyValue: (short)1,
                column: "detail",
                value: "The customer pays the courier or you when it arrives.");
        }
    }
}
