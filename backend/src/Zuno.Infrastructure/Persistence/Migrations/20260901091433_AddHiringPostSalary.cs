using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddHiringPostSalary : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "salary_amount",
                table: "hiring_posts",
                type: "numeric(10,2)",
                precision: 10,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<short>(
                name: "salary_unit",
                table: "hiring_posts",
                type: "smallint",
                nullable: false,
                defaultValue: (short)1);

            migrationBuilder.AddColumn<decimal>(
                name: "agreed_salary_amount",
                table: "hiring_post_applications",
                type: "numeric(10,2)",
                precision: 10,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<short>(
                name: "agreed_salary_unit",
                table: "hiring_post_applications",
                type: "smallint",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "hiring_post_salary_adjustments",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    hiring_post_application_id = table.Column<Guid>(type: "uuid", nullable: false),
                    previous_amount = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    new_amount = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    reason = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    created_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    created_by = table.Column<Guid>(type: "uuid", nullable: true),
                    modified_date = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    modified_by = table.Column<Guid>(type: "uuid", nullable: true),
                    is_deleted = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<short>(type: "smallint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_hiring_post_salary_adjustments", x => x.id);
                    table.ForeignKey(
                        name: "fk_hiring_post_salary_adjustments_hiring_post_applications_hir",
                        column: x => x.hiring_post_application_id,
                        principalTable: "hiring_post_applications",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_hiring_post_salary_adjustments_hiring_post_application_id",
                table: "hiring_post_salary_adjustments",
                column: "hiring_post_application_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "hiring_post_salary_adjustments");

            migrationBuilder.DropColumn(
                name: "salary_amount",
                table: "hiring_posts");

            migrationBuilder.DropColumn(
                name: "salary_unit",
                table: "hiring_posts");

            migrationBuilder.DropColumn(
                name: "agreed_salary_amount",
                table: "hiring_post_applications");

            migrationBuilder.DropColumn(
                name: "agreed_salary_unit",
                table: "hiring_post_applications");
        }
    }
}
