using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace Zuno.Marketplace.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddMarketplaceOrders : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<short>(
                name: "purpose",
                table: "marketplace_plans",
                type: "smallint",
                nullable: false,
                defaultValue: (short)1);

            migrationBuilder.AddColumn<bool>(
                name: "accepts_cash_on_delivery",
                table: "marketplace_businesses",
                type: "boolean",
                nullable: false,
                defaultValue: true);

            migrationBuilder.AddColumn<bool>(
                name: "accepts_online_pay",
                table: "marketplace_businesses",
                type: "boolean",
                nullable: false,
                defaultValue: true);

            migrationBuilder.CreateTable(
                name: "marketplace_b2b_requests",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    post_id = table.Column<Guid>(type: "uuid", nullable: false),
                    owner_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    buyer_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    buyer_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    buyer_phone = table.Column<string>(type: "character varying(15)", maxLength: 15, nullable: true),
                    title = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    quantity = table.Column<int>(type: "integer", nullable: false),
                    unit = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    unit_price = table.Column<decimal>(type: "numeric(14,2)", precision: 14, scale: 2, nullable: true),
                    message = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    status = table.Column<short>(type: "smallint", nullable: false),
                    responded_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    seller_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    seller_phone = table.Column<string>(type: "character varying(15)", maxLength: 15, nullable: true),
                    xmin = table.Column<uint>(type: "xid", rowVersion: true, nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_marketplace_b2b_requests", x => x.id);
                    table.CheckConstraint("ck_marketplace_b2b_requests_quantity", "quantity >= 1");
                    table.CheckConstraint("ck_marketplace_b2b_requests_status", "status IN (1, 2, 3)");
                    table.ForeignKey(
                        name: "fk_marketplace_b2b_requests_posts_post_id",
                        column: x => x.post_id,
                        principalTable: "marketplace_posts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "marketplace_orders",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    post_id = table.Column<Guid>(type: "uuid", nullable: false),
                    variant_id = table.Column<Guid>(type: "uuid", nullable: true),
                    owner_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    customer_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    customer_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    customer_phone = table.Column<string>(type: "character varying(15)", maxLength: 15, nullable: false),
                    delivery_address = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    pincode = table.Column<string>(type: "character varying(6)", maxLength: 6, nullable: false),
                    title = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    variant_name = table.Column<string>(type: "character varying(70)", maxLength: 70, nullable: true),
                    quantity = table.Column<int>(type: "integer", nullable: false),
                    unit_price = table.Column<decimal>(type: "numeric(14,2)", precision: 14, scale: 2, nullable: false),
                    amount = table.Column<decimal>(type: "numeric(14,2)", precision: 14, scale: 2, nullable: false),
                    payment_method = table.Column<short>(type: "smallint", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false),
                    pay_by = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    paid_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    provider_order_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    provider_payment_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    refund_due = table.Column<bool>(type: "boolean", nullable: false),
                    refund_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    courier_code = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: true),
                    courier_name = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: true),
                    tracking_number = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: true),
                    receipt_url = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    shipped_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    delivered_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    closes_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    closed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    cancelled_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    cancelled_by = table.Column<short>(type: "smallint", nullable: true),
                    rating_score = table.Column<short>(type: "smallint", nullable: true),
                    rating_comment = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    rated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    xmin = table.Column<uint>(type: "xid", rowVersion: true, nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_marketplace_orders", x => x.id);
                    table.CheckConstraint("ck_marketplace_orders_amount", "unit_price > 0 AND amount > 0");
                    table.CheckConstraint("ck_marketplace_orders_payment_method", "payment_method IN (1, 2)");
                    table.CheckConstraint("ck_marketplace_orders_quantity", "quantity >= 1");
                    table.CheckConstraint("ck_marketplace_orders_rating", "rating_score IS NULL OR rating_score BETWEEN 1 AND 5");
                    table.CheckConstraint("ck_marketplace_orders_status", "status BETWEEN 1 AND 8");
                    table.CheckConstraint("ck_marketplace_orders_tracking", "status NOT IN (4, 5) OR (courier_name IS NOT NULL AND tracking_number IS NOT NULL)");
                    table.ForeignKey(
                        name: "fk_marketplace_orders_posts_post_id",
                        column: x => x.post_id,
                        principalTable: "marketplace_posts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ref_marketplace_b2b_request_statuses",
                columns: table => new
                {
                    code = table.Column<short>(type: "smallint", nullable: false),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    tone = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    display_order = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ref_marketplace_b2b_request_statuses", x => x.code);
                });

            migrationBuilder.CreateTable(
                name: "ref_marketplace_couriers",
                columns: table => new
                {
                    code = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    name = table.Column<string>(type: "character varying(60)", maxLength: 60, nullable: false),
                    tracking_url = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    takes_custom_name = table.Column<bool>(type: "boolean", nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    display_order = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ref_marketplace_couriers", x => x.code);
                });

            migrationBuilder.CreateTable(
                name: "ref_marketplace_order_statuses",
                columns: table => new
                {
                    code = table.Column<short>(type: "smallint", nullable: false),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    tone = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    display_order = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ref_marketplace_order_statuses", x => x.code);
                });

            migrationBuilder.CreateTable(
                name: "ref_marketplace_order_transitions",
                columns: table => new
                {
                    from_status = table.Column<short>(type: "smallint", nullable: false),
                    to_status = table.Column<short>(type: "smallint", nullable: false),
                    action_name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    needs_confirm = table.Column<bool>(type: "boolean", nullable: false),
                    business_may = table.Column<bool>(type: "boolean", nullable: false),
                    customer_may = table.Column<bool>(type: "boolean", nullable: false),
                    needs_tracking = table.Column<bool>(type: "boolean", nullable: false),
                    display_order = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ref_marketplace_order_transitions", x => new { x.from_status, x.to_status });
                });

            migrationBuilder.CreateTable(
                name: "ref_marketplace_payment_methods",
                columns: table => new
                {
                    code = table.Column<short>(type: "smallint", nullable: false),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    detail = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    display_order = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ref_marketplace_payment_methods", x => x.code);
                });

            migrationBuilder.CreateTable(
                name: "marketplace_order_events",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    order_id = table.Column<Guid>(type: "uuid", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false),
                    actor = table.Column<short>(type: "smallint", nullable: false),
                    actor_user_id = table.Column<Guid>(type: "uuid", nullable: true),
                    note = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_marketplace_order_events", x => x.id);
                    table.CheckConstraint("ck_marketplace_order_events_actor", "actor IN (1, 2, 3)");
                    table.ForeignKey(
                        name: "fk_marketplace_order_events_marketplace_orders_order_id",
                        column: x => x.order_id,
                        principalTable: "marketplace_orders",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.UpdateData(
                table: "marketplace_plans",
                keyColumn: "id",
                keyValue: new Guid("e5555555-0000-0000-0000-000000000001"),
                column: "purpose",
                value: (short)1);

            migrationBuilder.InsertData(
                table: "marketplace_plans",
                columns: new[] { "id", "code", "created_by", "created_date", "display_order", "duration_days", "is_active", "is_default", "is_deleted", "max_active_posts", "modified_by", "modified_date", "name", "price", "purpose" },
                values: new object[] { new Guid("e5555555-0000-0000-0000-000000000002"), "b2b-buyer", null, new DateTimeOffset(new DateTime(2026, 11, 11, 0, 0, 0, 0, DateTimeKind.Unspecified), new TimeSpan(0, 0, 0, 0, 0)), (short)2, 30, true, false, false, 0, null, null, "B2B buyer", 199m, (short)2 });

            migrationBuilder.InsertData(
                table: "ref_marketplace_b2b_request_statuses",
                columns: new[] { "code", "display_order", "name", "tone" },
                values: new object[,]
                {
                    { (short)1, (short)1, "New", "danger" },
                    { (short)2, (short)2, "Accepted", "success" },
                    { (short)3, (short)3, "Declined", "waiting" }
                });

            migrationBuilder.InsertData(
                table: "ref_marketplace_couriers",
                columns: new[] { "code", "display_order", "is_active", "name", "takes_custom_name", "tracking_url" },
                values: new object[,]
                {
                    { "blue-dart", (short)6, true, "Blue Dart", false, null },
                    { "delhivery", (short)5, true, "Delhivery", false, "https://www.delhivery.com/track/package/{number}" },
                    { "dtdc", (short)2, true, "DTDC", false, null },
                    { "india-post", (short)1, true, "India Post", false, null },
                    { "other", (short)99, true, "Other", true, null },
                    { "professional", (short)4, true, "The Professional Couriers", false, null },
                    { "st-courier", (short)3, true, "ST Courier", false, null }
                });

            migrationBuilder.InsertData(
                table: "ref_marketplace_order_statuses",
                columns: new[] { "code", "display_order", "name", "tone" },
                values: new object[,]
                {
                    { (short)1, (short)2, "Awaiting payment", "waiting" },
                    { (short)2, (short)1, "New", "danger" },
                    { (short)3, (short)3, "Confirmed", "progress" },
                    { (short)4, (short)4, "Shipped", "progress" },
                    { (short)5, (short)5, "Out for delivery", "progress" },
                    { (short)6, (short)6, "Delivered", "success" },
                    { (short)7, (short)7, "Closed", "success" },
                    { (short)8, (short)8, "Cancelled", "waiting" }
                });

            migrationBuilder.InsertData(
                table: "ref_marketplace_order_transitions",
                columns: new[] { "from_status", "to_status", "action_name", "business_may", "customer_may", "display_order", "needs_confirm", "needs_tracking" },
                values: new object[,]
                {
                    { (short)1, (short)8, "Cancel order", false, true, (short)6, true, false },
                    { (short)2, (short)3, "Confirm order", true, false, (short)1, false, false },
                    { (short)2, (short)8, "Cancel order", false, true, (short)7, true, false },
                    { (short)3, (short)4, "Mark shipped", true, false, (short)2, false, true },
                    { (short)3, (short)8, "Cancel order", false, true, (short)8, true, false },
                    { (short)4, (short)5, "Out for delivery", true, false, (short)3, false, false },
                    { (short)4, (short)6, "Mark delivered", true, false, (short)5, true, false },
                    { (short)5, (short)6, "Mark delivered", true, false, (short)4, true, false }
                });

            migrationBuilder.InsertData(
                table: "ref_marketplace_payment_methods",
                columns: new[] { "code", "detail", "display_order", "name" },
                values: new object[,]
                {
                    { (short)1, "The customer pays the courier or you when it arrives.", (short)1, "Cash on delivery" },
                    { (short)2, "UPI, cards and net banking. The order is confirmed only after the payment goes through.", (short)2, "Online pay" }
                });

            migrationBuilder.AddCheckConstraint(
                name: "ck_marketplace_plans_purpose",
                table: "marketplace_plans",
                sql: "purpose IN (1, 2)");

            migrationBuilder.AddCheckConstraint(
                name: "ck_marketplace_businesses_payment",
                table: "marketplace_businesses",
                sql: "accepts_cash_on_delivery OR accepts_online_pay");

            migrationBuilder.CreateIndex(
                name: "ix_marketplace_b2b_requests_buyer_user_id_created_date",
                table: "marketplace_b2b_requests",
                columns: new[] { "buyer_user_id", "created_date" });

            migrationBuilder.CreateIndex(
                name: "ix_marketplace_b2b_requests_owner_user_id_status_created_date",
                table: "marketplace_b2b_requests",
                columns: new[] { "owner_user_id", "status", "created_date" });

            migrationBuilder.CreateIndex(
                name: "ix_marketplace_b2b_requests_post_id_buyer_user_id",
                table: "marketplace_b2b_requests",
                columns: new[] { "post_id", "buyer_user_id" },
                unique: true,
                filter: "status = 1 AND is_deleted = false");

            migrationBuilder.CreateIndex(
                name: "ix_marketplace_order_events_order_id_at",
                table: "marketplace_order_events",
                columns: new[] { "order_id", "at" });

            migrationBuilder.CreateIndex(
                name: "ix_marketplace_orders_customer_user_id_created_date",
                table: "marketplace_orders",
                columns: new[] { "customer_user_id", "created_date" });

            migrationBuilder.CreateIndex(
                name: "ix_marketplace_orders_owner_user_id_status_created_date",
                table: "marketplace_orders",
                columns: new[] { "owner_user_id", "status", "created_date" });

            migrationBuilder.CreateIndex(
                name: "ix_marketplace_orders_post_id",
                table: "marketplace_orders",
                column: "post_id");

            migrationBuilder.CreateIndex(
                name: "ix_marketplace_orders_provider_payment_id",
                table: "marketplace_orders",
                column: "provider_payment_id",
                unique: true,
                filter: "provider_payment_id IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "ix_marketplace_orders_status_closes_at",
                table: "marketplace_orders",
                columns: new[] { "status", "closes_at" });

            migrationBuilder.CreateIndex(
                name: "ix_marketplace_orders_status_pay_by",
                table: "marketplace_orders",
                columns: new[] { "status", "pay_by" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "marketplace_b2b_requests");

            migrationBuilder.DropTable(
                name: "marketplace_order_events");

            migrationBuilder.DropTable(
                name: "ref_marketplace_b2b_request_statuses");

            migrationBuilder.DropTable(
                name: "ref_marketplace_couriers");

            migrationBuilder.DropTable(
                name: "ref_marketplace_order_statuses");

            migrationBuilder.DropTable(
                name: "ref_marketplace_order_transitions");

            migrationBuilder.DropTable(
                name: "ref_marketplace_payment_methods");

            migrationBuilder.DropTable(
                name: "marketplace_orders");

            migrationBuilder.DropCheckConstraint(
                name: "ck_marketplace_plans_purpose",
                table: "marketplace_plans");

            migrationBuilder.DropCheckConstraint(
                name: "ck_marketplace_businesses_payment",
                table: "marketplace_businesses");

            migrationBuilder.DeleteData(
                table: "marketplace_plans",
                keyColumn: "id",
                keyValue: new Guid("e5555555-0000-0000-0000-000000000002"));

            migrationBuilder.DropColumn(
                name: "purpose",
                table: "marketplace_plans");

            migrationBuilder.DropColumn(
                name: "accepts_cash_on_delivery",
                table: "marketplace_businesses");

            migrationBuilder.DropColumn(
                name: "accepts_online_pay",
                table: "marketplace_businesses");

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
        }
    }
}
