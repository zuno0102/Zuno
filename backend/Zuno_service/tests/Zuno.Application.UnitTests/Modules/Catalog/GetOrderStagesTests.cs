using FluentAssertions;
using Moq;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Catalog.Queries.GetOrderStages;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Xunit;

namespace Zuno.Application.UnitTests.Modules.Catalog;

/// <summary>
/// The stage list the apps build their chips and filters from: names, colours and order as the
/// database holds them, so changing a row changes every app.
/// </summary>
public class GetOrderStagesTests
{
    private static OrderStageDefinition Row(OrderStage stage, string name, int order, bool onWork = true) => new()
    {
        Stage = stage,
        DisplayName = name,
        SortOrder = order,
        Tone = "success",
        ShowOnBookings = true,
        ShowOnWork = onWork,
    };

    [Fact]
    public async Task Handle_ReturnsEveryRowInSortOrder_WithItsStoredNameAndCode()
    {
        var db = new Mock<IApplicationDbContext>();
        db.Setup(d => d.OrderStages).Returns(TestDbSet.From(
            Row(OrderStage.Completed, "All done", 2),
            Row(OrderStage.Active, "New request", 1, onWork: false)));

        var stages = await new GetOrderStagesQueryHandler(db.Object).Handle(new GetOrderStagesQuery(), CancellationToken.None);

        stages.Select(s => s.Code).Should().Equal("Active", "Completed");
        // Whatever the row says, not a name built into the code.
        stages[0].Label.Should().Be("New request");
        stages[0].ShowOnWork.Should().BeFalse();
        stages[1].Label.Should().Be("All done");
    }
}
