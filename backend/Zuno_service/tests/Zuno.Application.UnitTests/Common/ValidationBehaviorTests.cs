using FluentAssertions;
using FluentValidation;
using MediatR;
using Microsoft.Extensions.DependencyInjection;
using Zuno.Application.Common.Behaviors;
using Zuno.Application.Modules.Authentication.Commands.ChangePassword;

namespace Zuno.Application.UnitTests.Common;

/// <summary>
/// The validation step runs for every request through the real MediatR pipeline — including a
/// command that returns nothing, whose validators were once skipped and let "abc" in as a new
/// password.
/// </summary>
public class ValidationBehaviorTests
{
    public class SaySomething : IRequest
    {
        public string Text { get; set; } = string.Empty;
    }

    public class SaySomethingValidator : AbstractValidator<SaySomething>
    {
        public SaySomethingValidator() => RuleFor(x => x.Text).NotEmpty();
    }

    public class SaySomethingHandler : IRequestHandler<SaySomething>
    {
        public static int Handled;

        public Task Handle(SaySomething request, CancellationToken cancellationToken)
        {
            Handled++;
            return Task.CompletedTask;
        }
    }

    private static ISender Mediator()
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddMediatR(config =>
        {
            config.RegisterServicesFromAssemblyContaining<ValidationBehaviorTests>();
            config.AddOpenBehavior(typeof(ValidationBehavior<,>));
        });
        services.AddTransient<IValidator<SaySomething>, SaySomethingValidator>();
        return services.BuildServiceProvider().GetRequiredService<ISender>();
    }

    [Fact]
    public async Task A_command_that_returns_nothing_is_still_validated()
    {
        var before = SaySomethingHandler.Handled;

        var act = () => Mediator().Send(new SaySomething { Text = "" });

        await act.Should().ThrowAsync<ValidationException>();
        SaySomethingHandler.Handled.Should().Be(before, "the handler never runs on invalid input");
    }

    [Fact]
    public async Task A_valid_command_that_returns_nothing_goes_through()
    {
        var before = SaySomethingHandler.Handled;

        await Mediator().Send(new SaySomething { Text = "hello" });

        SaySomethingHandler.Handled.Should().Be(before + 1);
    }

    [Theory]
    [InlineData("abc")]
    [InlineData("abcdefgh")]
    public void A_weak_new_password_is_refused(string password) =>
        new ChangePasswordCommandValidator()
            .Validate(new ChangePasswordCommand { CurrentPassword = "E2e@12345", NewPassword = password })
            .IsValid.Should().BeFalse();
}
