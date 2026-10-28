using FluentAssertions;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;
using Moq;
using Zuno.Application.Common.Settings;
using Zuno.Infrastructure.Services;

namespace Zuno.Infrastructure.UnitTests.Services;

/// <summary>Personal documents stay inside private storage, under names the server chose.</summary>
public sealed class LocalPrivateDocumentStoreTests : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), $"zuno-private-{Guid.NewGuid():N}");
    private readonly LocalPrivateDocumentStore _store;

    public LocalPrivateDocumentStoreTests()
    {
        var host = new Mock<IHostEnvironment>();
        host.Setup(h => h.ContentRootPath).Returns(_root);
        _store = new LocalPrivateDocumentStore(
            host.Object, Options.Create(new FileStorageSettings { PrivateRootPath = "private-uploads" }));
    }

    public void Dispose()
    {
        if (Directory.Exists(_root))
        {
            Directory.Delete(_root, recursive: true);
        }
    }

    [Fact]
    public async Task SaveThenOpen_ReturnsTheSameBytesUnderARandomName()
    {
        var key = await _store.SaveAsync("vacancies/v1/a1", new MemoryStream([1, 2, 3]), "pdf", CancellationToken.None);

        key.Should().StartWith("vacancies/v1/a1/").And.EndWith(".pdf");
        await using var read = _store.OpenRead(key)!;
        using var copy = new MemoryStream();
        await read.CopyToAsync(copy);
        copy.ToArray().Should().Equal(1, 2, 3);
    }

    [Fact]
    public async Task DeleteFolder_RemovesEverythingInIt()
    {
        var key = await _store.SaveAsync("vacancies/v1/a1", new MemoryStream([1]), "png", CancellationToken.None);

        _store.DeleteFolder("vacancies/v1");

        _store.OpenRead(key).Should().BeNull();
    }

    [Fact]
    public void DeleteFolder_WhenAlreadyGone_DoesNothing()
    {
        var act = () => _store.DeleteFolder("vacancies/never-existed");

        act.Should().NotThrow();
    }

    [Theory]
    [InlineData("../appsettings.json")]
    [InlineData("vacancies/../../secrets.json")]
    [InlineData("..")]
    public void AKeyOutsidePrivateStorage_IsRefused(string key)
    {
        var open = () => _store.OpenRead(key);
        var delete = () => _store.DeleteFolder(key);

        open.Should().Throw<InvalidOperationException>();
        delete.Should().Throw<InvalidOperationException>();
    }
}
