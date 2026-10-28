using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddHiringPosts : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "hiring_posts",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    business_owner_profile_id = table.Column<Guid>(type: "uuid", nullable: false),
                    title = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    description = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    image_url = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    event_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    location = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    auditorium_name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    workers_needed = table.Column<int>(type: "integer", nullable: false),
                    hiring_post_status = table.Column<short>(type: "smallint", nullable: false),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_hiring_posts", x => x.id);
                    table.ForeignKey(
                        name: "fk_hiring_posts_business_owner_profiles_business_owner_profile",
                        column: x => x.business_owner_profile_id,
                        principalTable: "business_owner_profiles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "hiring_post_applications",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    hiring_post_id = table.Column<Guid>(type: "uuid", nullable: false),
                    worker_profile_id = table.Column<Guid>(type: "uuid", nullable: false),
                    application_status = table.Column<short>(type: "smallint", nullable: false),
                    responded_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_hiring_post_applications", x => x.id);
                    table.ForeignKey(
                        name: "fk_hiring_post_applications_hiring_posts_hiring_post_id",
                        column: x => x.hiring_post_id,
                        principalTable: "hiring_posts",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_hiring_post_applications_worker_profiles_worker_profile_id",
                        column: x => x.worker_profile_id,
                        principalTable: "worker_profiles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "ix_hiring_post_applications_hiring_post_id",
                table: "hiring_post_applications",
                column: "hiring_post_id");

            migrationBuilder.CreateIndex(
                name: "ix_hiring_post_applications_worker_profile_id",
                table: "hiring_post_applications",
                column: "worker_profile_id");

            migrationBuilder.CreateIndex(
                name: "ix_hiring_posts_business_owner_profile_id",
                table: "hiring_posts",
                column: "business_owner_profile_id");

            migrationBuilder.CreateIndex(
                name: "ix_hiring_posts_hiring_post_status",
                table: "hiring_posts",
                column: "hiring_post_status");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "hiring_post_applications");

            migrationBuilder.DropTable(
                name: "hiring_posts");
        }
    }
}
