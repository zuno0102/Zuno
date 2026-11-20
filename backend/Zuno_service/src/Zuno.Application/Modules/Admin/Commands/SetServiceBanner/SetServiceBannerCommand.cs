using MediatR;

namespace Zuno.Application.Modules.Admin.Commands.SetServiceBanner;

/// <summary>
/// Puts a service in the customers' top banner until <see cref="PaidUntil"/>, or takes it out (null).
/// </summary>
/// <remarks>
/// A banner is paid for. Until the business can pay in the app, a Super Admin records the payment
/// taken outside it here.
/// </remarks>
public record SetServiceBannerCommand(Guid ServiceId, DateTimeOffset? PaidUntil) : IRequest<ServiceBannerDto>;

/// <summary>A service and until when its banner runs; null for none.</summary>
public record ServiceBannerDto(Guid ServiceId, DateTimeOffset? BannerPaidUntil);
