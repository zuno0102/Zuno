using System.Text.Json;

namespace Zuno.Launcher;

internal sealed class LauncherSettings
{
    public string WindowTitle { get; set; } = "Zuno";
    public string BackendExeRelativePath { get; set; } = "backend/Zuno.Api.exe";
    public string WebRootRelativePath { get; set; } = "web";
    public int BackendPort { get; set; } = 5056;
    public int StaticPort { get; set; } = 8090;
    public string BackendHealthCheckPath { get; set; } = "/api/v1/states";
    public string ConnectionString { get; set; } = "";
    public string JwtSigningKey { get; set; } = "";

    public static LauncherSettings Load(string baseDirectory)
    {
        var path = Path.Combine(baseDirectory, "launcher.settings.json");
        if (!File.Exists(path))
        {
            return new LauncherSettings();
        }

        var json = File.ReadAllText(path);
        return JsonSerializer.Deserialize<LauncherSettings>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        }) ?? new LauncherSettings();
    }
}
