using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddHiringPostSubCategoryDropAuditorium : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "auditorium_name",
                table: "hiring_posts");

            migrationBuilder.AddColumn<Guid>(
                name: "service_sub_category_id",
                table: "hiring_posts",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "ix_hiring_posts_service_sub_category_id",
                table: "hiring_posts",
                column: "service_sub_category_id");

            migrationBuilder.AddForeignKey(
                name: "fk_hiring_posts_service_sub_categories_service_sub_category_id",
                table: "hiring_posts",
                column: "service_sub_category_id",
                principalTable: "service_sub_categories",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_hiring_posts_service_sub_categories_service_sub_category_id",
                table: "hiring_posts");

            migrationBuilder.DropIndex(
                name: "ix_hiring_posts_service_sub_category_id",
                table: "hiring_posts");

            migrationBuilder.DropColumn(
                name: "service_sub_category_id",
                table: "hiring_posts");

            migrationBuilder.AddColumn<string>(
                name: "auditorium_name",
                table: "hiring_posts",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);
        }
    }
}
