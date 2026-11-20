using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddBusinessPlans : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "plan_paused_listings",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    owner_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    area = table.Column<short>(type: "smallint", nullable: false),
                    listing_id = table.Column<Guid>(type: "uuid", nullable: false),
                    paused_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_plan_paused_listings", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "subscription_plans",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    code = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    name = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    includes_service = table.Column<bool>(type: "boolean", nullable: false),
                    includes_rent = table.Column<bool>(type: "boolean", nullable: false),
                    includes_marketplace = table.Column<bool>(type: "boolean", nullable: false),
                    max_live_listings = table.Column<int>(type: "integer", nullable: true),
                    price = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    duration_days = table.Column<int>(type: "integer", nullable: true),
                    period = table.Column<short>(type: "smallint", nullable: false),
                    is_default = table.Column<bool>(type: "boolean", nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    sort_order = table.Column<short>(type: "smallint", nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_subscription_plans", x => x.id);
                    table.CheckConstraint("ck_subscription_plans_duration_days", "duration_days IS NULL OR duration_days > 0");
                    table.CheckConstraint("ck_subscription_plans_max_live_listings", "max_live_listings IS NULL OR max_live_listings >= 0");
                    table.CheckConstraint("ck_subscription_plans_price", "price >= 0");
                });

            migrationBuilder.CreateTable(
                name: "business_subscriptions",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    owner_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    plan_id = table.Column<Guid>(type: "uuid", nullable: false),
                    plan_name = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    amount = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    duration_days = table.Column<int>(type: "integer", nullable: false),
                    includes_service = table.Column<bool>(type: "boolean", nullable: false),
                    includes_rent = table.Column<bool>(type: "boolean", nullable: false),
                    includes_marketplace = table.Column<bool>(type: "boolean", nullable: false),
                    state = table.Column<short>(type: "smallint", nullable: false),
                    starts_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    ends_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    pending_order_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    payment_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    paid_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_business_subscriptions", x => x.id);
                    table.CheckConstraint("ck_business_subscriptions_amount", "amount >= 0");
                    table.CheckConstraint("ck_business_subscriptions_state", "state BETWEEN 1 AND 3");
                    table.ForeignKey(
                        name: "fk_business_subscriptions_subscription_plans_plan_id",
                        column: x => x.plan_id,
                        principalTable: "subscription_plans",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.InsertData(
                table: "subscription_plans",
                columns: new[] { "id", "code", "created_by", "created_date", "duration_days", "includes_marketplace", "includes_rent", "includes_service", "is_active", "is_default", "is_deleted", "max_live_listings", "modified_by", "modified_date", "name", "period", "price", "sort_order", "status" },
                values: new object[,]
                {
                    { new Guid("c6666666-0000-0000-0000-000000000001"), "basic", null, new DateTimeOffset(new DateTime(2026, 11, 21, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), null, true, true, true, true, true, false, 1, null, null, "Basic", (short)0, 0m, (short)1, (short)1 },
                    { new Guid("c6666666-0000-0000-0000-000000000002"), "service-monthly", null, new DateTimeOffset(new DateTime(2026, 11, 21, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), 30, false, false, true, true, false, false, null, null, null, "Service", (short)1, 199m, (short)2, (short)1 },
                    { new Guid("c6666666-0000-0000-0000-000000000003"), "service-annual", null, new DateTimeOffset(new DateTime(2026, 11, 21, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), 365, false, false, true, true, false, false, null, null, null, "Service", (short)2, 1999m, (short)3, (short)1 },
                    { new Guid("c6666666-0000-0000-0000-000000000004"), "rent-monthly", null, new DateTimeOffset(new DateTime(2026, 11, 21, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), 30, false, true, false, true, false, false, null, null, null, "Rent", (short)1, 199m, (short)4, (short)1 },
                    { new Guid("c6666666-0000-0000-0000-000000000005"), "rent-annual", null, new DateTimeOffset(new DateTime(2026, 11, 21, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), 365, false, true, false, true, false, false, null, null, null, "Rent", (short)2, 1999m, (short)5, (short)1 },
                    { new Guid("c6666666-0000-0000-0000-000000000006"), "marketplace-monthly", null, new DateTimeOffset(new DateTime(2026, 11, 21, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), 30, true, false, false, true, false, false, null, null, null, "Marketplace", (short)1, 399m, (short)6, (short)1 },
                    { new Guid("c6666666-0000-0000-0000-000000000007"), "marketplace-annual", null, new DateTimeOffset(new DateTime(2026, 11, 21, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), 365, true, false, false, true, false, false, null, null, null, "Marketplace", (short)2, 3999m, (short)7, (short)1 },
                    { new Guid("c6666666-0000-0000-0000-000000000008"), "service-rent-monthly", null, new DateTimeOffset(new DateTime(2026, 11, 21, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), 30, false, true, true, true, false, false, null, null, null, "Service + Rent", (short)1, 349m, (short)8, (short)1 },
                    { new Guid("c6666666-0000-0000-0000-000000000009"), "service-rent-annual", null, new DateTimeOffset(new DateTime(2026, 11, 21, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), 365, false, true, true, true, false, false, null, null, null, "Service + Rent", (short)2, 3499m, (short)9, (short)1 },
                    { new Guid("c6666666-0000-0000-0000-000000000010"), "service-marketplace-monthly", null, new DateTimeOffset(new DateTime(2026, 11, 21, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), 30, true, false, true, true, false, false, null, null, null, "Service + Marketplace", (short)1, 499m, (short)10, (short)1 },
                    { new Guid("c6666666-0000-0000-0000-000000000011"), "service-marketplace-annual", null, new DateTimeOffset(new DateTime(2026, 11, 21, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), 365, true, false, true, true, false, false, null, null, null, "Service + Marketplace", (short)2, 4999m, (short)11, (short)1 },
                    { new Guid("c6666666-0000-0000-0000-000000000012"), "rent-marketplace-monthly", null, new DateTimeOffset(new DateTime(2026, 11, 21, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), 30, true, true, false, true, false, false, null, null, null, "Rent + Marketplace", (short)1, 549m, (short)12, (short)1 },
                    { new Guid("c6666666-0000-0000-0000-000000000013"), "rent-marketplace-annual", null, new DateTimeOffset(new DateTime(2026, 11, 21, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), 365, true, true, false, true, false, false, null, null, null, "Rent + Marketplace", (short)2, 5499m, (short)13, (short)1 },
                    { new Guid("c6666666-0000-0000-0000-000000000014"), "all3-monthly", null, new DateTimeOffset(new DateTime(2026, 11, 21, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), 30, true, true, true, true, false, false, null, null, null, "All 3", (short)1, 699m, (short)14, (short)1 },
                    { new Guid("c6666666-0000-0000-0000-000000000015"), "all3-annual", null, new DateTimeOffset(new DateTime(2026, 11, 21, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), 365, true, true, true, true, false, false, null, null, null, "All 3", (short)2, 6999m, (short)15, (short)1 }
                });

            migrationBuilder.UpdateData(
                table: "vacancy_fee_plans",
                keyColumn: "id",
                keyValue: new Guid("c5555555-0000-0000-0000-000000000001"),
                columns: new[] { "amount", "name" },
                values: new object[] { 99m, "1 month" });

            migrationBuilder.InsertData(
                table: "vacancy_fee_plans",
                columns: new[] { "id", "amount", "created_by", "created_date", "is_active", "is_deleted", "listing_days", "modified_by", "modified_date", "name", "sort_order", "status" },
                values: new object[,]
                {
                    { new Guid("c5555555-0000-0000-0000-000000000002"), 149m, null, new DateTimeOffset(new DateTime(2026, 10, 27, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), true, false, 60, null, null, "2 months", (short)2, (short)1 },
                    { new Guid("c5555555-0000-0000-0000-000000000003"), 249m, null, new DateTimeOffset(new DateTime(2026, 10, 27, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), true, false, 180, null, null, "6 months", (short)3, (short)1 }
                });

            migrationBuilder.CreateIndex(
                name: "ix_business_subscriptions_owner_state_ends",
                table: "business_subscriptions",
                columns: new[] { "owner_user_id", "state", "ends_at" });

            migrationBuilder.CreateIndex(
                name: "ix_business_subscriptions_plan_id",
                table: "business_subscriptions",
                column: "plan_id");

            migrationBuilder.CreateIndex(
                name: "ix_business_subscriptions_state_ends",
                table: "business_subscriptions",
                columns: new[] { "state", "ends_at" });

            migrationBuilder.CreateIndex(
                name: "ux_business_subscriptions_payment_id",
                table: "business_subscriptions",
                column: "payment_id",
                unique: true,
                filter: "payment_id IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "ux_plan_paused_listings_owner_area_listing",
                table: "plan_paused_listings",
                columns: new[] { "owner_user_id", "area", "listing_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ux_subscription_plans_code",
                table: "subscription_plans",
                column: "code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ux_subscription_plans_default",
                table: "subscription_plans",
                column: "is_default",
                unique: true,
                filter: "is_default = true");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "business_subscriptions");

            migrationBuilder.DropTable(
                name: "plan_paused_listings");

            migrationBuilder.DropTable(
                name: "subscription_plans");

            migrationBuilder.DeleteData(
                table: "vacancy_fee_plans",
                keyColumn: "id",
                keyValue: new Guid("c5555555-0000-0000-0000-000000000002"));

            migrationBuilder.DeleteData(
                table: "vacancy_fee_plans",
                keyColumn: "id",
                keyValue: new Guid("c5555555-0000-0000-0000-000000000003"));

            migrationBuilder.UpdateData(
                table: "vacancy_fee_plans",
                keyColumn: "id",
                keyValue: new Guid("c5555555-0000-0000-0000-000000000001"),
                columns: new[] { "amount", "name" },
                values: new object[] { 49m, "Standard listing" });
        }
    }
}
