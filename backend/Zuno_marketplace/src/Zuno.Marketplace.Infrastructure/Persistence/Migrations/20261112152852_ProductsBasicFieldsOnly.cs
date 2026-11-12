using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Marketplace.Infrastructure.Persistence.Migrations
{
    /// <summary>
    /// A product asks only its basic fields; colours and sizes are typed per variant. The colour and
    /// size suggestions go, and the per-kind details (Fabric, For, Material, Brand) are switched off —
    /// a value a post already had moves into its own details, so nothing it said is lost.
    /// </summary>
    public partial class ProductsBasicFieldsOnly : Migration
    {
        /// <summary>The switched-off details: their keys and the name each keeps as an own detail.</summary>
        private const string MovedKeys = "('fabric', 'Fabric'), ('for', 'For'), ('material', 'Material'), ('brand', 'Brand')";

        /// <summary>Sarees, Clothing, Footwear, Mobiles & electronics, Furniture — never Vehicles' brand.</summary>
        private const string MovedSubCategories =
            "'c7777777-0000-0000-0003-000000000001', 'c7777777-0000-0000-0003-000000000002', " +
            "'c7777777-0000-0000-0003-000000000003', 'c7777777-0000-0000-0003-000000000005', " +
            "'c7777777-0000-0000-0003-000000000007'";

        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Each detail with one of those keys becomes an own detail of the same name — unless the
            // post already has an own detail by that name — and leaves the category details.
            migrationBuilder.Sql(
                $"""
                WITH names(key, label) AS (VALUES {MovedKeys}),
                moved AS (
                    SELECT p.id,
                           COALESCE(jsonb_agg(jsonb_build_object('Key', n.label, 'Value', a->>'Value'))
                               FILTER (WHERE n.key IS NOT NULL AND NOT COALESCE(p.custom_details, '[]'::jsonb)
                                   @> jsonb_build_array(jsonb_build_object('Key', n.label))), '[]'::jsonb) AS added,
                           COALESCE(jsonb_agg(a) FILTER (WHERE n.key IS NULL), '[]'::jsonb) AS kept
                    FROM marketplace_posts p
                    CROSS JOIN LATERAL jsonb_array_elements(COALESCE(p.attributes, '[]'::jsonb)) a
                    LEFT JOIN names n ON n.key = a->>'Key'
                    WHERE p.sub_category_id IN ({MovedSubCategories})
                    GROUP BY p.id
                    HAVING bool_or(n.key IS NOT NULL)
                )
                UPDATE marketplace_posts p
                SET attributes = m.kept,
                    custom_details = COALESCE(p.custom_details, '[]'::jsonb) || m.added
                FROM moved m
                WHERE p.id = m.id;
                """);

            migrationBuilder.DropColumn(
                name: "colour_options",
                table: "marketplace_sub_categories");

            migrationBuilder.DropColumn(
                name: "size_options",
                table: "marketplace_sub_categories");

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000003"),
                column: "is_active",
                value: false);

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000004"),
                column: "is_active",
                value: false);

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000005"),
                column: "is_active",
                value: false);

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000006"),
                column: "is_active",
                value: false);

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000007"),
                column: "is_active",
                value: false);

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000008"),
                column: "is_active",
                value: false);

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0003-000000000009"),
                column: "is_active",
                value: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<List<string>>(
                name: "colour_options",
                table: "marketplace_sub_categories",
                type: "text[]",
                nullable: false,
                defaultValueSql: "'{}'");

            migrationBuilder.AddColumn<List<string>>(
                name: "size_options",
                table: "marketplace_sub_categories",
                type: "text[]",
                nullable: false,
                defaultValueSql: "'{}'");

            // The details are asked again; values already moved stay as the posts' own details.
            migrationBuilder.Sql(
                "UPDATE marketplace_category_fields SET is_active = TRUE WHERE id IN (" +
                string.Join(", ", Enumerable.Range(3, 7).Select(i => $"'f6666666-0000-0000-0003-{i:D12}'")) + ");");

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000001"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string> { "Red", "Blue", "Green", "Black", "White", "Yellow", "Pink", "Maroon", "Orange", "Purple", "Grey", "Brown", "Gold", "Silver", "Multicolour" }, new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000002"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string> { "Red", "Blue", "Green", "Black", "White", "Yellow", "Pink", "Maroon", "Orange", "Purple", "Grey", "Brown", "Gold", "Silver", "Multicolour" }, new List<string> { "XS", "S", "M", "L", "XL", "XXL", "3XL", "Free size" } });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000003"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string> { "Black", "Brown", "Tan", "White", "Blue", "Red", "Grey", "Multicolour" }, new List<string> { "UK 3", "UK 4", "UK 5", "UK 6", "UK 7", "UK 8", "UK 9", "UK 10", "UK 11" } });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000004"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string> { "Red", "Blue", "Green", "Black", "White", "Yellow", "Pink", "Maroon", "Orange", "Purple", "Grey", "Brown", "Gold", "Silver", "Multicolour" }, new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000005"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string> { "Black", "White", "Blue", "Silver", "Gold", "Green" }, new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000006"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string> { "Red", "Blue", "Green", "Black", "White", "Yellow", "Pink", "Maroon", "Orange", "Purple", "Grey", "Brown", "Gold", "Silver", "Multicolour" }, new List<string> { "Small", "Medium", "Large" } });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000007"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string> { "Brown", "Black", "White", "Grey", "Natural wood" }, new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000008"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000009"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000010"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000011"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0003-000000000012"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string> { "Red", "Blue", "Green", "Black", "White", "Yellow", "Pink", "Maroon", "Orange", "Purple", "Grey", "Brown", "Gold", "Silver", "Multicolour" }, new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000001"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000002"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000003"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000004"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000005"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000006"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000007"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000008"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000009"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0005-000000000001"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0005-000000000002"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0005-000000000003"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0005-000000000004"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0005-000000000005"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0005-000000000006"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0006-000000000001"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0006-000000000002"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0006-000000000003"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0006-000000000004"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0006-000000000005"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0006-000000000006"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0006-000000000007"),
                columns: new[] { "colour_options", "size_options" },
                values: new object[] { new List<string>(), new List<string>() });
        }
    }
}
