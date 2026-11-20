using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Zuno.Api.Authorization;
using Zuno.Application.Modules.BusinessPlans;
using Zuno.Domain.Enums;

namespace Zuno.Api.Controllers;

/// <summary>The business's plan: Basic or paid, what it uses in each area, and buying a plan.</summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/business/plan")]
[Authorize(Policy = AuthorizationPolicyNames.RequireBusinessOwnerRole)]
public class BusinessPlanController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetMyBusinessPlanQuery(), cancellationToken));

    /// <summary>Starts buying a plan; answers the Razorpay order to pay.</summary>
    [HttpPost("purchase")]
    public async Task<IActionResult> Purchase([FromBody] PurchaseRequest request, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new StartPlanPurchaseCommand(request.PlanId), cancellationToken));

    /// <summary>Confirms the payment with Razorpay's signature; the plan then runs.</summary>
    [HttpPost("purchase/{id:guid}/confirm")]
    public async Task<IActionResult> Confirm(Guid id, [FromBody] ConfirmRequest request, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new ConfirmPlanPurchaseCommand(id, request.ProviderPaymentId, request.Signature), cancellationToken));

    /// <summary>Asked by the Rent and Marketplace APIs, with the business's own sign-in, before a listing goes live.</summary>
    [HttpPost("can-add")]
    public async Task<IActionResult> CanAdd([FromBody] CanAddRequest request, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new CheckListingAllowanceQuery(request.Area, request.LiveHere), cancellationToken));

    public record PurchaseRequest(Guid PlanId);

    public record ConfirmRequest(string? ProviderPaymentId, string? Signature);

    public record CanAddRequest(ListingArea Area, int LiveHere);
}

/// <summary>Super Admin: every price — business plans and full-time hiring post options.</summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/admin/pricing")]
[Authorize(Policy = AuthorizationPolicyNames.RequireSuperAdminRole)]
public class AdminPricingController(ISender mediator) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken cancellationToken) =>
        Ok(await mediator.Send(new GetPricingQuery(), cancellationToken));

    [HttpPut("plans/{id:guid}")]
    public async Task<IActionResult> UpdatePlan(Guid id, [FromBody] PlanRequest request, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(
            new UpdatePlanCommand(id, request.Name, request.Price, request.DurationDays, request.MaxLiveListings, request.IsActive, request.SortOrder),
            cancellationToken));

    [HttpPost("hiring-plans")]
    public async Task<IActionResult> AddHiringPlan([FromBody] HiringPlanRequest request, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(
            new SaveHiringPlanCommand(null, request.Name, request.Amount, request.ListingDays, request.IsActive, request.SortOrder),
            cancellationToken));

    [HttpPut("hiring-plans/{id:guid}")]
    public async Task<IActionResult> UpdateHiringPlan(Guid id, [FromBody] HiringPlanRequest request, CancellationToken cancellationToken) =>
        Ok(await mediator.Send(
            new SaveHiringPlanCommand(id, request.Name, request.Amount, request.ListingDays, request.IsActive, request.SortOrder),
            cancellationToken));

    public record PlanRequest(string Name, decimal Price, int? DurationDays, int? MaxLiveListings, bool IsActive, short SortOrder);

    public record HiringPlanRequest(string Name, decimal Amount, int ListingDays, bool IsActive, short SortOrder);
}
