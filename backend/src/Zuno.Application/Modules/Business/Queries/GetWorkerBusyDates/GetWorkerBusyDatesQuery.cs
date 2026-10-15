using MediatR;
using Zuno.Application.Modules.Business.DTOs;

namespace Zuno.Application.Modules.Business.Queries.GetWorkerBusyDates;

/// <summary>
/// One worker's diary as the business needs to read it: every job holding them, with real start
/// and end times.
/// </summary>
/// <remarks>
/// Replaced a version returning bare distinct <c>ScheduledDate</c> values. That shape could not
/// answer the two questions actually asked of it — two jobs on one day collapsed to one entry
/// when they happened to start at the same minute, and jobs taken through a hiring post were
/// missing altogether.
/// </remarks>
public class GetWorkerBusyDatesQuery : IRequest<List<WorkerBusyPeriodDto>>
{
    public Guid WorkerProfileId { get; set; }
}
