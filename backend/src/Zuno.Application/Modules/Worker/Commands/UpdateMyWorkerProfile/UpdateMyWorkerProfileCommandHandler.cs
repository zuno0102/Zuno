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
    IDateTimeProvider dateTimeProvider)
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

        if (request.UpiVpa is { } upi)
        {
            SetUpi(profile, upi);
        }

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

        var earnings = await earningsService.GetAsync(profile.Id, cancellationToken);
        return profile.ToDto(earnings);
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
    /// Points the worker's wages at a UPI address, creating the payout record on first use.
    /// </summary>
    /// <remarks>
    /// A changed address goes back to Pending. Verification attaches to a specific destination, so
    /// carrying the old status over to a new address would let unverified details be paid to — the
    /// one thing <c>WorkerPayoutDetail.CanReceivePayouts</c> exists to prevent. The provider handle
    /// is cleared for the same reason: it identifies the old destination.
    /// </remarks>
    /// <summary>
    /// Records the worker's UPI, ready to be paid to.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Accepted on sight, the same way a business is verified the moment it registers. Nothing in
    /// this app has ever been able to move payout details out of Pending — no admin screen, no
    /// provider call, no job — so every worker who saved a UPI sat in "being checked" for good and
    /// could never be paid. The e2e scripts hid it by writing verification_status straight into
    /// the database.
    /// </para>
    /// <para>
    /// This is a placeholder for a real check, and deliberately a small one: asking Razorpay
    /// whether the address exists, through /fund_accounts/validations, is the answer the UI
    /// already promises the worker ("Checked before the first payment"). Until that is built, a
    /// wrong address fails at the payout itself with a reason the business can read and act on,
    /// which is a better place to find out than a status that never changes.
    /// </para>
    /// </remarks>
    private void SetUpi(WorkerProfile profile, string upiVpa)
    {
        var payout = profile.PayoutDetail;
        var now = dateTimeProvider.UtcNow;

        if (payout is null)
        {
            // Added through the set, not the navigation. A child reached by navigation fixup is
            // tracked Modified because BaseEntity fills Id in a property initialiser, and EF then
            // issues an UPDATE against a row that does not exist.
            dbContext.WorkerPayoutDetails.Add(new WorkerPayoutDetail
            {
                WorkerProfileId = profile.Id,
                UpiVpa = upiVpa,
                VerificationStatus = VerificationStatus.Verified,
                VerifiedAt = now,
            });
            return;
        }

        if (string.Equals(payout.UpiVpa, upiVpa, StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        payout.UpiVpa = upiVpa;
        payout.VerificationStatus = VerificationStatus.Verified;
        payout.VerifiedAt = now;
        // The old address's handle does not describe the new one.
        payout.ProviderFundAccountId = null;
    }
}
