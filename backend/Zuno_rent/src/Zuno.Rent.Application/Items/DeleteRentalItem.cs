using FluentValidation;
using MediatR;
using Zuno.Rent.Application.Common;

namespace Zuno.Rent.Application.Items;

/// <summary>Takes an item off the business's Rent list. The row is kept, marked deleted.</summary>
public class DeleteRentalItemCommand : IRequest
{
    public Guid Id { get; set; }
}

public class DeleteRentalItemCommandValidator : AbstractValidator<DeleteRentalItemCommand>
{
    public DeleteRentalItemCommandValidator()
    {
        RuleFor(x => x.Id).NotEmpty();
    }
}

public class DeleteRentalItemCommandHandler(ICurrentUser currentUser, IRentDbContext dbContext)
    : IRequestHandler<DeleteRentalItemCommand>
{
    public async Task Handle(DeleteRentalItemCommand request, CancellationToken cancellationToken)
    {
        var item = await dbContext.OwnedItemAsync(request.Id, currentUser.OwnerId(), cancellationToken);

        // Soft: saving marks it deleted rather than removing the row, so a later booking history can
        // still name the item. Its photos stay on disk for the same reason.
        dbContext.RentalItems.Remove(item);
        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
