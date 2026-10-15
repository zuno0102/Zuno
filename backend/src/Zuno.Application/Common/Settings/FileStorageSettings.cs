namespace Zuno.Application.Common.Settings;

public class FileStorageSettings
{
    public const string SectionName = "FileStorage";

    /// <summary>Physical directory, relative to the content root, where uploaded files are written.</summary>
    public string RootPath { get; set; } = "wwwroot/uploads";

    /// <summary>URL path prefix the static file middleware serves <see cref="RootPath"/> under.</summary>
    public string PublicPath { get; set; } = "/uploads";

    public long MaxFileSizeBytes { get; set; } = 5 * 1024 * 1024;

    public long MaxVideoFileSizeBytes { get; set; } = 25 * 1024 * 1024;
}
