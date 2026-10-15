using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Business.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Business.Commands.SetBusinessServiceQuestions;

public class SetBusinessServiceQuestionsCommandHandler(
    ICurrentUserService currentUserService,
    IBusinessOwnerProfileRepository businessOwnerProfileRepository,
    IBusinessServiceRepository businessServiceRepository,
    IApplicationDbContext dbContext)
    : IRequestHandler<SetBusinessServiceQuestionsCommand, BusinessServiceDto>
{
    public async Task<BusinessServiceDto> Handle(
        SetBusinessServiceQuestionsCommand request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var businessProfile = await businessOwnerProfileRepository.GetByUserIdAsync(userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessOwnerProfile), userId);

        // Through the repository rather than a hand-rolled query: the response is a full service
        // DTO, which reads the category, media, districts and variants. Loading only what this
        // command writes saves the rows fine and then throws building the reply.
        var service = await businessServiceRepository.GetByIdAsync(request.ServiceId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(BusinessService), request.ServiceId);

        if (service.BusinessOwnerProfileId != businessProfile.Id)
        {
            throw new UnauthorizedAccessException("This service does not belong to your business.");
        }

        var incoming = request.Questions;
        var keptIds = incoming.Where(q => q.Id.HasValue).Select(q => q.Id!.Value).ToHashSet();

        // Dropped questions are soft-deleted (the save interceptor turns Deleted into a flag), so
        // they leave the booking form while every answer already given to them stays readable —
        // each answer carries its own copy of the wording.
        foreach (var removed in service.Questions.Where(q => !keptIds.Contains(q.Id)).ToList())
        {
            dbContext.BusinessServiceQuestions.Remove(removed);
            service.Questions.Remove(removed);
        }

        for (var position = 0; position < incoming.Count; position++)
        {
            var input = incoming[position];
            var prompt = input.Prompt.Trim();

            if (input.Id is { } id)
            {
                var existing = service.Questions.FirstOrDefault(q => q.Id == id)
                    ?? throw new EntityNotFoundException(nameof(BusinessServiceQuestion), id);

                // Edited in place, keeping its id, so the answers already pointing at it stay
                // pointed somewhere. Re-creating the row would orphan every one of them.
                existing.Prompt = prompt;
                existing.IsRequired = input.IsRequired;
                existing.SortOrder = (short)position;
                continue;
            }

            var question = new BusinessServiceQuestion
            {
                BusinessServiceId = service.Id,
                Prompt = prompt,
                IsRequired = input.IsRequired,
                SortOrder = (short)position,
            };

            // Added on the DbSet rather than only through the navigation collection. BaseEntity
            // fills in the Guid key before EF sees the object, so a child discovered by
            // navigation fixup on an already-tracked parent is taken for an existing row and
            // emitted as an UPDATE against a row that does not exist yet.
            dbContext.BusinessServiceQuestions.Add(question);
            service.Questions.Add(question);
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        return service.ToDto();
    }
}
