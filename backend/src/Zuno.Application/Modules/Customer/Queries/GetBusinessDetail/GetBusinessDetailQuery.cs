using MediatR;
using Zuno.Application.Modules.Customer.DTOs;

namespace Zuno.Application.Modules.Customer.Queries.GetBusinessDetail;

public class GetBusinessDetailQuery : IRequest<BusinessDetailDto>
{
    public Guid BusinessId { get; set; }
}
