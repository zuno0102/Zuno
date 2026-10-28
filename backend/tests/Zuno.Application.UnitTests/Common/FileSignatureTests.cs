using System.Text;
using FluentAssertions;
using Zuno.Application.Common;

namespace Zuno.Application.UnitTests.Common;

/// <summary>An upload is judged by its bytes. The name and content type are the attacker's to choose.</summary>
public class FileSignatureTests
{
    [Fact]
    public void Detect_Pdf() =>
        FileSignature.Detect("%PDF-1.7\n..."u8).Should().Be(new DetectedFile("pdf", "application/pdf"));

    [Fact]
    public void Detect_Jpeg_IsCanonicalisedToJpgButAcceptsJpeg()
    {
        var detected = FileSignature.Detect([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46]);

        detected!.Extension.Should().Be("jpg");
        detected.Aliases.Should().BeEquivalentTo("jpg", "jpeg");
    }

    [Fact]
    public void Detect_Png() =>
        FileSignature.Detect([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0x0D])!
            .ContentType.Should().Be("image/png");

    [Fact]
    public void Detect_Webp() =>
        FileSignature.Detect(Encoding.ASCII.GetBytes("RIFF\x10\0\0\0WEBPVP8 "))!
            .Extension.Should().Be("webp");

    [Theory]
    [InlineData("#!/bin/sh\necho")]          // a script renamed .pdf
    [InlineData("<html><script>")]           // markup
    [InlineData("MZ\x90\0\x03\0\0\0")]       // a Windows executable
    [InlineData("RIFF\x10\0\0\0WAVEfmt ")]   // RIFF, but audio
    [InlineData("%PD")]                      // too short to be a PDF
    [InlineData("")]
    public void Detect_AnythingElse_IsNull(string content) =>
        FileSignature.Detect(Encoding.Latin1.GetBytes(content)).Should().BeNull();

    private static byte[] Bytes(params int[] values) => [.. values.Select(v => (byte)v)];

    private static byte[] IsoMedia(string brand) =>
        [0, 0, 0, 0x18, .. Encoding.ASCII.GetBytes("ftyp" + brand)];

    [Fact]
    public void DetectVideo_Mp4() =>
        FileSignature.DetectVideo(IsoMedia("mp42"))!.Extension.Should().Be("mp4");

    [Fact]
    public void DetectVideo_Mov() =>
        FileSignature.DetectVideo(IsoMedia("qt  "))!.Extension.Should().Be("mov");

    [Fact]
    public void DetectVideo_Webm() =>
        FileSignature.DetectVideo(Bytes(0x1A, 0x45, 0xDF, 0xA3, 0x9F, 0x42, 0x86, 0x81, 0x01, 0x42, 0xF7, 0x81))!
            .Extension.Should().Be("webm");

    [Theory]
    [InlineData("<html><body>")]                                 // a web page named .mp4
    [InlineData("<svg xmlns=\"http://www.w3.org/2000/svg\">")]    // an SVG, which can carry script
    [InlineData("")]
    public void DetectVideo_AnythingElse_IsNull(string content) =>
        FileSignature.DetectVideo(Encoding.ASCII.GetBytes(content)).Should().BeNull();

    [Fact]
    public void DetectVideo_AnImage_IsNotAVideo() =>
        FileSignature.DetectVideo(Bytes(0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46, 0x49, 0x46, 0, 1)).Should().BeNull();

    [Fact]
    public void DetectVideo_TooShortToReadTheBrand_IsNull() =>
        FileSignature.DetectVideo(IsoMedia("")).Should().BeNull();

    [Theory]
    [InlineData("<svg xmlns=\"http://www.w3.org/2000/svg\"><script>")]
    [InlineData("<!DOCTYPE html><html>")]
    public void Detect_MarkupIsNeverAnImage(string content) =>
        FileSignature.Detect(Encoding.ASCII.GetBytes(content)).Should().BeNull();
}
