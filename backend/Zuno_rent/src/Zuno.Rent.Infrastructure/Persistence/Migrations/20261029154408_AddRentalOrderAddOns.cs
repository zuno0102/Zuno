using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Zuno.Rent.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddRentalOrderAddOns : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<Guid>(
                name: "customer_user_id",
                table: "rental_orders",
                type: "uuid",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AddColumn<Guid>(
                name: "parent_order_id",
                table: "rental_orders",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "ix_rental_orders_parent_order_id",
                table: "rental_orders",
                column: "parent_order_id");

            migrationBuilder.AddForeignKey(
                name: "fk_rental_orders_rental_orders_parent_order_id",
                table: "rental_orders",
                column: "parent_order_id",
                principalTable: "rental_orders",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "fk_rental_orders_rental_orders_parent_order_id",
                table: "rental_orders");

            migrationBuilder.DropIndex(
                name: "ix_rental_orders_parent_order_id",
                table: "rental_orders");

            migrationBuilder.DropColumn(
                name: "parent_order_id",
                table: "rental_orders");

            migrationBuilder.AlterColumn<Guid>(
                name: "customer_user_id",
                table: "rental_orders",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);
        }
    }
}
