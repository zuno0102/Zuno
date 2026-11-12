using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Marketplace.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class ProductVariantsDetailsAndDelivery : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "address_line",
                table: "marketplace_posts",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "custom_details",
                table: "marketplace_posts",
                type: "jsonb",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "delivers_everywhere",
                table: "marketplace_posts",
                type: "boolean",
                nullable: false,
                defaultValue: true); // every post made so far ships anywhere

            migrationBuilder.AddColumn<List<Guid>>(
                name: "delivery_district_ids",
                table: "marketplace_posts",
                type: "uuid[]",
                nullable: false,
                defaultValueSql: "'{}'"); // existing posts ship anywhere, so to no listed districts

            migrationBuilder.CreateTable(
                name: "marketplace_post_variants",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    post_id = table.Column<Guid>(type: "uuid", nullable: false),
                    colour = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: true),
                    size = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    price = table.Column<decimal>(type: "numeric(14,2)", precision: 14, scale: 2, nullable: true),
                    stock = table.Column<int>(type: "integer", nullable: false),
                    sort_order = table.Column<short>(type: "smallint", nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_marketplace_post_variants", x => x.id);
                    table.CheckConstraint("ck_marketplace_post_variants_named", "colour IS NOT NULL OR size IS NOT NULL");
                    table.CheckConstraint("ck_marketplace_post_variants_price", "price IS NULL OR price > 0");
                    table.CheckConstraint("ck_marketplace_post_variants_stock", "stock >= 0");
                    table.ForeignKey(
                        name: "fk_marketplace_post_variants_marketplace_posts_post_id",
                        column: x => x.post_id,
                        principalTable: "marketplace_posts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.InsertData(
                table: "marketplace_category_fields",
                columns: new[] { "id", "category_id", "created_by", "created_date", "display_order", "field_type", "is_active", "is_deleted", "is_required", "key", "label", "modified_by", "modified_date", "options", "sub_category_id", "unit" },
                values: new object[,]
                {
                    { new Guid("f6666666-0000-0000-0003-000000000003"), new Guid("d4444444-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)3, (short)3, true, false, false, "fabric", "Fabric", null, null, new List<string> { "Silk", "Cotton", "Georgette", "Chiffon", "Crepe", "Other" }, new Guid("c7777777-0000-0000-0003-000000000001"), null },
                    { new Guid("f6666666-0000-0000-0003-000000000004"), new Guid("d4444444-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)4, (short)3, true, false, false, "fabric", "Fabric", null, null, new List<string> { "Cotton", "Polyester", "Linen", "Denim", "Wool", "Other" }, new Guid("c7777777-0000-0000-0003-000000000002"), null },
                    { new Guid("f6666666-0000-0000-0003-000000000005"), new Guid("d4444444-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)5, (short)3, true, false, false, "for", "For", null, null, new List<string> { "Men", "Women", "Kids", "Unisex" }, new Guid("c7777777-0000-0000-0003-000000000002"), null },
                    { new Guid("f6666666-0000-0000-0003-000000000006"), new Guid("d4444444-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)6, (short)3, true, false, false, "material", "Material", null, null, new List<string> { "Genuine leather", "Synthetic leather", "Canvas", "Rubber", "Other" }, new Guid("c7777777-0000-0000-0003-000000000003"), null },
                    { new Guid("f6666666-0000-0000-0003-000000000007"), new Guid("d4444444-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)7, (short)3, true, false, false, "for", "For", null, null, new List<string> { "Men", "Women", "Kids", "Unisex" }, new Guid("c7777777-0000-0000-0003-000000000003"), null },
                    { new Guid("f6666666-0000-0000-0003-000000000008"), new Guid("d4444444-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)8, (short)1, true, false, false, "brand", "Brand", null, null, new List<string>(), new Guid("c7777777-0000-0000-0003-000000000005"), null },
                    { new Guid("f6666666-0000-0000-0003-000000000009"), new Guid("d4444444-0000-0000-0000-000000000003"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)9, (short)3, true, false, false, "material", "Material", null, null, new List<string> { "Wood", "Metal", "Plastic", "Glass", "Other" }, new Guid("c7777777-0000-0000-0003-000000000007"), null }
                });

            migrationBuilder.CreateIndex(
                name: "ix_marketplace_post_variants_post_id_colour_size",
                table: "marketplace_post_variants",
                columns: new[] { "post_id", "colour", "size" },
                unique: true,
                filter: "is_deleted = false")
                .Annotation("Npgsql:NullsDistinct", false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "marketplace_post_variants");

            migrationBuilder.DeleteData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000003"));

            migrationBuilder.DeleteData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000004"));

            migrationBuilder.DeleteData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000005"));

            migrationBuilder.DeleteData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000006"));

            migrationBuilder.DeleteData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000007"));

            migrationBuilder.DeleteData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000008"));

            migrationBuilder.DeleteData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000009"));

            migrationBuilder.DropColumn(
                name: "address_line",
                table: "marketplace_posts");

            migrationBuilder.DropColumn(
                name: "custom_details",
                table: "marketplace_posts");

            migrationBuilder.DropColumn(
                name: "delivers_everywhere",
                table: "marketplace_posts");

            migrationBuilder.DropColumn(
                name: "delivery_district_ids",
                table: "marketplace_posts");

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0001-000000000004"),
                column: "options",
                value: new List<string> { "Petrol", "Diesel", "CNG", "Electric" });

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
                keyValue: new Guid("f6666666-0000-0000-0003-000000000001"),
                column: "options",
                value: new List<string> { "New", "Used" });

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
        }
    }
}
