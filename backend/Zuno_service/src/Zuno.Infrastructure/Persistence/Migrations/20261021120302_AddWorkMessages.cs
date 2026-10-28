using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddWorkMessages : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "work_messages",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    business_owner_profile_id = table.Column<Guid>(type: "uuid", nullable: false),
                    worker_profile_id = table.Column<Guid>(type: "uuid", nullable: false),
                    sender_role = table.Column<short>(type: "smallint", nullable: false),
                    sender_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    body = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: false),
                    read_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_work_messages", x => x.id);
                    table.ForeignKey(
                        name: "fk_work_messages_business_owner_profiles_business_owner_profil",
                        column: x => x.business_owner_profile_id,
                        principalTable: "business_owner_profiles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_work_messages_worker_profiles_worker_profile_id",
                        column: x => x.worker_profile_id,
                        principalTable: "worker_profiles",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_work_messages_business_owner_profile_id_worker_profile_id_c",
                table: "work_messages",
                columns: new[] { "business_owner_profile_id", "worker_profile_id", "created_date" });

            migrationBuilder.CreateIndex(
                name: "ix_work_messages_worker_profile_id_created_date",
                table: "work_messages",
                columns: new[] { "worker_profile_id", "created_date" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "work_messages");
        }
    }
}
