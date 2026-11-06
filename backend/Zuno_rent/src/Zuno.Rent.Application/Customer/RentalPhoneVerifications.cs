using System.Security.Cryptography;
using System.Text;
using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Zuno.Rent.Application.Common;
using Zuno.Rent.Application.Orders;
using Zuno.Rent.Domain.Entities;
using Zuno.Rent.Domain.Exceptions;

namespace Zuno.Rent.Application.Customer;

/// <summary>Sends a one-time code to the customer's mobile, so they can book rent items with it.</summary>
public class SendRentalPhoneCodeCommand : IRequest<RentalPhoneCodeSentDto>
{
    public string Phone { get; set; } = string.Empty;
}

/// <summary>Checks the code the customer typed; right, and the number is theirs for every later booking.</summary>
public class VerifyRentalPhoneCodeCommand : IRequest<RentalPhoneDto>
{
    public string Phone { get; set; } = string.Empty;

    public string Code { get; set; } = string.Empty;
}

/// <summary>The customer's most recently verified mobile, for the booking form to start with.</summary>
public class GetRentalPhoneQuery : IRequest<RentalPhoneDto>;

public class RentalPhoneCodeSentDto
{
    public string Phone { get; set; } = string.Empty;

    /// <summary>The number was already verified: no code was sent, and none is needed.</summary>
    public bool AlreadyVerified { get; set; }

    public int ExpiresInSeconds { get; set; }

    public int ResendInSeconds { get; set; }

    /// <summary>The code itself — only while no SMS is really sent, so it can be tried in the app.</summary>
    public string? TestCode { get; set; }
}

public class RentalPhoneDto
{
    /// <summary>The verified 10 digits; null when the customer has none yet.</summary>
    public string? Phone { get; set; }

    public bool IsVerified { get; set; }
}

/// <summary>The customer's wording for the mobile rules; the business's offline order has its own.</summary>
public static class RentalPhoneMessages
{
    public const string Missing = "Enter your mobile number. If there is no mobile box, update the Zuno app.";

    public const string NotVerified = "Verify your mobile number with the code we send before booking.";
}

public class SendRentalPhoneCodeCommandValidator : AbstractValidator<SendRentalPhoneCodeCommand>
{
    public SendRentalPhoneCodeCommandValidator()
    {
        RuleFor(x => x.Phone).Cascade(CascadeMode.Stop)
            .Must(phone => !string.IsNullOrWhiteSpace(phone)).WithMessage(RentalPhoneMessages.Missing)
            .Must(phone => RentalPhone.Normalize(phone) is not null).WithMessage(RentalPhone.Hint);
    }
}

public class VerifyRentalPhoneCodeCommandValidator : AbstractValidator<VerifyRentalPhoneCodeCommand>
{
    public VerifyRentalPhoneCodeCommandValidator()
    {
        RuleFor(x => x.Phone)
            .Must(phone => RentalPhone.Normalize(phone) is not null).WithMessage(RentalPhone.Hint);
        RuleFor(x => x.Code)
            .Must(code => !string.IsNullOrWhiteSpace(code) && code.Trim().All(char.IsAsciiDigit))
            .WithMessage("Enter the code we sent.");
    }
}

public class RentalPhoneVerificationHandlers(
    ICurrentUser currentUser,
    IRentDbContext dbContext,
    IPhoneOtpSender sender,
    IOptions<PhoneOtpSettings> settings,
    TimeProvider clock) :
    IRequestHandler<SendRentalPhoneCodeCommand, RentalPhoneCodeSentDto>,
    IRequestHandler<VerifyRentalPhoneCodeCommand, RentalPhoneDto>,
    IRequestHandler<GetRentalPhoneQuery, RentalPhoneDto>
{
    private static readonly TimeSpan SendWindow = TimeSpan.FromHours(1);

    private const string Busy = "Another request for this number came in at the same time. Try again.";

    public async Task<RentalPhoneCodeSentDto> Handle(SendRentalPhoneCodeCommand request, CancellationToken cancellationToken)
    {
        var customerId = currentUser.OwnerId();
        var phone = RentalPhone.Normalize(request.Phone)!;
        var limits = settings.Value;
        var now = clock.GetUtcNow();

        var row = await dbContext.RentalPhoneVerifications
            .FirstOrDefaultAsync(v => v.CustomerUserId == customerId && v.Phone == phone, cancellationToken);

        if (row?.VerifiedAt is not null)
        {
            return new RentalPhoneCodeSentDto { Phone = phone, AlreadyVerified = true };
        }

        if (row?.LastSentAt is { } lastSent && now < lastSent.AddSeconds(limits.ResendSeconds))
        {
            var wait = (int)Math.Ceiling((lastSent.AddSeconds(limits.ResendSeconds) - now).TotalSeconds);
            throw new DomainException($"Wait {wait} seconds before asking for a new code.");
        }

        // Every number this customer was sent a code for in the last hour, so cycling numbers does
        // not get round the limit.
        var windowStart = now - SendWindow;
        var sentThisHour = await dbContext.RentalPhoneVerifications
            .Where(v => v.CustomerUserId == customerId && v.SendWindowStartedAt > windowStart)
            .SumAsync(v => v.SendsInWindow, cancellationToken);
        if (sentThisHour >= limits.MaxSendsPerHour)
        {
            throw new DomainException("Too many codes asked for. Try again in an hour.");
        }

        // And every customer together, so many accounts cannot flood one person's phone.
        var sentToNumber = await dbContext.RentalPhoneVerifications
            .Where(v => v.Phone == phone && v.SendWindowStartedAt > windowStart)
            .SumAsync(v => v.SendsInWindow, cancellationToken);
        if (sentToNumber >= limits.MaxSendsPerNumberPerHour)
        {
            throw new DomainException("Too many codes were sent to this number. Try again in an hour.");
        }

        if (row is null)
        {
            row = new RentalPhoneVerification { CustomerUserId = customerId, Phone = phone };
            dbContext.RentalPhoneVerifications.Add(row);
        }

        if (row.SendWindowStartedAt is null || row.SendWindowStartedAt <= windowStart)
        {
            row.SendWindowStartedAt = now;
            row.SendsInWindow = 0;
        }

        var code = NewCode(limits.CodeLength);
        row.CodeHash = Hash(row.Id, code);
        row.CodeExpiresAt = now.AddMinutes(limits.ExpiryMinutes);
        row.Attempts = 0;
        row.LastSentAt = now;
        row.SendsInWindow++;
        row.ConcurrencyStamp = Guid.NewGuid();
        await SaveOnceAsync(cancellationToken);

        await sender.SendAsync(phone, code, cancellationToken);

        return new RentalPhoneCodeSentDto
        {
            Phone = phone,
            ExpiresInSeconds = limits.ExpiryMinutes * 60,
            ResendInSeconds = limits.ResendSeconds,
            TestCode = sender.ShowsCode ? code : null,
        };
    }

    public async Task<RentalPhoneDto> Handle(VerifyRentalPhoneCodeCommand request, CancellationToken cancellationToken)
    {
        var customerId = currentUser.OwnerId();
        var phone = RentalPhone.Normalize(request.Phone)!;
        var now = clock.GetUtcNow();

        var row = await dbContext.RentalPhoneVerifications
            .FirstOrDefaultAsync(v => v.CustomerUserId == customerId && v.Phone == phone, cancellationToken);

        if (row?.VerifiedAt is not null)
        {
            return new RentalPhoneDto { Phone = phone, IsVerified = true };
        }

        if (row?.CodeHash is null || row.CodeExpiresAt is null)
        {
            throw new DomainException("Ask for a code first.");
        }

        if (now > row.CodeExpiresAt)
        {
            throw new DomainException("This code has expired. Ask for a new one.");
        }

        var maxAttempts = settings.Value.MaxAttempts;
        if (row.Attempts >= maxAttempts)
        {
            throw new DomainException("Too many wrong codes. Ask for a new one.");
        }

        // The try is counted — and saved — before the code is looked at. Saving fails for all but one
        // of a burst of guesses sent at once, so a burst gets no more tries than one guess at a time.
        row.Attempts++;
        row.ConcurrencyStamp = Guid.NewGuid();
        await SaveOnceAsync(cancellationToken);

        if (!CryptographicOperations.FixedTimeEquals(
                Encoding.UTF8.GetBytes(row.CodeHash),
                Encoding.UTF8.GetBytes(Hash(row.Id, request.Code.Trim()))))
        {
            var left = maxAttempts - row.Attempts;
            throw new DomainException(left > 0
                ? $"That code is not right. {left} {(left == 1 ? "try" : "tries")} left."
                : "That code is not right. Ask for a new one.");
        }

        row.VerifiedAt = now;
        row.CodeHash = null;
        row.CodeExpiresAt = null;
        row.ConcurrencyStamp = Guid.NewGuid();
        await SaveOnceAsync(cancellationToken);
        return new RentalPhoneDto { Phone = phone, IsVerified = true };
    }

    public async Task<RentalPhoneDto> Handle(GetRentalPhoneQuery request, CancellationToken cancellationToken)
    {
        var customerId = currentUser.OwnerId();
        var phone = await dbContext.RentalPhoneVerifications
            .AsNoTracking()
            .Where(v => v.CustomerUserId == customerId && v.VerifiedAt != null)
            .OrderByDescending(v => v.VerifiedAt)
            .Select(v => v.Phone)
            .FirstOrDefaultAsync(cancellationToken);
        return new RentalPhoneDto { Phone = phone, IsVerified = phone is not null };
    }

    /// <summary>Whether this customer verified this number — the check every app booking passes.</summary>
    public static Task<bool> IsVerifiedAsync(
        IRentDbContext dbContext, Guid customerId, string phone, CancellationToken cancellationToken) =>
        dbContext.RentalPhoneVerifications.AnyAsync(
            v => v.CustomerUserId == customerId && v.Phone == phone && v.VerifiedAt != null,
            cancellationToken);

    /// <summary>
    /// Saves, turning away a request that lost a race with another for the same row — a second new
    /// row for the same number, or a count another request changed first — instead of letting it
    /// through or failing with a server error.
    /// </summary>
    private async Task SaveOnceAsync(CancellationToken cancellationToken)
    {
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException)
        {
            throw new DomainException(Busy);
        }
    }

    private static string NewCode(int length)
    {
        var code = new StringBuilder(length);
        for (var i = 0; i < length; i++)
        {
            code.Append((char)('0' + RandomNumberGenerator.GetInt32(10)));
        }

        return code.ToString();
    }

    /// <summary>Salted with the row's id, so the same code on two rows never hashes alike.</summary>
    private static string Hash(Guid rowId, string code) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes($"{rowId:N}:{code}")));
}
