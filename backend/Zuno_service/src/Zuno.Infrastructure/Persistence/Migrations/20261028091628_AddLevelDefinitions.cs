using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddLevelDefinitions : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "level_definitions",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    audience = table.Column<int>(type: "integer", nullable: false),
                    level = table.Column<int>(type: "integer", nullable: false),
                    name = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    min_completed_jobs = table.Column<int>(type: "integer", nullable: false),
                    min_rating = table.Column<decimal>(type: "numeric(3,2)", precision: 3, scale: 2, nullable: false),
                    min_businesses = table.Column<int>(type: "integer", nullable: false),
                    min_answered_rate = table.Column<decimal>(type: "numeric(4,3)", precision: 4, scale: 3, nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_level_definitions", x => x.id);
                });

            migrationBuilder.InsertData(
                table: "level_definitions",
                columns: new[] { "id", "audience", "created_by", "created_date", "is_deleted", "level", "min_answered_rate", "min_businesses", "min_completed_jobs", "min_rating", "modified_by", "modified_date", "name", "status" },
                values: new object[,]
                {
                    { new Guid("20140d8a-3a14-3cac-5863-5cf8a274fc51"), 1, null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), false, 3, 0.80m, 3, 20, 4.0m, null, null, "Experienced", (short)1 },
                    { new Guid("6b7ac230-8ccd-e081-a718-72926b2584f5"), 0, null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), false, 1, 0m, 0, 0, 0m, null, null, "New", (short)1 },
                    { new Guid("7c404a06-f0f7-4ae4-9f13-1d8fb8a642b9"), 0, null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), false, 4, 0m, 0, 50, 4.3m, null, null, "Established", (short)1 },
                    { new Guid("8144608c-6b5c-8b36-4621-f7279f9034ea"), 0, null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), false, 5, 0m, 0, 100, 4.5m, null, null, "Top rated", (short)1 },
                    { new Guid("bcaebb43-718b-e1dc-78bf-70ab8dfc5d89"), 1, null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), false, 4, 0.85m, 5, 50, 4.3m, null, null, "Very experienced", (short)1 },
                    { new Guid("d2c99a45-b437-230d-44d3-bfecc5b4055e"), 0, null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), false, 3, 0m, 0, 20, 4.0m, null, null, "Trusted", (short)1 },
                    { new Guid("d504fd7e-e562-17ba-2d37-f15d8d6146cb"), 0, null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), false, 2, 0m, 0, 5, 3.5m, null, null, "Rising", (short)1 },
                    { new Guid("e237e2da-637d-0dc4-bed1-8292099865a6"), 1, null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), false, 2, 0.70m, 1, 5, 3.5m, null, null, "Getting established", (short)1 },
                    { new Guid("e6736bee-24a7-9fd9-39c0-90223461aa60"), 1, null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), false, 5, 0.90m, 8, 100, 4.5m, null, null, "Highly experienced", (short)1 },
                    { new Guid("fc00526a-1f9c-d5c5-7000-57866a0d22c5"), 1, null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), false, 1, 0m, 0, 0, 0m, null, null, "New", (short)1 }
                });

            migrationBuilder.InsertData(
                table: "platform_settings",
                columns: new[] { "id", "created_by", "created_date", "description", "is_deleted", "key", "modified_by", "modified_date", "status", "value" },
                values: new object[,]
                {
                    { new Guid("40103091-6304-4fb3-1357-d97adc4720c3"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Longest contract a full-time job post may describe (months).", false, "vacancy.max-contract-months", null, null, (short)1, "60" },
                    { new Guid("51046fce-7bbe-87ca-c26b-f0fbe8aa2fb0"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Most openings one full-time job post may offer.", false, "vacancy.max-openings", null, null, (short)1, "999" },
                    { new Guid("5eff7c8f-fb92-e4c0-3590-a0627ea5c218"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Furthest ahead a customer may book a service (days).", false, "booking.customer-max-days-ahead", null, null, (short)1, "90" },
                    { new Guid("7c3ec82f-6a15-8e30-21fe-cefc2fceca74"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Ratings a worker needs before their average counts towards their level.", false, "worker-level.min-reviews-for-average", null, null, (short)1, "3" },
                    { new Guid("857b0a23-f7ca-c121-9bb0-436989de6381"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "JPEG quality the app compresses photos to before upload (1-100).", false, "media.image-quality", null, null, (short)1, "85" },
                    { new Guid("a4d2398a-43c6-0e7c-f61d-c16e4fdd5edf"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Longest a service video may run (seconds).", false, "service.video-max-seconds", null, null, (short)1, "30" },
                    { new Guid("b075c538-b5bd-3532-ed10-c47b6129f8f9"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Reviews a business needs before its average counts towards its level.", false, "business-level.min-reviews-for-average", null, null, (short)1, "3" },
                    { new Guid("c6bb5ba0-f03b-03f4-e5e7-68c427a902ca"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Furthest ahead a date can be picked in the app (days).", false, "schedule.max-days-ahead", null, null, (short)1, "365" },
                    { new Guid("f1866297-a5c1-0ce5-5066-8fa5d901cb44"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Offers a worker needs before their answered-offers rate counts towards their level.", false, "worker-level.min-offers-for-rate", null, null, (short)1, "5" },
                    { new Guid("f282dbf3-b7c3-dfed-8336-eae8d36746a0"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Widest a photo is uploaded at (pixels).", false, "media.image-max-width", null, null, (short)1, "1600" }
                });

            migrationBuilder.CreateIndex(
                name: "ux_level_definitions_audience_level",
                table: "level_definitions",
                columns: new[] { "audience", "level" },
                unique: true,
                filter: "is_deleted = false");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "level_definitions");

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("40103091-6304-4fb3-1357-d97adc4720c3"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("51046fce-7bbe-87ca-c26b-f0fbe8aa2fb0"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("5eff7c8f-fb92-e4c0-3590-a0627ea5c218"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("7c3ec82f-6a15-8e30-21fe-cefc2fceca74"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("857b0a23-f7ca-c121-9bb0-436989de6381"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("a4d2398a-43c6-0e7c-f61d-c16e4fdd5edf"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("b075c538-b5bd-3532-ed10-c47b6129f8f9"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("c6bb5ba0-f03b-03f4-e5e7-68c427a902ca"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("f1866297-a5c1-0ce5-5066-8fa5d901cb44"));

            migrationBuilder.DeleteData(
                table: "platform_settings",
                keyColumn: "id",
                keyValue: new Guid("f282dbf3-b7c3-dfed-8336-eae8d36746a0"));
        }
    }
}
