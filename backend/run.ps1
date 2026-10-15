#!/usr/bin/env pwsh
# Runs the Zuno API from the solution folder.
#
# `dotnet run` cannot target a solution, so running it here fails with
# "Couldn't find a project to run". This wraps the real command:
#     dotnet run --project src/Zuno.Api --launch-profile http
#
# The `http` profile is the default because the Flutter client talks to
# plain http://localhost:5056. Pass -Https to also bind 7087.
#
# Usage:  .\run.ps1            .\run.ps1 -Https            .\run.ps1 -NoBuild

[CmdletBinding()]
param(
    [switch]$Https,
    [switch]$NoBuild
)

$ErrorActionPreference = 'Stop'

$project = Join-Path $PSScriptRoot 'src/Zuno.Api'
$profileName = if ($Https) { 'https' } else { 'http' }

$arguments = @('run', '--project', $project, '--launch-profile', $profileName)
if ($NoBuild) { $arguments += '--no-build' }

Write-Host "Starting Zuno API ($profileName profile)..." -ForegroundColor Cyan
& dotnet @arguments
