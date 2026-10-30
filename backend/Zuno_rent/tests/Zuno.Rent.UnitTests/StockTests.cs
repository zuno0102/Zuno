using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.UnitTests;

/// <summary>The Stock page's quick change: quantity and availability, nothing else.</summary>
public class StockTests : IDisposable
{
    private readonly TestRent _rent = new();

    public void Dispose() => _rent.Dispose();

    private UpdateRentalStockCommandHandler Handler => new(_rent.User, _rent.Db);

    private async Task<RentalItemDto> ChairsAsync()
    {
        var created = await _rent.SaveHandlers.Handle(
            TestRent.Machine(c =>
            {
                c.Name = "Plastic chair";
                c.PriceType = "Fixed";
                c.Price = 12;
                c.QuantityOwned = 1000;
                c.Questions = [new RentalQuestionInput { Prompt = "Event date", IsRequired = true }];
            }),
            default);
        _rent.Db.ChangeTracker.Clear();
        return created;
    }

    [Fact]
    public async Task Changes_quantity_and_availability_and_nothing_else()
    {
        var chairs = await ChairsAsync();

        var updated = await Handler.Handle(
            new UpdateRentalStockCommand { Id = chairs.Id, QuantityOwned = 1050, IsAvailable = false }, default);

        updated.QuantityOwned.Should().Be(1050);
        updated.IsAvailable.Should().BeFalse();
        updated.Should().BeEquivalentTo(
            chairs,
            o => o.Excluding(i => i.QuantityOwned).Excluding(i => i.IsAvailable),
            "the rate, category, districts and questions stay as saved");
    }

    [Fact]
    public async Task The_summary_follows_the_change()
    {
        var chairs = await ChairsAsync();

        await Handler.Handle(new UpdateRentalStockCommand { Id = chairs.Id, QuantityOwned = 1200, IsAvailable = true }, default);

        (await new GetMyRentalSummaryQueryHandler(_rent.User, _rent.Db).Handle(new GetMyRentalSummaryQuery(), default))
            .UnitsAvailable.Should().Be(1200);
    }

    [Fact]
    public async Task Another_business_is_refused_and_nothing_changes()
    {
        var chairs = await ChairsAsync();
        _rent.As(TestRent.OwnerB);

        var act = () => Handler.Handle(new UpdateRentalStockCommand { Id = chairs.Id, QuantityOwned = 1, IsAvailable = true }, default);

        await act.Should().ThrowAsync<ForbiddenException>();
        (await _rent.Db.RentalItems.SingleAsync()).QuantityOwned.Should().Be(1000);
    }

    [Fact]
    public async Task An_unknown_or_removed_item_is_not_found()
    {
        var chairs = await ChairsAsync();
        await new DeleteRentalItemCommandHandler(_rent.User, _rent.Db).Handle(new DeleteRentalItemCommand { Id = chairs.Id }, default);
        _rent.Db.ChangeTracker.Clear();

        foreach (var id in new[] { chairs.Id, Guid.NewGuid() })
        {
            var act = () => Handler.Handle(new UpdateRentalStockCommand { Id = id, QuantityOwned = 5, IsAvailable = true }, default);
            await act.Should().ThrowAsync<EntityNotFoundException>();
        }
    }

    [Theory]
    [InlineData(0, false)]
    [InlineData(1, true)]
    [InlineData(100_000, true)]
    [InlineData(100_001, false)]
    public async Task Quantity_limits(int quantity, bool valid)
    {
        var result = await new UpdateRentalStockCommandValidator(_rent.Settings)
            .ValidateAsync(new UpdateRentalStockCommand { Id = Guid.NewGuid(), QuantityOwned = quantity, IsAvailable = true });

        result.IsValid.Should().Be(valid);
    }
}
