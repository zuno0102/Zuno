using MediatR;
using Zuno.Application.Modules.Customer.DTOs;

namespace Zuno.Application.Modules.Customer.Queries.GetServiceDetail;

/// <summary>One service, with every package it is sold in and the business behind it.</summary>
public record GetServiceDetailQuery(Guid ServiceId) : IRequest<ServiceDetailDto>;
