using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddPayoutFoundation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "paid_at",
                table: "hiring_post_offline_hires",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<short>(
                name: "payment_status",
                table: "hiring_post_offline_hires",
                type: "smallint",
                nullable: false,
                defaultValue: (short)1);

            migrationBuilder.AddColumn<string>(
                name: "dispute_reason",
                table: "hiring_post_applications",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "disputed_at",
                table: "hiring_post_applications",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "paid_at",
                table: "hiring_post_applications",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<short>(
                name: "payment_status",
                table: "hiring_post_applications",
                type: "smallint",
                nullable: false,
                defaultValue: (short)1);

            migrationBuilder.CreateTable(
                name: "payout_batches",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    hiring_post_id = table.Column<Guid>(type: "uuid", nullable: false),
                    business_owner_profile_id = table.Column<Guid>(type: "uuid", nullable: false),
                    total_amount = table.Column<decimal>(type: "numeric(12,2)", precision: 12, scale: 2, nullable: false),
                    batch_status = table.Column<short>(type: "smallint", nullable: false),
                    provider_order_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    provider_payment_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    funded_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    completed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    idempotency_key = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_payout_batches", x => x.id);
                    table.ForeignKey(
                        name: "fk_payout_batches_business_owner_profiles_business_owner_profi",
                        column: x => x.business_owner_profile_id,
                        principalTable: "business_owner_profiles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_payout_batches_hiring_posts_hiring_post_id",
                        column: x => x.hiring_post_id,
                        principalTable: "hiring_posts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "worker_payout_details",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    worker_profile_id = table.Column<Guid>(type: "uuid", nullable: false),
                    upi_vpa = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    account_number = table.Column<string>(type: "character varying(34)", maxLength: 34, nullable: true),
                    ifsc_code = table.Column<string>(type: "character varying(11)", maxLength: 11, nullable: true),
                    account_holder_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    verification_status = table.Column<short>(type: "smallint", nullable: false),
                    verified_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    provider_fund_account_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_worker_payout_details", x => x.id);
                    table.ForeignKey(
                        name: "fk_worker_payout_details_worker_profiles_worker_profile_id",
                        column: x => x.worker_profile_id,
                        principalTable: "worker_profiles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "payout_batch_items",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    payout_batch_id = table.Column<Guid>(type: "uuid", nullable: false),
                    hiring_post_application_id = table.Column<Guid>(type: "uuid", nullable: true),
                    hiring_post_offline_hire_id = table.Column<Guid>(type: "uuid", nullable: true),
                    worker_profile_id = table.Column<Guid>(type: "uuid", nullable: true),
                    worker_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    amount = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    payment_status = table.Column<short>(type: "smallint", nullable: false),
                    provider_payout_id = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    failure_reason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
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
                    table.PrimaryKey("pk_payout_batch_items", x => x.id);
                    table.ForeignKey(
                        name: "fk_payout_batch_items_hiring_post_applications_hiring_post_app",
                        column: x => x.hiring_post_application_id,
                        principalTable: "hiring_post_applications",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_payout_batch_items_hiring_post_offline_hires_hiring_post_of",
                        column: x => x.hiring_post_offline_hire_id,
                        principalTable: "hiring_post_offline_hires",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_payout_batch_items_payout_batches_payout_batch_id",
                        column: x => x.payout_batch_id,
                        principalTable: "payout_batches",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_payout_batch_items_worker_profiles_worker_profile_id",
                        column: x => x.worker_profile_id,
                        principalTable: "worker_profiles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "ix_payout_batch_items_hiring_post_application_id",
                table: "payout_batch_items",
                column: "hiring_post_application_id");

            migrationBuilder.CreateIndex(
                name: "ix_payout_batch_items_hiring_post_offline_hire_id",
                table: "payout_batch_items",
                column: "hiring_post_offline_hire_id");

            migrationBuilder.CreateIndex(
                name: "ix_payout_batch_items_payout_batch_id",
                table: "payout_batch_items",
                column: "payout_batch_id");

            migrationBuilder.CreateIndex(
                name: "ix_payout_batch_items_provider_payout_id",
                table: "payout_batch_items",
                column: "provider_payout_id");

            migrationBuilder.CreateIndex(
                name: "ix_payout_batch_items_worker_profile_id",
                table: "payout_batch_items",
                column: "worker_profile_id");

            migrationBuilder.CreateIndex(
                name: "ix_payout_batches_business_owner_profile_id",
                table: "payout_batches",
                column: "business_owner_profile_id");

            migrationBuilder.CreateIndex(
                name: "ix_payout_batches_hiring_post_id",
                table: "payout_batches",
                column: "hiring_post_id");

            migrationBuilder.CreateIndex(
                name: "ix_payout_batches_provider_order_id",
                table: "payout_batches",
                column: "provider_order_id");

            migrationBuilder.CreateIndex(
                name: "ux_payout_batches_idempotency_key",
                table: "payout_batches",
                column: "idempotency_key",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ux_worker_payout_details_worker_profile_id",
                table: "worker_payout_details",
                column: "worker_profile_id",
                unique: true,
                filter: "is_deleted = false");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "payout_batch_items");

            migrationBuilder.DropTable(
                name: "worker_payout_details");

            migrationBuilder.DropTable(
                name: "payout_batches");

            migrationBuilder.DropColumn(
                name: "paid_at",
                table: "hiring_post_offline_hires");

            migrationBuilder.DropColumn(
                name: "payment_status",
                table: "hiring_post_offline_hires");

            migrationBuilder.DropColumn(
                name: "dispute_reason",
                table: "hiring_post_applications");

            migrationBuilder.DropColumn(
                name: "disputed_at",
                table: "hiring_post_applications");

            migrationBuilder.DropColumn(
                name: "paid_at",
                table: "hiring_post_applications");

            migrationBuilder.DropColumn(
                name: "payment_status",
                table: "hiring_post_applications");
        }
    }
}
