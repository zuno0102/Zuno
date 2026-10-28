using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddWorkerPhoto : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "photo_url",
                table: "worker_profiles",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "photo_url",
                table: "worker_profiles");
        }
    }
}
