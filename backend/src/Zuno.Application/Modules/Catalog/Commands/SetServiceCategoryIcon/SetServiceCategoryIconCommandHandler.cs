using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Catalog.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Catalog.Commands.SetServiceCategoryIcon;

public class SetServiceCategoryIconCommandHandler(
    IDateTimeProvider dateTimeProvider,
    IApplicationDbContext dbContext)
    : IRequestHandler<SetServiceCategoryIconCommand, AdminServiceCategoryDto>
{
    public async Task<AdminServiceCategoryDto> Handle(
        SetServiceCategoryIconCommand request,
        CancellationToken cancellationToken)
    {
        var category = await dbContext.ServiceCategories
            .Include(c => c.SubCategories)
            .FirstOrDefaultAsync(c => c.Id == request.Id, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(ServiceCategory), request.Id);

        category.IconUrl = request.IconUrl;
        category.ModifiedDate = dateTimeProvider.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);

        return category.ToAdminDto();
    }
}
