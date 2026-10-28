using MediatR;
using Zuno.Application.Modules.WorkChat.DTOs;

namespace Zuno.Application.Modules.WorkChat.Queries.GetMyWorkThreads;

/// <summary>
/// Every business–worker conversation the signed-in user has: a business sees one per worker it has
/// written with, a worker one per business. Only pairs still on the same team, and only once
/// somebody has written.
/// </summary>
public record GetMyWorkThreadsQuery : IRequest<List<WorkThreadDto>>;
