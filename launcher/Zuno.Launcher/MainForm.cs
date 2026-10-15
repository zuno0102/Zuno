using System.Diagnostics;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Logging;
using Microsoft.Web.WebView2.WinForms;

namespace Zuno.Launcher;

internal sealed class MainForm : Form
{
    private readonly Label _statusLabel;
    private readonly WebView2 _webView;
    private readonly LauncherSettings _settings;
    private readonly string _baseDirectory;

    private Process? _backendProcess;
    private WebApplication? _staticServer;

    public MainForm()
    {
        _baseDirectory = AppContext.BaseDirectory;
        _settings = LauncherSettings.Load(_baseDirectory);

        Text = _settings.WindowTitle;
        Width = 1280;
        Height = 800;
        StartPosition = FormStartPosition.CenterScreen;

        _statusLabel = new Label
        {
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.MiddleCenter,
            Font = new Font("Segoe UI", 14F),
            Text = "Starting Zuno..."
        };

        _webView = new WebView2
        {
            Dock = DockStyle.Fill,
            Visible = false
        };

        Controls.Add(_webView);
        Controls.Add(_statusLabel);

        Load += OnLoadAsync;
        FormClosing += OnFormClosing;
    }

    private async void OnLoadAsync(object? sender, EventArgs e)
    {
        try
        {
            StartBackend();
            await StartStaticServerAsync();

            var backendReady = await WaitForBackendAsync(TimeSpan.FromSeconds(45));
            if (!backendReady)
            {
                _statusLabel.Text = "The backend service did not start in time. Please close and try again.";
                return;
            }

            await _webView.EnsureCoreWebView2Async();
            _webView.CoreWebView2.Navigate($"http://localhost:{_settings.StaticPort}/");
            _webView.Visible = true;
            _statusLabel.Visible = false;
        }
        catch (Exception ex)
        {
            _statusLabel.Text = $"Failed to start: {ex.Message}";
        }
    }

    private void StartBackend()
    {
        var backendExe = Path.Combine(_baseDirectory, _settings.BackendExeRelativePath);
        if (!File.Exists(backendExe))
        {
            throw new FileNotFoundException("Backend executable not found.", backendExe);
        }

        var startInfo = new ProcessStartInfo
        {
            FileName = backendExe,
            WorkingDirectory = Path.GetDirectoryName(backendExe),
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        };

        startInfo.EnvironmentVariables["ASPNETCORE_ENVIRONMENT"] = "Testing";
        startInfo.EnvironmentVariables["ASPNETCORE_URLS"] = $"http://127.0.0.1:{_settings.BackendPort}";
        startInfo.EnvironmentVariables["Cors__AllowedOrigins__0"] = $"http://localhost:{_settings.StaticPort}";
        startInfo.EnvironmentVariables["ConnectionStrings__ZunoDatabase"] = _settings.ConnectionString;
        startInfo.EnvironmentVariables["JwtSettings__SigningKey"] = _settings.JwtSigningKey;

        _backendProcess = new Process { StartInfo = startInfo, EnableRaisingEvents = true };
        _backendProcess.OutputDataReceived += (_, args) => LogBackendLine(args.Data);
        _backendProcess.ErrorDataReceived += (_, args) => LogBackendLine(args.Data);
        _backendProcess.Start();
        _backendProcess.BeginOutputReadLine();
        _backendProcess.BeginErrorReadLine();
    }

    private async Task StartStaticServerAsync()
    {
        var webRoot = Path.Combine(_baseDirectory, _settings.WebRootRelativePath);
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            ContentRootPath = _baseDirectory,
            WebRootPath = webRoot
        });
        builder.Logging.ClearProviders();

        var app = builder.Build();
        app.UseStaticFiles();
        app.MapFallbackToFile("index.html");
        app.Urls.Add($"http://localhost:{_settings.StaticPort}");

        await app.StartAsync();
        _staticServer = app;
    }

    private async Task<bool> WaitForBackendAsync(TimeSpan timeout)
    {
        using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(3) };
        var healthUrl = $"http://127.0.0.1:{_settings.BackendPort}{_settings.BackendHealthCheckPath}";
        var deadline = DateTime.UtcNow + timeout;

        while (DateTime.UtcNow < deadline)
        {
            try
            {
                var response = await http.GetAsync(healthUrl);
                if (response.IsSuccessStatusCode)
                {
                    return true;
                }
            }
            catch
            {
                // Backend not ready yet; retry until timeout.
            }

            await Task.Delay(750);
        }

        return false;
    }

    private void LogBackendLine(string? line)
    {
        if (string.IsNullOrEmpty(line))
        {
            return;
        }

        try
        {
            File.AppendAllText(Path.Combine(_baseDirectory, "backend.log"), line + Environment.NewLine);
        }
        catch
        {
            // Best-effort logging only.
        }
    }

    private void OnFormClosing(object? sender, FormClosingEventArgs e)
    {
        try
        {
            _staticServer?.StopAsync().GetAwaiter().GetResult();
        }
        catch
        {
            // Best-effort shutdown.
        }

        try
        {
            if (_backendProcess is { HasExited: false })
            {
                _backendProcess.Kill(entireProcessTree: true);
            }
        }
        catch
        {
            // Best-effort shutdown.
        }
    }
}
