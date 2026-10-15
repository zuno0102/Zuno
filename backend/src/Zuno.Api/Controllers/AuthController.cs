using Asp.Versioning;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;
using Zuno.Api.Common;
using Zuno.Api.RateLimiting;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Settings;
using Zuno.Application.Modules.Authentication.Commands.SetMyAccountPhoto;
using Zuno.Application.Modules.Authentication.Commands.ChangePassword;
using Zuno.Application.Modules.Authentication.Commands.ForgotPassword;
using Zuno.Application.Modules.Authentication.Commands.Login;
using Zuno.Application.Modules.Authentication.Commands.RefreshToken;
using Zuno.Application.Modules.Authentication.Commands.Register;
using Zuno.Application.Modules.Authentication.Commands.RevokeToken;
using Zuno.Application.Modules.Authentication.Commands.UpdateMyAccount;
using Zuno.Application.Modules.Authentication.Commands.ResetPassword;
using Zuno.Application.Modules.Authentication.Queries.GetCurrentUser;

namespace Zuno.Api.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/auth")]
public class AuthController(
    ISender mediator,
    ICurrentUserService currentUserService,
    IFileStorageService fileStorageService,
    IOptions<FileStorageSettings> fileStorageSettings) : ControllerBase
{
    /// <summary>What a profile picture may be. Matches the worker photo endpoint.</summary>
    private static readonly HashSet<string> AllowedImageContentTypes =
        new(StringComparer.OrdinalIgnoreCase)
        {
            "image/jpeg",
            "image/png",
            "image/webp",
        };

    // Marked one by one rather than on the controller: the application denies anything that does not
    // say otherwise, and a class-level AllowAnonymous would silently override the [Authorize] on
    // change-password, revoke-token and me — which the compiler refuses outright.
    [AllowAnonymous]
    [HttpPost("register")]
    [EnableRateLimiting(RateLimiterExtensions.AuthPolicy)]
    public async Task<IActionResult> Register(RegisterUserCommand command, CancellationToken cancellationToken)
    {
        command.IpAddress = GetIpAddress();
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    [AllowAnonymous]
    [HttpPost("login")]
    [EnableRateLimiting(RateLimiterExtensions.AuthPolicy)]
    public async Task<IActionResult> Login(LoginCommand command, CancellationToken cancellationToken)
    {
        command.IpAddress = GetIpAddress();
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    // Carries a credential, so it is throttled like the others: without this, a stolen or guessed
    // refresh token could be tried against the endpoint as fast as the network allows.
    [AllowAnonymous]
    [HttpPost("refresh-token")]
    [EnableRateLimiting(RateLimiterExtensions.AuthPolicy)]
    public async Task<IActionResult> RefreshToken(RefreshTokenCommand command, CancellationToken cancellationToken)
    {
        command.IpAddress = GetIpAddress();
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    [HttpPost("revoke-token")]
    [Authorize]
    public async Task<IActionResult> RevokeToken(RevokeTokenCommand command, CancellationToken cancellationToken)
    {
        command.IpAddress = GetIpAddress();
        await mediator.Send(command, cancellationToken);
        return NoContent();
    }

    [AllowAnonymous]
    [HttpPost("forgot-password")]
    [EnableRateLimiting(RateLimiterExtensions.AuthPolicy)]
    public async Task<IActionResult> ForgotPassword(ForgotPasswordCommand command, CancellationToken cancellationToken)
    {
        await mediator.Send(command, cancellationToken);
        return NoContent();
    }

    // The reset token is the only thing standing between a stranger and the account.
    [AllowAnonymous]
    [HttpPost("reset-password")]
    [EnableRateLimiting(RateLimiterExtensions.AuthPolicy)]
    public async Task<IActionResult> ResetPassword(ResetPasswordCommand command, CancellationToken cancellationToken)
    {
        await mediator.Send(command, cancellationToken);
        return NoContent();
    }

    [HttpPost("change-password")]
    [Authorize]
    public async Task<IActionResult> ChangePassword(ChangePasswordCommand command, CancellationToken cancellationToken)
    {
        await mediator.Send(command, cancellationToken);
        return NoContent();
    }

    /// <summary>Uploads or replaces the signed-in account's own picture.</summary>
    [HttpPut("me/photo")]
    [Authorize]
    public async Task<IActionResult> SetMyPhoto(IFormFile file, CancellationToken cancellationToken)
    {
        if (file.Length == 0)
        {
            return BadRequest(ApiResponse.Fail("No file was uploaded.", HttpContext.TraceIdentifier));
        }

        if (file.Length > fileStorageSettings.Value.MaxFileSizeBytes)
        {
            return BadRequest(ApiResponse.Fail(
                $"Image must be {fileStorageSettings.Value.MaxFileSizeBytes / (1024 * 1024)}MB or smaller.",
                HttpContext.TraceIdentifier));
        }

        if (!AllowedImageContentTypes.Contains(file.ContentType))
        {
            return BadRequest(ApiResponse.Fail(
                "Image must be a JPEG, PNG or WebP file.",
                HttpContext.TraceIdentifier));
        }

        // Taken from the content type just validated, never from the uploaded file name: the name is
        // the caller's to choose and it ends up in a file path.
        var extension = file.ContentType.ToLowerInvariant() switch
        {
            "image/png" => ".png",
            "image/webp" => ".webp",
            _ => ".jpg",
        };

        // Stored under the signed-in user's own id, read from the token.
        var userId = currentUserService.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        await using var stream = file.OpenReadStream();
        var url = await fileStorageService.SaveAccountPhotoAsync(
            userId, stream, extension, cancellationToken);

        var result = await mediator.Send(new SetMyAccountPhotoCommand { Url = url }, cancellationToken);
        return Ok(result);
    }

    /// <summary>Corrects the signed-in account's own name and phone number.</summary>
    [HttpPut("me")]
    [Authorize]
    public async Task<IActionResult> UpdateMyAccount(
        UpdateMyAccountCommand command,
        CancellationToken cancellationToken)
    {
        var result = await mediator.Send(command, cancellationToken);
        return Ok(result);
    }

    [HttpGet("me")]
    [Authorize]
    public async Task<IActionResult> GetCurrentUser(CancellationToken cancellationToken)
    {
        var result = await mediator.Send(new GetCurrentUserQuery(), cancellationToken);
        return Ok(result);
    }

    private string? GetIpAddress() => HttpContext.Connection.RemoteIpAddress?.ToString();
}
