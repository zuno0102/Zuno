using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddServiceSubCategories : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "service_sub_category_id",
                table: "business_service_variants",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "service_sub_categories",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    service_category_id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    slug = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    display_order = table.Column<short>(type: "smallint", nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_service_sub_categories", x => x.id);
                    table.ForeignKey(
                        name: "fk_service_sub_categories_service_categories_service_category_",
                        column: x => x.service_category_id,
                        principalTable: "service_categories",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.InsertData(
                table: "service_sub_categories",
                columns: new[] { "id", "created_by", "created_date", "display_order", "is_active", "is_deleted", "modified_by", "modified_date", "name", "service_category_id", "slug", "status" },
                values: new object[,]
                {
                    { new Guid("a2222222-0000-0000-0001-000000000001"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)1, true, false, null, null, "Tap & mixer repair", new Guid("a1111111-0000-0000-0000-000000000001"), "tap-mixer-repair", (short)1 },
                    { new Guid("a2222222-0000-0000-0001-000000000002"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)2, true, false, null, null, "Pipe leak repair", new Guid("a1111111-0000-0000-0000-000000000001"), "pipe-leak-repair", (short)1 },
                    { new Guid("a2222222-0000-0000-0001-000000000003"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)3, true, false, null, null, "Bathroom fitting", new Guid("a1111111-0000-0000-0000-000000000001"), "bathroom-fitting", (short)1 },
                    { new Guid("a2222222-0000-0000-0001-000000000004"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)4, true, false, null, null, "Drainage unclogging", new Guid("a1111111-0000-0000-0000-000000000001"), "drainage-unclogging", (short)1 },
                    { new Guid("a2222222-0000-0000-0001-000000000005"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)5, true, false, null, null, "Water tank cleaning", new Guid("a1111111-0000-0000-0000-000000000001"), "water-tank-cleaning", (short)1 },
                    { new Guid("a2222222-0000-0000-0001-000000000006"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)6, true, false, null, null, "Motor & pump repair", new Guid("a1111111-0000-0000-0000-000000000001"), "motor-pump-repair", (short)1 },
                    { new Guid("a2222222-0000-0000-0002-000000000001"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)1, true, false, null, null, "Wiring & rewiring", new Guid("a1111111-0000-0000-0000-000000000002"), "wiring-rewiring", (short)1 },
                    { new Guid("a2222222-0000-0000-0002-000000000002"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)2, true, false, null, null, "Switchboard & socket", new Guid("a1111111-0000-0000-0000-000000000002"), "switchboard-socket", (short)1 },
                    { new Guid("a2222222-0000-0000-0002-000000000003"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)3, true, false, null, null, "Fan installation", new Guid("a1111111-0000-0000-0000-000000000002"), "fan-installation", (short)1 },
                    { new Guid("a2222222-0000-0000-0002-000000000004"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)4, true, false, null, null, "Light & chandelier fitting", new Guid("a1111111-0000-0000-0000-000000000002"), "light-chandelier-fitting", (short)1 },
                    { new Guid("a2222222-0000-0000-0002-000000000005"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)5, true, false, null, null, "Inverter & stabiliser", new Guid("a1111111-0000-0000-0000-000000000002"), "inverter-stabiliser", (short)1 },
                    { new Guid("a2222222-0000-0000-0002-000000000006"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)6, true, false, null, null, "MCB & fuse repair", new Guid("a1111111-0000-0000-0000-000000000002"), "mcb-fuse-repair", (short)1 },
                    { new Guid("a2222222-0000-0000-0003-000000000001"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)1, true, false, null, null, "Bedroom cleaning", new Guid("a1111111-0000-0000-0000-000000000003"), "bedroom-cleaning", (short)1 },
                    { new Guid("a2222222-0000-0000-0003-000000000002"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)2, true, false, null, null, "Kitchen cleaning", new Guid("a1111111-0000-0000-0000-000000000003"), "kitchen-cleaning", (short)1 },
                    { new Guid("a2222222-0000-0000-0003-000000000003"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)3, true, false, null, null, "Bathroom cleaning", new Guid("a1111111-0000-0000-0000-000000000003"), "bathroom-cleaning", (short)1 },
                    { new Guid("a2222222-0000-0000-0003-000000000004"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)4, true, false, null, null, "Utensils & dishwashing", new Guid("a1111111-0000-0000-0000-000000000003"), "utensils-dishwashing", (short)1 },
                    { new Guid("a2222222-0000-0000-0003-000000000005"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)5, true, false, null, null, "Sofa & carpet cleaning", new Guid("a1111111-0000-0000-0000-000000000003"), "sofa-carpet-cleaning", (short)1 },
                    { new Guid("a2222222-0000-0000-0003-000000000006"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)6, true, false, null, null, "Full home deep cleaning", new Guid("a1111111-0000-0000-0000-000000000003"), "full-home-deep-cleaning", (short)1 },
                    { new Guid("a2222222-0000-0000-0004-000000000001"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)1, true, false, null, null, "Furniture repair", new Guid("a1111111-0000-0000-0000-000000000004"), "furniture-repair", (short)1 },
                    { new Guid("a2222222-0000-0000-0004-000000000002"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)2, true, false, null, null, "Door & window work", new Guid("a1111111-0000-0000-0000-000000000004"), "door-window-work", (short)1 },
                    { new Guid("a2222222-0000-0000-0004-000000000003"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)3, true, false, null, null, "Wardrobe & storage", new Guid("a1111111-0000-0000-0000-000000000004"), "wardrobe-storage", (short)1 },
                    { new Guid("a2222222-0000-0000-0004-000000000004"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)4, true, false, null, null, "Modular kitchen", new Guid("a1111111-0000-0000-0000-000000000004"), "modular-kitchen", (short)1 },
                    { new Guid("a2222222-0000-0000-0004-000000000005"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)5, true, false, null, null, "Bed & cot work", new Guid("a1111111-0000-0000-0000-000000000004"), "bed-cot-work", (short)1 },
                    { new Guid("a2222222-0000-0000-0004-000000000006"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)6, true, false, null, null, "Custom woodwork", new Guid("a1111111-0000-0000-0000-000000000004"), "custom-woodwork", (short)1 },
                    { new Guid("a2222222-0000-0000-0005-000000000001"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)1, true, false, null, null, "Interior wall painting", new Guid("a1111111-0000-0000-0000-000000000005"), "interior-wall-painting", (short)1 },
                    { new Guid("a2222222-0000-0000-0005-000000000002"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)2, true, false, null, null, "Exterior wall painting", new Guid("a1111111-0000-0000-0000-000000000005"), "exterior-wall-painting", (short)1 },
                    { new Guid("a2222222-0000-0000-0005-000000000003"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)3, true, false, null, null, "Putty & primer work", new Guid("a1111111-0000-0000-0000-000000000005"), "putty-primer-work", (short)1 },
                    { new Guid("a2222222-0000-0000-0005-000000000004"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)4, true, false, null, null, "Texture & stencil", new Guid("a1111111-0000-0000-0000-000000000005"), "texture-stencil", (short)1 },
                    { new Guid("a2222222-0000-0000-0005-000000000005"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)5, true, false, null, null, "Wood polishing", new Guid("a1111111-0000-0000-0000-000000000005"), "wood-polishing", (short)1 },
                    { new Guid("a2222222-0000-0000-0005-000000000006"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)6, true, false, null, null, "Waterproofing", new Guid("a1111111-0000-0000-0000-000000000005"), "waterproofing", (short)1 },
                    { new Guid("a2222222-0000-0000-0006-000000000001"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)1, true, false, null, null, "AC service & repair", new Guid("a1111111-0000-0000-0000-000000000006"), "ac-service-repair", (short)1 },
                    { new Guid("a2222222-0000-0000-0006-000000000002"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)2, true, false, null, null, "Refrigerator repair", new Guid("a1111111-0000-0000-0000-000000000006"), "refrigerator-repair", (short)1 },
                    { new Guid("a2222222-0000-0000-0006-000000000003"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)3, true, false, null, null, "Washing machine repair", new Guid("a1111111-0000-0000-0000-000000000006"), "washing-machine-repair", (short)1 },
                    { new Guid("a2222222-0000-0000-0006-000000000004"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)4, true, false, null, null, "Microwave & oven repair", new Guid("a1111111-0000-0000-0000-000000000006"), "microwave-oven-repair", (short)1 },
                    { new Guid("a2222222-0000-0000-0006-000000000005"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)5, true, false, null, null, "Water purifier service", new Guid("a1111111-0000-0000-0000-000000000006"), "water-purifier-service", (short)1 },
                    { new Guid("a2222222-0000-0000-0006-000000000006"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)6, true, false, null, null, "TV & display repair", new Guid("a1111111-0000-0000-0000-000000000006"), "tv-display-repair", (short)1 },
                    { new Guid("a2222222-0000-0000-0007-000000000001"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)1, true, false, null, null, "General pest control", new Guid("a1111111-0000-0000-0000-000000000007"), "general-pest-control", (short)1 },
                    { new Guid("a2222222-0000-0000-0007-000000000002"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)2, true, false, null, null, "Termite treatment", new Guid("a1111111-0000-0000-0000-000000000007"), "termite-treatment", (short)1 },
                    { new Guid("a2222222-0000-0000-0007-000000000003"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)3, true, false, null, null, "Cockroach control", new Guid("a1111111-0000-0000-0000-000000000007"), "cockroach-control", (short)1 },
                    { new Guid("a2222222-0000-0000-0007-000000000004"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)4, true, false, null, null, "Bed bug treatment", new Guid("a1111111-0000-0000-0000-000000000007"), "bed-bug-treatment", (short)1 },
                    { new Guid("a2222222-0000-0000-0007-000000000005"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)5, true, false, null, null, "Rodent control", new Guid("a1111111-0000-0000-0000-000000000007"), "rodent-control", (short)1 },
                    { new Guid("a2222222-0000-0000-0007-000000000006"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)6, true, false, null, null, "Mosquito control", new Guid("a1111111-0000-0000-0000-000000000007"), "mosquito-control", (short)1 },
                    { new Guid("a2222222-0000-0000-0008-000000000001"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)1, true, false, null, null, "Hair cut & styling", new Guid("a1111111-0000-0000-0000-000000000008"), "hair-cut-styling", (short)1 },
                    { new Guid("a2222222-0000-0000-0008-000000000002"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)2, true, false, null, null, "Facial & clean-up", new Guid("a1111111-0000-0000-0000-000000000008"), "facial-clean-up", (short)1 },
                    { new Guid("a2222222-0000-0000-0008-000000000003"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)3, true, false, null, null, "Waxing & threading", new Guid("a1111111-0000-0000-0000-000000000008"), "waxing-threading", (short)1 },
                    { new Guid("a2222222-0000-0000-0008-000000000004"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)4, true, false, null, null, "Manicure & pedicure", new Guid("a1111111-0000-0000-0000-000000000008"), "manicure-pedicure", (short)1 },
                    { new Guid("a2222222-0000-0000-0008-000000000005"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)5, true, false, null, null, "Bridal makeup", new Guid("a1111111-0000-0000-0000-000000000008"), "bridal-makeup", (short)1 },
                    { new Guid("a2222222-0000-0000-0008-000000000006"), null, new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)6, true, false, null, null, "Massage & spa", new Guid("a1111111-0000-0000-0000-000000000008"), "massage-spa", (short)1 }
                });

            migrationBuilder.CreateIndex(
                name: "ix_business_service_variants_service_sub_category_id",
                table: "business_service_variants",
                column: "service_sub_category_id");

            migrationBuilder.CreateIndex(
                name: "ux_service_sub_categories_category_slug",
                table: "service_sub_categories",
                columns: new[] { "service_category_id", "slug" },
                unique: true,
                filter: "is_deleted = false");

            migrationBuilder.AddForeignKey(
                name: "fk_business_service_variants_service_sub_categories_service_su",
                table: "business_service_variants",
                column: "service_sub_category_id",
                principalTable: "service_sub_categories",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_business_service_variants_service_sub_categories_service_su",
                table: "business_service_variants");

            migrationBuilder.DropTable(
                name: "service_sub_categories");

            migrationBuilder.DropIndex(
                name: "ix_business_service_variants_service_sub_category_id",
                table: "business_service_variants");

            migrationBuilder.DropColumn(
                name: "service_sub_category_id",
                table: "business_service_variants");
        }
    }
}
