using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddVariantMediaSlots : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "image_url",
                table: "business_service_variants");

            migrationBuilder.AlterColumn<Guid>(
                name: "business_service_id",
                table: "business_service_media",
                type: "uuid",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AddColumn<Guid>(
                name: "business_service_variant_id",
                table: "business_service_media",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "ix_business_service_media_business_service_variant_id",
                table: "business_service_media",
                column: "business_service_variant_id");

            migrationBuilder.AddCheckConstraint(
                name: "ck_business_service_media_owner",
                table: "business_service_media",
                sql: "num_nonnulls(business_service_id, business_service_variant_id) = 1");

            migrationBuilder.AddForeignKey(
                name: "fk_business_service_media_business_service_variants_business_s",
                table: "business_service_media",
                column: "business_service_variant_id",
                principalTable: "business_service_variants",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_business_service_media_business_service_variants_business_s",
                table: "business_service_media");

            migrationBuilder.DropIndex(
                name: "ix_business_service_media_business_service_variant_id",
                table: "business_service_media");

            migrationBuilder.DropCheckConstraint(
                name: "ck_business_service_media_owner",
                table: "business_service_media");

            migrationBuilder.DropColumn(
                name: "business_service_variant_id",
                table: "business_service_media");

            migrationBuilder.AddColumn<string>(
                name: "image_url",
                table: "business_service_variants",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AlterColumn<Guid>(
                name: "business_service_id",
                table: "business_service_media",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);
        }
    }
}
