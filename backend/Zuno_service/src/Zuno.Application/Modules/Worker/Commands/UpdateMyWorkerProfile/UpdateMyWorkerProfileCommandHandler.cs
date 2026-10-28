using MediatR;
using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Modules.Worker.DTOs;
using Zuno.Domain.Entities;
using Zuno.Domain.Enums;
using Zuno.Domain.Exceptions;

namespace Zuno.Application.Modules.Worker.Commands.UpdateMyWorkerProfile;

public class UpdateMyWorkerProfileCommandHandler(
    ICurrentUserService currentUserService,
    IUserRepository userRepository,
    IWorkerEarningsService earningsService,
    IApplicationDbContext dbContext,
    IDateTimeProvider dateTimeProvider,
    IPlatformSettings platformSettings,
    IPayoutDestinationCheck payoutCheck,
    INotificationSender notifications)
    : IRequestHandler<UpdateMyWorkerProfileCommand, WorkerProfileDto>
{
    public async Task<WorkerProfileDto> Handle(
        UpdateMyWorkerProfileCommand request,
        CancellationToken cancellationToken)
    {
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var profile = await dbContext.WorkerProfiles
            .Include(w => w.User)
            .Include(w => w.PayoutDetail)
            .FirstOrDefaultAsync(w => w.UserId == userId, cancellationToken)
            ?? throw new EntityNotFoundException(nameof(WorkerProfile), userId);

        // Trimmed, because a trailing space is invisible on screen and turns one worker into two
        // different-looking names across the crew lists they appear on.
        if (request.FirstName is { } firstName)
        {
            profile.User.FirstName = firstName.Trim();
        }

        if (request.LastName is { } lastName)
        {
            profile.User.LastName = lastName.Trim();
        }

        if (request.PhoneNumber is { } phone)
        {
            await SetPhoneNumberAsync(profile.User, phone, cancellationToken);
        }

        var upiChanged = request.UpiVpa is { } upi && await SetUpiAsync(profile, upi, cancellationToken);

        // Assigned only when sent. A form that posts back four fields of which the worker touched
        // one must not blank the other three.
        if (request.HourlyRate is { } rate)
        {
            profile.HourlyRate = rate;
        }

        if (request.ExperienceYears is { } years)
        {
            profile.ExperienceYears = years;
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        if (upiChanged)
        {
            // So the worker hears of it if it was not them: a changed UPI is where their next wages go.
            await notifications.NotifyAsync(
                userId,
                NotificationKind.PayoutDestinationChanged,
                "Your payout UPI was changed",
                $"Wages will now go to {Mask(request.UpiVpa!)}. If you did not change it, change your password now.",
                NotificationTarget.Profile,
                Guid.Empty,
                cancellationToken);
        }

        var earnings = await earningsService.GetAsync(profile.Id, cancellationToken);
        return profile.ToDto(earnings, platformSettings.Current.WorkerLevels);
    }

    /// <summary>
    /// Takes the number, refusing one that belongs to somebody else.
    /// </summary>
    /// <remarks>
    /// <c>users.phone_number</c> carries a filtered unique index, so without this check a worker
    /// typing a number that already exists would get a 500 out of the database rather than being
    /// told what was wrong. Re-saving the number they already have is a no-op rather than a clash.
    /// </remarks>
    private async Task SetPhoneNumberAsync(
        User user,
        string phoneNumber,
        CancellationToken cancellationToken)
    {
        if (string.Equals(user.PhoneNumber, phoneNumber, StringComparison.Ordinal))
        {
            return;
        }

        var owner = await userRepository.GetByPhoneNumberAsync(phoneNumber, cancellationToken);
        if (owner is not null && owner.Id != user.Id)
        {
            throw new DomainException("Another account already uses that phone number.");
        }

        user.PhoneNumber = phoneNumber;

        // Back to unconfirmed: nobody has proved this new number is reachable, and leaving the old
        // confirmation in place would claim otherwise.
        user.PhoneNumberConfirmed = false;
    }

    /// <summary>
    /// Points the worker's wages at a UPI address, creating the payout record on first use. Returns
    /// whether the address actually changed.
    /// </summary>
    /// <remarks>
    /// A new or changed address is verified again through <see cref="IPayoutDestinationCheck"/> before
    /// it can be paid: verification belongs to one destination, and carrying the old status over to a
    /// new address would let unchecked details be paid to — the one thing
    /// <c>WorkerPayoutDetail.CanReceivePayouts</c> exists to prevent. Until it passes, a pay run
    /// leaves the worker out and tells the business why. An unchanged address is not re-checked. The
    /// provider handle is cleared on any change: it identifies the old destination.
    /// </remarks>
    private async Task<bool> SetUpiAsync(WorkerProfile profile, string upiVpa, CancellationToken cancellationToken)
    {
        var payout = profile.PayoutDetail;
        if (payout is not null && string.Equals(payout.UpiVpa, upiVpa, StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var check = await payoutCheck.CheckUpiAsync(upiVpa, cancellationToken);
        var status = check.IsVerified ? VerificationStatus.Verified : VerificationStatus.Pending;
        DateTimeOffset? verifiedAt = check.IsVerified ? dateTimeProvider.UtcNow : null;

        if (payout is null)
        {
            // Added through the set, not the navigation. A child reached by navigation fixup is
            // tracked Modified because BaseEntity fills Id in a property initialiser, and EF then
            // issues an UPDATE against a row that does not exist.
            dbContext.WorkerPayoutDetails.Add(new WorkerPayoutDetail
            {
                WorkerProfileId = profile.Id,
                UpiVpa = upiVpa,
                VerificationStatus = status,
                VerifiedAt = verifiedAt,
            });
            return true;
        }

        payout.UpiVpa = upiVpa;
        payout.VerificationStatus = status;
        payout.VerifiedAt = verifiedAt;
        payout.ProviderFundAccountId = null;
        return true;
    }

    /// <summary>"ravi@okaxis" → "ra***@okaxis": enough to recognise, not enough to copy.</summary>
    private static string Mask(string upiVpa)
    {
        var at = upiVpa.IndexOf('@');
        return at <= 0 ? "***" : upiVpa[..Math.Min(2, at)] + "***" + upiVpa[at..];
    }
}
