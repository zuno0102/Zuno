using MediatR;
using Zuno.Application.Modules.Admin.DTOs;

namespace Zuno.Application.Modules.Admin.Queries.GetBusinessesForReview;

/// <param name="Status">Pending, Verified or Rejected. Null returns every business.</param>
public record GetBusinessesForReviewQuery(string? Status = null)
    : IRequest<List<BusinessReviewDto>>;
