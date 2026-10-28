using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddBusinessServiceSubCategory : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "service_sub_category_id",
                table: "business_services",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "ix_business_services_service_sub_category_id",
                table: "business_services",
                column: "service_sub_category_id");

            migrationBuilder.AddForeignKey(
                name: "fk_business_services_service_sub_categories_service_sub_catego",
                table: "business_services",
                column: "service_sub_category_id",
                principalTable: "service_sub_categories",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_business_services_service_sub_categories_service_sub_catego",
                table: "business_services");

            migrationBuilder.DropIndex(
                name: "ix_business_services_service_sub_category_id",
                table: "business_services");

            migrationBuilder.DropColumn(
                name: "service_sub_category_id",
                table: "business_services");
        }
    }
}
