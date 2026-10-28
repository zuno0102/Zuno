# Build context: backend/
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY Zuno_service/src/Zuno.Api/Zuno.Api.csproj Zuno_service/src/Zuno.Api/
COPY Zuno_service/src/Zuno.Application/Zuno.Application.csproj Zuno_service/src/Zuno.Application/
COPY Zuno_service/src/Zuno.Domain/Zuno.Domain.csproj Zuno_service/src/Zuno.Domain/
COPY Zuno_service/src/Zuno.Infrastructure/Zuno.Infrastructure.csproj Zuno_service/src/Zuno.Infrastructure/
RUN dotnet restore Zuno_service/src/Zuno.Api/Zuno.Api.csproj

COPY Zuno_service/src/ Zuno_service/src/
RUN dotnet publish Zuno_service/src/Zuno.Api/Zuno.Api.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app
COPY --from=build /app .

ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 8080
ENTRYPOINT ["sh", "-c", "ASPNETCORE_URLS=http://+:${PORT:-8080} dotnet Zuno.Api.dll"]
