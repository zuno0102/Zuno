using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddBookingModule : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "bookings",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    customer_profile_id = table.Column<Guid>(type: "uuid", nullable: false),
                    business_owner_profile_id = table.Column<Guid>(type: "uuid", nullable: false),
                    business_service_id = table.Column<Guid>(type: "uuid", nullable: false),
                    worker_profile_id = table.Column<Guid>(type: "uuid", nullable: true),
                    address_id = table.Column<Guid>(type: "uuid", nullable: false),
                    booking_status = table.Column<short>(type: "smallint", nullable: false),
                    scheduled_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    notes = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    price_quoted = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    completed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    cancelled_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    cancellation_reason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_bookings", x => x.id);
                    table.ForeignKey(
                        name: "fk_bookings_addresses_address_id",
                        column: x => x.address_id,
                        principalTable: "addresses",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_bookings_business_owner_profiles_business_owner_profile_id",
                        column: x => x.business_owner_profile_id,
                        principalTable: "business_owner_profiles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_bookings_business_services_business_service_id",
                        column: x => x.business_service_id,
                        principalTable: "business_services",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_bookings_customer_profiles_customer_profile_id",
                        column: x => x.customer_profile_id,
                        principalTable: "customer_profiles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_bookings_worker_profiles_worker_profile_id",
                        column: x => x.worker_profile_id,
                        principalTable: "worker_profiles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ratings",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    booking_id = table.Column<Guid>(type: "uuid", nullable: false),
                    customer_profile_id = table.Column<Guid>(type: "uuid", nullable: false),
                    business_owner_profile_id = table.Column<Guid>(type: "uuid", nullable: false),
                    score = table.Column<short>(type: "smallint", nullable: false),
                    comment = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_ratings", x => x.id);
                    table.CheckConstraint("ck_ratings_score_range", "score >= 1 AND score <= 5");
                    table.ForeignKey(
                        name: "fk_ratings_bookings_booking_id",
                        column: x => x.booking_id,
                        principalTable: "bookings",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ratings_business_owner_profiles_business_owner_profile_id",
                        column: x => x.business_owner_profile_id,
                        principalTable: "business_owner_profiles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_ratings_customer_profiles_customer_profile_id",
                        column: x => x.customer_profile_id,
                        principalTable: "customer_profiles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "ix_bookings_address_id",
                table: "bookings",
                column: "address_id");

            migrationBuilder.CreateIndex(
                name: "ix_bookings_booking_status",
                table: "bookings",
                column: "booking_status");

            migrationBuilder.CreateIndex(
                name: "ix_bookings_business_owner_profile_id",
                table: "bookings",
                column: "business_owner_profile_id");

            migrationBuilder.CreateIndex(
                name: "ix_bookings_business_service_id",
                table: "bookings",
                column: "business_service_id");

            migrationBuilder.CreateIndex(
                name: "ix_bookings_customer_profile_id",
                table: "bookings",
                column: "customer_profile_id");

            migrationBuilder.CreateIndex(
                name: "ix_bookings_worker_profile_id",
                table: "bookings",
                column: "worker_profile_id");

            migrationBuilder.CreateIndex(
                name: "ix_ratings_business_owner_profile_id",
                table: "ratings",
                column: "business_owner_profile_id");

            migrationBuilder.CreateIndex(
                name: "ix_ratings_customer_profile_id",
                table: "ratings",
                column: "customer_profile_id");

            migrationBuilder.CreateIndex(
                name: "ux_ratings_booking_id",
                table: "ratings",
                column: "booking_id",
                unique: true,
                filter: "is_deleted = false");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ratings");

            migrationBuilder.DropTable(
                name: "bookings");
        }
    }
}
