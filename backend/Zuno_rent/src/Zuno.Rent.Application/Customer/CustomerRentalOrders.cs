using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Items;
using Zuno.Rent.Application.Orders;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Enums;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.Application.Customer;

/// <summary>
/// A customer books pieces in the app — refused when the dates do not leave enough, the place is
/// outside the item's area, or a required question is unanswered. Their name and phone come from
/// their account, never from what the app sends.
/// </summary>
public class BookRentalCommand : IRequest<RentalOrderDto>
{
    public Guid RentalItemId { get; set; }

    public int Quantity { get; set; }

    public DateTimeOffset StartDate { get; set; }

    public DateTimeOffset EndDate { get; set; }

    public string DeliveryAddress { get; set; } = string.Empty;

    /// <summary>Where it goes — one of the districts the item is offered in.</summary>
    public Guid DistrictId { get; set; }

    public List<RentalAnswerInput> Answers { get; set; } = [];
}

public class RentalAnswerInput
{
    public Guid QuestionId { get; set; }

    public string Answer { get; set; } = string.Empty;
}

public class GetMyRentalsQuery : IRequest<RentalOrderPageDto>
{
    public int Page { get; set; } = 1;

    public int? PageSize { get; set; }
}

public class GetMyRentalQuery : IRequest<RentalOrderDto>
{
    public Guid Id { get; set; }
}

/// <summary>The customer cancels while the order is only booked — the step the transition table lets customers take.</summary>
public class CancelMyRentalCommand : IRequest<RentalOrderDto>
{
    public Guid Id { get; set; }
}

/// <summary>Refreshes how customers see this business — name, logo, verified — from its Service profile.</summary>
public class SyncRentalBusinessCommand : IRequest<RentalBusinessDto>;

public class RentalBusinessDto
{
    public string Name { get; set; } = string.Empty;

    public bool IsVerified { get; set; }
}

public class BookRentalCommandValidator : AbstractValidator<BookRentalCommand>
{
    public const int AnswerMaxLength = 1000;

    public BookRentalCommandValidator(IOptions<RentSettings> settings, TimeProvider clock)
    {
        RuleFor(x => x.RentalItemId).NotEmpty();
        RuleFor(x => x.Quantity)
            .GreaterThanOrEqualTo(1).WithMessage("Book at least one.")
            .LessThanOrEqualTo(settings.Value.MaxQuantityOwned);
        RentalOrderDates.Rules(this, x => x.StartDate, x => x.EndDate, clock);
        RuleFor(x => x.DeliveryAddress)
            .Must(address => !string.IsNullOrWhiteSpace(address)).WithMessage("Say where the pieces go.")
            .MaximumLength(500);
        RuleFor(x => x.DistrictId).NotEmpty().WithMessage("Choose the district it goes to.");
        RuleFor(x => x.Answers)
            .Must(answers => answers.Select(a => a.QuestionId).Distinct().Count() == answers.Count)
            .WithMessage("The same question was answered twice.");
        RuleForEach(x => x.Answers).ChildRules(answer =>
            answer.RuleFor(a => a.Answer).MaximumLength(AnswerMaxLength));
    }
}

public class CustomerRentalOrderHandlers(
    ICurrentUser currentUser,
    IRentDbContext dbContext,
    IServiceDirectory directory,
    IOptions<RentSettings> settings,
    TimeProvider clock) :
    IRequestHandler<BookRentalCommand, RentalOrderDto>,
    IRequestHandler<GetMyRentalsQuery, RentalOrderPageDto>,
    IRequestHandler<GetMyRentalQuery, RentalOrderDto>,
    IRequestHandler<CancelMyRentalCommand, RentalOrderDto>,
    IRequestHandler<SyncRentalBusinessCommand, RentalBusinessDto>
{
    public async Task<RentalOrderDto> Handle(BookRentalCommand request, CancellationToken cancellationToken)
    {
        var customerId = currentUser.OwnerId();

        var item = await dbContext.VisibleToCustomers()
            .AsNoTracking()
            .Include(i => i.Districts)
            .Include(i => i.Questions)
            .Include(i => i.RentalCategory)
            .Include(i => i.RentalSubCategory)
            .FirstOrDefaultAsync(i => i.Id == request.RentalItemId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(RentalItem), request.RentalItemId);

        if (item.OwnerUserId == customerId)
        {
            throw new DomainException("You cannot rent your own item.");
        }

        if (item.Districts.All(d => d.DistrictId != request.DistrictId))
        {
            throw new DomainException($"{item.Name} is not offered in that district. Choose one of its districts.");
        }

        // Every required question answered; answers only to this item's questions.
        var questions = item.Questions.Where(q => !q.IsDeleted).ToDictionary(q => q.Id);
        if (request.Answers.Any(a => !questions.ContainsKey(a.QuestionId)))
        {
            throw new DomainException("An answer was for a question this item does not ask.");
        }

        var answered = request.Answers.Where(a => !string.IsNullOrWhiteSpace(a.Answer)).ToDictionary(a => a.QuestionId);
        var missing = questions.Values.Where(q => q.IsRequired && !answered.ContainsKey(q.Id)).OrderBy(q => q.SortOrder).FirstOrDefault();
        if (missing is not null)
        {
            throw new DomainException($"Please answer: {missing.Prompt}");
        }

        // The name the business sees comes from the customer's own account.
        var person = await directory.GetCurrentPersonAsync(cancellationToken)
            ?? throw new DomainException("We could not read your profile just now. Try again in a moment.");

        var orderId = await dbContext.WithItemLockAsync(item.Id, async () =>
        {
            await dbContext.EnsureAvailableAsync(item, request.Quantity, request.StartDate, request.EndDate, cancellationToken);

            var order = new RentalOrder
            {
                RentalItemId = item.Id,
                OwnerUserId = item.OwnerUserId,
                CustomerUserId = customerId,
                CustomerName = person.Name,
                CustomerPhone = person.Phone,
                Quantity = request.Quantity,
                StartDate = request.StartDate.ToUniversalTime(),
                EndDate = request.EndDate.ToUniversalTime(),
                DeliveryAddress = request.DeliveryAddress.Trim(),
                DistrictId = request.DistrictId,
                Status = RentalOrderStatus.Booked,
                Source = RentalOrderSource.App,
            };
            order.PriceFrom(item.PriceType, item.Price);
            order.AdvanceDue = RentalCharge.Advance(item.AdvanceType, item.AdvanceAmount, order.Quantity, order.Amount);

            // The cancellation terms the customer agreed to, kept with the order.
            order.CancelSteps = item.CancelSteps
                .Select(s => new RentalCancelStep { UnitsBefore = s.UnitsBefore, Percent = s.Percent })
                .ToList();
            order.CancelChargeType = item.CancelChargeType;
            order.CancelPercentPerDay = item.CancelPercentPerDay;
            // The limit as it stands now: a per-day charge on a long rental never adds up past it.
            order.CancelPercentCap = RentalCancelLimits.For(item.RentalCategory, item.RentalSubCategory, settings.Value);
            if (order.AdvanceDue > 0)
            {
                order.Status = RentalOrderStatus.AwaitingAdvance;
                order.HoldUntil = clock.GetUtcNow().AddMinutes(settings.Value.AdvanceHoldMinutes);
            }

            dbContext.RentalOrders.Add(order);

            foreach (var answer in answered.Values.OrderBy(a => questions[a.QuestionId].SortOrder))
            {
                dbContext.RentalOrderAnswers.Add(new RentalOrderAnswer
                {
                    RentalOrderId = order.Id,
                    QuestionId = answer.QuestionId,
                    Prompt = questions[answer.QuestionId].Prompt,
                    Answer = answer.Answer.Trim(),
                });
            }

            RentalOrderHistory.Record(dbContext, order.Id, RentalOrderEventKind.BookedByCustomer, order.Quantity, customerId);
            await dbContext.SaveChangesAsync(cancellationToken);
            return order.Id;
        }, cancellationToken);

        return await RentalOrderReader.ReadOneAsync(dbContext, orderId, customerId, cancellationToken, RentalAudience.Customer);
    }

    public async Task<RentalOrderPageDto> Handle(GetMyRentalsQuery request, CancellationToken cancellationToken)
    {
        var limits = settings.Value;
        return await RentalOrderReader.ReadPageAsync(
            dbContext,
            dbContext.OrdersOf(currentUser.OwnerId(), RentalAudience.Customer),
            Math.Max(1, request.Page),
            Math.Clamp(request.PageSize ?? limits.DefaultPageSize, 1, limits.MaxPageSize),
            cancellationToken,
            RentalAudience.Customer);
    }

    public Task<RentalOrderDto> Handle(GetMyRentalQuery request, CancellationToken cancellationToken) =>
        RentalOrderReader.ReadOneAsync(dbContext, request.Id, currentUser.OwnerId(), cancellationToken, RentalAudience.Customer);

    public Task<RentalOrderDto> Handle(CancelMyRentalCommand request, CancellationToken cancellationToken) =>
        ChangeRentalOrderStatusCommandHandler.TakeStepAsync(
            dbContext, clock, request.Id, RentalOrderStatus.Cancelled, currentUser.OwnerId(), RentalAudience.Customer, cancellationToken);

    public async Task<RentalBusinessDto> Handle(SyncRentalBusinessCommand request, CancellationToken cancellationToken)
    {
        var ownerId = currentUser.OwnerId();
        var profile = await directory.GetCurrentBusinessAsync(cancellationToken);

        var row = await dbContext.RentalBusinesses.FirstOrDefaultAsync(b => b.OwnerUserId == ownerId, cancellationToken);
        if (profile is null)
        {
            // Service could not be asked: keep what was known, rather than hiding the business's items.
            return new RentalBusinessDto { Name = row?.Name ?? string.Empty, IsVerified = row?.IsVerified ?? false };
        }

        if (row is null)
        {
            row = new RentalBusiness { OwnerUserId = ownerId };
            dbContext.RentalBusinesses.Add(row);
        }

        row.Name = profile.Name;
        row.LogoUrl = profile.LogoUrl;
        row.IsVerified = profile.IsVerified;
        row.RefreshedAt = clock.GetUtcNow();
        await dbContext.SaveChangesAsync(cancellationToken);

        return new RentalBusinessDto { Name = row.Name, IsVerified = row.IsVerified };
    }
}
