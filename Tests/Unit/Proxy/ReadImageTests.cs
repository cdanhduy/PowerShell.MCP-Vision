using PowerShell.MCP.Proxy.Tools;
using Xunit;

namespace PowerShell.MCP.Tests;

public class ReadImageTests
{
    [Fact]
    public void ReadImage_ReturnsNativeImageContentWithOriginalBytes()
    {
        // 1x1 transparent PNG.
        var bytes = Convert.FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=");
        var path = Path.Combine(Path.GetTempPath(), $"psmcp-vision-{Guid.NewGuid():N}.png");

        try
        {
            File.WriteAllBytes(path, bytes);
            var result = PowerShellTools.ReadImage(path);

            Assert.Equal("image/png", result.MimeType);
            Assert.Equal(bytes, result.DecodedData.ToArray());
        }
        finally
        {
            if (File.Exists(path)) File.Delete(path);
        }
    }

    [Fact]
    public void ReadImage_RejectsUnsupportedExtension()
    {
        var path = Path.Combine(Path.GetTempPath(), $"psmcp-vision-{Guid.NewGuid():N}.txt");
        try
        {
            File.WriteAllText(path, "not an image");
            Assert.Throws<NotSupportedException>(() => PowerShellTools.ReadImage(path));
        }
        finally
        {
            if (File.Exists(path)) File.Delete(path);
        }
    }
}
