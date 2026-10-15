# Build context: backend/
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY src/Zuno.Api/Zuno.Api.csproj src/Zuno.Api/
COPY src/Zuno.Application/Zuno.Application.csproj src/Zuno.Application/
COPY src/Zuno.Domain/Zuno.Domain.csproj src/Zuno.Domain/
COPY src/Zuno.Infrastructure/Zuno.Infrastructure.csproj src/Zuno.Infrastructure/
RUN dotnet restore src/Zuno.Api/Zuno.Api.csproj

COPY src/ src/
RUN dotnet publish src/Zuno.Api/Zuno.Api.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app
COPY --from=build /app .

ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 8080
ENTRYPOINT ["sh", "-c", "ASPNETCORE_URLS=http://+:${PORT:-8080} dotnet Zuno.Api.dll"]
