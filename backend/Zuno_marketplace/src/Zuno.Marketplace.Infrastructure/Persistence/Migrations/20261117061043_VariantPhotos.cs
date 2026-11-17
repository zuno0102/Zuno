using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Marketplace.Infrastructure.Persistence.Migrations
{
    /// <summary>
    /// A colour / size can have photos of its own — the saree in that colour. They are post photos
    /// tagged with the colour / size; the post's own photos have none. Photos already saved are the
    /// post's.
    /// </summary>
    public partial class VariantPhotos : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "variant_id",
                table: "marketplace_post_media",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "ix_marketplace_post_media_variant_id",
                table: "marketplace_post_media",
                column: "variant_id");

            migrationBuilder.AddForeignKey(
                name: "fk_marketplace_post_media_post_variants_variant_id",
                table: "marketplace_post_media",
                column: "variant_id",
                principalTable: "marketplace_post_variants",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Without the column a colour's photo would turn into one of the post's: they go first.
            migrationBuilder.Sql("DELETE FROM marketplace_post_media WHERE variant_id IS NOT NULL;");

            migrationBuilder.DropForeignKey(
                name: "fk_marketplace_post_media_post_variants_variant_id",
                table: "marketplace_post_media");

            migrationBuilder.DropIndex(
                name: "ix_marketplace_post_media_variant_id",
                table: "marketplace_post_media");

            migrationBuilder.DropColumn(
                name: "variant_id",
                table: "marketplace_post_media");
        }
    }
}
