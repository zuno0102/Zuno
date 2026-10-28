using MediatR;
using Zuno.Application.Modules.HiringPost.DTOs;

namespace Zuno.Application.Modules.HiringPost.Queries.GetMyPostJobs;

/// <summary>
/// Work this worker took through a hiring post — accepted, whatever date it falls on.
/// </summary>
/// <remarks>
/// A worker reaches paid work by two routes, and only one of them reached My jobs. That screen is
/// fed by <c>/worker/jobs</c>, which returns the customer bookings they were assigned to; a job they
/// took through a hiring post appeared on the dashboard and in the Find work feed and nowhere else.
/// So a worker could see "1 coming up" on their home page and open My jobs to find it empty.
///
/// Past dates are included: the half of this that belongs to history is as much a part of their
/// record as the half still ahead.
/// </remarks>
public record GetMyPostJobsQuery : IRequest<List<HiringPostDto>>;
