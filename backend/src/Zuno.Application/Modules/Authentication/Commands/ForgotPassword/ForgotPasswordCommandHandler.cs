using MediatR;
using Microsoft.Extensions.Logging;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Application.Modules.Authentication.Commands.ForgotPassword;

public class ForgotPasswordCommandHandler(
    IUserRepository userRepository,
    IJwtTokenService jwtTokenService,
    IEmailService emailService,
    ILogger<ForgotPasswordCommandHandler> logger) : IRequestHandler<ForgotPasswordCommand>
{
    public async Task Handle(ForgotPasswordCommand request, CancellationToken cancellationToken)
    {
        var user = await userRepository.GetByEmailAsync(request.Email, cancellationToken);

        // Always behave identically whether or not the account exists — prevents user enumeration.
        if (user is null)
        {
            return;
        }

        var resetToken = jwtTokenService.GeneratePasswordResetToken(user.Id, user.PasswordHash);

        try
        {
            await emailService.SendPasswordResetEmailAsync(request.Email, resetToken, cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Failed to send password reset email to user {UserId}.", user.Id);
        }
    }
}
