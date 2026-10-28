using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddPlatformSettings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "platform_settings",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    key = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    value = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    description = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_platform_settings", x => x.id);
                });

            migrationBuilder.InsertData(
                table: "platform_settings",
                columns: new[] { "id", "created_by", "created_date", "description", "is_deleted", "key", "modified_by", "modified_date", "status", "value" },
                values: new object[,]
                {
                    { new Guid("144736b4-1aa3-1744-3e9b-9c5e277de372"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Job length assumed when a service gives none (minutes).", false, "schedule.default-job-minutes", null, null, (short)1, "120" },
                    { new Guid("1968ef61-b5e5-cc40-f4ca-3eaf3ea88c6a"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Further-away and unlocated jobs added to a nearby feed.", false, "hiring-feed.side-group-cap", null, null, (short)1, "10" },
                    { new Guid("1c6c03be-31d2-10e4-3e9c-5d206cc29fd2"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Furthest a customer may be from a served district's centre (km).", false, "service-area.max-distance-km", null, null, (short)1, "150" },
                    { new Guid("214d4020-e887-654d-b401-65db4e89aaa4"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Gap a worker needs between two jobs (minutes).", false, "schedule.travel-buffer-minutes", null, null, (short)1, "30" },
                    { new Guid("23ad102a-a9f0-dcf5-7eb1-9bb2ff19fea0"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Most questions a service may ask the customer.", false, "service.max-questions", null, null, (short)1, "15" },
                    { new Guid("44643e2b-5693-f981-baf5-0d043f01bbbe"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Jobs shown per page in a worker's Find work feed.", false, "hiring-feed.default-page-size", null, null, (short)1, "60" },
                    { new Guid("4b44c17d-167b-aa2c-e380-2f32d466d907"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Longest job a hiring post may describe (minutes).", false, "hiring-post.max-duration-minutes", null, null, (short)1, "1440" },
                    { new Guid("4f1318a6-525a-7011-d04d-7ea3e6d514ee"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Most jobs a worker's Find work feed may ask for at once.", false, "hiring-feed.max-page-size", null, null, (short)1, "100" },
                    { new Guid("50a46fb0-b5ee-4579-c78d-4c1ee5317baa"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Length a hiring post gets when none is given (minutes).", false, "hiring-post.default-duration-minutes", null, null, (short)1, "120" },
                    { new Guid("674181cf-c6d5-d5bf-4686-3c48741e8489"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Most workers one hiring post may ask for.", false, "hiring-post.max-workers", null, null, (short)1, "100" },
                    { new Guid("74577a96-904f-2c88-22e7-daaef781aa18"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Shortest job a hiring post may describe (minutes).", false, "hiring-post.min-duration-minutes", null, null, (short)1, "15" },
                    { new Guid("92990531-02e1-a739-b39d-b12062e2a351"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Most people one order's crew may be set to.", false, "order.max-crew-size", null, null, (short)1, "100" },
                    { new Guid("9b24cd12-870a-071e-b96b-2ee8470d27c3"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Photo slots per service and per package.", false, "service.image-slots", null, null, (short)1, "3" },
                    { new Guid("9d981c59-1c68-3632-add5-f5680b4fbb29"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "How far past the nearest district a customer may be and still be served (km).", false, "service-area.border-slack-km", null, null, (short)1, "25" },
                    { new Guid("ab457f5b-20c9-cd16-88c6-a8d18c726b65"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Rows in each business home list.", false, "business-dashboard.detail-limit", null, null, (short)1, "50" },
                    { new Guid("bc1d398e-8ee9-0a33-b7f7-408ae6749b7b"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Months shown on the worker home trend chart.", false, "worker-dashboard.trend-months", null, null, (short)1, "6" },
                    { new Guid("d5c12ede-b430-3911-6d3f-960991164833"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Furthest a pin may be from a district centre and still be placed in it (km).", false, "district.match-max-distance-km", null, null, (short)1, "150" },
                    { new Guid("dc9f08a1-b535-1697-98a7-78c7cebd90bf"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Rows in each worker home list.", false, "worker-dashboard.detail-limit", null, null, (short)1, "25" },
                    { new Guid("ef5b0164-7aaf-85d1-4473-1a3e20c0d724"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Months shown on the business home trend chart.", false, "business-dashboard.trend-months", null, null, (short)1, "6" },
                    { new Guid("f2a8c0c7-aae1-0a16-32ba-c9b5f73e5cc7"), null, new DateTimeOffset(new DateTime(2026, 10, 28, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), "Rows a distance search reads before measuring (performance cap).", false, "hiring-feed.bounding-box-row-cap", null, null, (short)1, "500" }
                });

            migrationBuilder.CreateIndex(
                name: "ux_platform_settings_key",
                table: "platform_settings",
                column: "key",
                unique: true,
                filter: "is_deleted = false");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "platform_settings");
        }
    }
}
