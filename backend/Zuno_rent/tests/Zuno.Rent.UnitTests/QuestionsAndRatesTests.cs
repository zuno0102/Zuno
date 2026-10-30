using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Zuno.Rent.Application.Categories;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Domain.Enums;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.UnitTests;

/// <summary>The questions a business asks per item, and the rate types read from their table.</summary>
public class QuestionsAndRatesTests : IDisposable
{
    private readonly TestRent _rent = new();

    public void Dispose() => _rent.Dispose();

    private static RentalQuestionInput Ask(string prompt, bool required = false, Guid? id = null) =>
        new() { Id = id, Prompt = prompt, IsRequired = required };

    [Fact]
    public async Task Rate_types_come_from_the_table_in_display_order()
    {
        var handler = new GetRentalPriceTypesQueryHandler(_rent.Db, new MemoryCache(new MemoryCacheOptions()), _rent.Settings);

        var types = await handler.Handle(new GetRentalPriceTypesQuery(), default);

        types.Select(t => (t.Code, t.Name, t.UnitSuffix)).Should().Equal(
            ("Daily", "Per day", "/day"),
            ("Fixed", "Per item", "/item"),
            ("Hourly", "Per hour", "/hr"));
        types.Should().OnlyContain(t => t.Detail.Length > 0);
    }

    [Fact]
    public async Task A_rate_type_switched_off_in_the_table_is_hidden_and_refused()
    {
        var hourly = await _rent.Db.RentalPriceTypes.SingleAsync(p => p.Code == RentalPriceType.Hourly);
        hourly.IsActive = false;
        await _rent.Db.SaveChangesAsync();

        var handler = new GetRentalPriceTypesQueryHandler(_rent.Db, new MemoryCache(new MemoryCacheOptions()), _rent.Settings);
        (await handler.Handle(new GetRentalPriceTypesQuery(), default)).Select(t => t.Code).Should().Equal("Daily", "Fixed");

        var result = await Validate(TestRent.Machine(c => c.PriceType = "Hourly"));
        result.Errors.Should().ContainSingle(e => e.PropertyName == "PriceType");
    }

    [Theory]
    [InlineData("Daily")]
    [InlineData("Fixed")]
    [InlineData("Hourly")]
    public async Task Every_offered_rate_type_passes(string priceType)
    {
        (await Validate(TestRent.Machine(c => c.PriceType = priceType))).IsValid.Should().BeTrue();
    }

    [Fact]
    public async Task Create_saves_questions_trimmed_and_in_order()
    {
        var dto = await _rent.SaveHandlers.Handle(
            TestRent.Machine(c => c.Questions = [Ask("  Event date and venue ", required: true), Ask("Floor type")]),
            default);

        dto.Questions.Select(q => (q.Prompt, q.IsRequired)).Should().Equal(
            ("Event date and venue", true),
            ("Floor type", false));
    }

    [Fact]
    public async Task Update_edits_in_place_reorders_adds_and_soft_deletes()
    {
        var created = await _rent.SaveHandlers.Handle(
            TestRent.Machine(c => c.Questions = [Ask("Event date"), Ask("Floor type"), Ask("Delivery needed?")]),
            default);
        var date = created.Questions[0].Id;
        var floor = created.Questions[1].Id;
        _rent.Db.ChangeTracker.Clear();

        var updated = await _rent.SaveHandlers.Handle(
            TestRent.Edit(created.Id, c => c.Questions =
            [
                Ask("Floor type (tiles or marble)", required: true, id: floor),
                Ask("Event date", id: date),
                Ask("How many days?"),
            ]),
            default);

        updated.Questions.Select(q => q.Prompt).Should().Equal("Floor type (tiles or marble)", "Event date", "How many days?");
        updated.Questions[0].Id.Should().Be(floor, "an edited question keeps its id so its answers stay linked");
        updated.Questions[0].IsRequired.Should().BeTrue();

        var dropped = await _rent.Db.RentalItemQuestions.IgnoreQueryFilters().SingleAsync(q => q.Prompt == "Delivery needed?");
        dropped.IsDeleted.Should().BeTrue("a dropped question is kept, marked deleted");
    }

    [Fact]
    public async Task An_empty_list_clears_the_questions()
    {
        var created = await _rent.SaveHandlers.Handle(TestRent.Machine(c => c.Questions = [Ask("Event date")]), default);
        _rent.Db.ChangeTracker.Clear();

        var updated = await _rent.SaveHandlers.Handle(TestRent.Edit(created.Id, c => c.Questions = []), default);

        updated.Questions.Should().BeEmpty();
    }

    [Fact]
    public async Task A_question_id_from_another_item_is_refused()
    {
        var other = await _rent.SaveHandlers.Handle(TestRent.Machine(c => c.Questions = [Ask("Theirs")]), default);
        var mine = await _rent.SaveHandlers.Handle(TestRent.Machine(), default);
        _rent.Db.ChangeTracker.Clear();

        var act = () => _rent.SaveHandlers.Handle(
            TestRent.Edit(mine.Id, c => c.Questions = [Ask("Taken over", id: other.Questions[0].Id)]),
            default);

        await act.Should().ThrowAsync<EntityNotFoundException>();
        (await _rent.Db.RentalItemQuestions.SingleAsync(q => q.Id == other.Questions[0].Id)).Prompt.Should().Be("Theirs");
    }

    public static TheoryData<Action<CreateRentalItemCommand>> BadQuestions => new()
    {
        c => c.Questions = [Ask("   ")],
        c => c.Questions = [Ask(new string('x', 201))],
        c => c.Questions = Enumerable.Range(1, 16).Select(i => Ask($"Question {i}")).ToList(),
        c => { var id = Guid.NewGuid(); c.Questions = [Ask("One", id: id), Ask("Two", id: id)]; },
        c => c.Questions = null!,
    };

    [Theory]
    [MemberData(nameof(BadQuestions))]
    public async Task Bad_questions_are_refused(Action<CreateRentalItemCommand> breakIt)
    {
        var result = await Validate(TestRent.Machine(breakIt));

        result.Errors.Should().Contain(e => e.PropertyName.StartsWith("Questions"));
    }

    [Fact]
    public async Task Fifteen_questions_of_200_characters_are_allowed()
    {
        var result = await Validate(TestRent.Machine(c =>
            c.Questions = Enumerable.Range(1, 15).Select(_ => Ask(new string('x', 200))).ToList()));

        result.IsValid.Should().BeTrue(string.Join("; ", result.Errors));
    }

    private Task<FluentValidation.Results.ValidationResult> Validate(CreateRentalItemCommand command) =>
        new CreateRentalItemCommandValidator(_rent.Db, _rent.Settings).ValidateAsync(command);
}
