using FluentValidation;
using MediatR;
using Microsoft.Extensions.DependencyInjection;
using Zuno.Application.Common.Behaviors;
using Zuno.Application.Common.Interfaces;
using Zuno.Application.Common.Services;
using Zuno.Application.Modules.Authentication.Common;

namespace Zuno.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        var applicationAssembly = typeof(DependencyInjection).Assembly;

        services.AddMediatR(config =>
        {
            config.RegisterServicesFromAssembly(applicationAssembly);
            config.AddOpenBehavior(typeof(UnhandledExceptionBehavior<,>));
            config.AddOpenBehavior(typeof(LoggingBehavior<,>));
            config.AddOpenBehavior(typeof(ValidationBehavior<,>));
            config.AddOpenBehavior(typeof(PerformanceBehavior<,>));
        });

        services.AddValidatorsFromAssembly(applicationAssembly);

        services.AddScoped<RefreshTokenFactory>();
        services.AddScoped<IBusinessVerificationCheck, Modules.Business.Common.BusinessVerificationCheck>();
        services.AddScoped<Modules.Business.Common.BusinessApproval>();
        services.AddScoped<IPayoutDestinationCheck, Modules.Worker.Common.PayoutDestinationCheck>();
        services.AddScoped<IWorkerScheduleService, WorkerScheduleService>();

        // The in-app half of notifications. A push sender decorates this one when FCM lands; it
        // never replaces it, because a dismissed banner leaves no trace and the list has to.
        services.AddScoped<INotificationSender, DatabaseNotificationSender>();

        return services;
    }
}
