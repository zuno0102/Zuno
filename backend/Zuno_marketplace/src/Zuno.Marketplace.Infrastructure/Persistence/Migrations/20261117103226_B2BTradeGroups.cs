using System;
using System.Linq;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Marketplace.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class B2BTradeGroups : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.UpdateData(
                table: "marketplace_categories",
                keyColumn: "id",
                keyValue: new Guid("d4444444-0000-0000-0000-000000000004"),
                column: "description",
                value: "Fruits, vegetables, spices, plumbing, electrical — in bulk for dealers");

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0004-000000000002"),
                column: "is_active",
                value: false);

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000009"),
                column: "display_order",
                value: (short)15);

            migrationBuilder.InsertData(
                table: "marketplace_sub_categories",
                columns: new[] { "id", "category_id", "created_by", "created_date", "display_order", "icon_name", "is_active", "is_deleted", "modified_by", "modified_date", "name", "slug" },
                values: new object[,]
                {
                    { new Guid("c7777777-0000-0000-0004-000000000010"), new Guid("d4444444-0000-0000-0000-000000000004"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)9, null, true, false, null, null, "Plumbing & sanitary", "plumbing-sanitary" },
                    { new Guid("c7777777-0000-0000-0004-000000000011"), new Guid("d4444444-0000-0000-0000-000000000004"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)10, null, true, false, null, null, "Electrical", "electrical" },
                    { new Guid("c7777777-0000-0000-0004-000000000012"), new Guid("d4444444-0000-0000-0000-000000000004"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)11, null, true, false, null, null, "Hardware & tools", "hardware-tools" },
                    { new Guid("c7777777-0000-0000-0004-000000000013"), new Guid("d4444444-0000-0000-0000-000000000004"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)12, null, true, false, null, null, "Building materials", "building-materials" },
                    { new Guid("c7777777-0000-0000-0004-000000000014"), new Guid("d4444444-0000-0000-0000-000000000004"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)13, null, true, false, null, null, "Packaging", "packaging" },
                    { new Guid("c7777777-0000-0000-0004-000000000015"), new Guid("d4444444-0000-0000-0000-000000000004"), null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)14, null, true, false, null, null, "Textiles & garments", "textiles-garments" }
                });

            // "Organic" is no longer asked: a B2B post that answered it keeps the answer as one of its
            // own details ("Organic: Yes"), unless it already has one by that name.
            migrationBuilder.Sql(
                """
                WITH moved AS (
                    SELECT p.id,
                           COALESCE(jsonb_agg(jsonb_build_object('Key', 'Organic', 'Value', a->>'Value'))
                               FILTER (WHERE a->>'Key' = 'organic' AND NOT COALESCE(p.custom_details, '[]'::jsonb)
                                   @> '[{"Key": "Organic"}]'::jsonb), '[]'::jsonb) AS added,
                           COALESCE(jsonb_agg(a) FILTER (WHERE a->>'Key' <> 'organic'), '[]'::jsonb) AS kept
                    FROM marketplace_posts p
                    CROSS JOIN LATERAL jsonb_array_elements(COALESCE(p.attributes, '[]'::jsonb)) a
                    WHERE p.category_id = 'd4444444-0000-0000-0000-000000000004'
                    GROUP BY p.id
                    HAVING bool_or(a->>'Key' = 'organic')
                )
                UPDATE marketplace_posts p
                SET attributes = m.kept,
                    custom_details = COALESCE(p.custom_details, '[]'::jsonb) || m.added
                FROM moved m
                WHERE p.id = m.id;
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // A post filed under a trade group goes back to "Other" before the groups are taken away.
            migrationBuilder.Sql(
                "UPDATE marketplace_posts SET sub_category_id = 'c7777777-0000-0000-0004-000000000009' " +
                "WHERE sub_category_id IN (" +
                string.Join(", ", Enumerable.Range(10, 6).Select(i => $"'c7777777-0000-0000-0004-{i:D12}'")) + ");");

            migrationBuilder.DeleteData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValues: Enumerable.Range(10, 6)
                    .Select(i => (object)new Guid($"c7777777-0000-0000-0004-{i:D12}"))
                    .ToArray());

            migrationBuilder.UpdateData(
                table: "marketplace_sub_categories",
                keyColumn: "id",
                keyValue: new Guid("c7777777-0000-0000-0004-000000000009"),
                column: "display_order",
                value: (short)9);

            migrationBuilder.UpdateData(
                table: "marketplace_category_fields",
                keyColumn: "id",
                keyValue: new Guid("f6666666-0000-0000-0004-000000000002"),
                column: "is_active",
                value: true);

            migrationBuilder.UpdateData(
                table: "marketplace_categories",
                keyColumn: "id",
                keyValue: new Guid("d4444444-0000-0000-0000-000000000004"),
                column: "description",
                value: "Banana, pineapple, coconut, chicken — in bulk for dealers");
        }
    }
}
