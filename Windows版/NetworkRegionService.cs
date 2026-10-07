using System.Globalization;
using System.Text.Json;

namespace 是否认同;

internal sealed record NetworkRegion(
    bool IsChina,
    string CountryCode,
    string Source,
    bool IsCertain);

internal static class NetworkRegionService
{
    private const int MaximumResponseBytes = 32 * 1024;
    private static readonly Uri CloudflareTraceUri = new("https://www.cloudflare.com/cdn-cgi/trace");
    private static readonly Uri CountryIsUri = new("https://api.country.is/");
    private static readonly HttpClient Client = CreateClient();
    private static readonly SemaphoreSlim RefreshLock = new(1, 1);
    private static NetworkRegion? _cache;
    private static DateTimeOffset _expiresAt;

    internal static async Task<NetworkRegion> GetAsync(CancellationToken cancellationToken)
    {
        if (_cache is not null && DateTimeOffset.UtcNow < _expiresAt) return _cache;

        await RefreshLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_cache is not null && DateTimeOffset.UtcNow < _expiresAt) return _cache;

            foreach (Func<CancellationToken, Task<NetworkRegion>> detector in
                     new Func<CancellationToken, Task<NetworkRegion>>[]
                     {
                         DetectWithCloudflareAsync,
                         DetectWithCountryIsAsync
                     })
            {
                try
                {
                    NetworkRegion result = await detector(cancellationToken).ConfigureAwait(false);
                    _cache = result;
                    _expiresAt = DateTimeOffset.UtcNow.AddMinutes(30);
                    return result;
                }
                catch (Exception exception) when (IsRecoverable(exception, cancellationToken))
                {
                }
            }

            string fallbackCode = GetSystemRegionCode();
            _cache = new NetworkRegion(
                string.Equals(fallbackCode, "CN", StringComparison.OrdinalIgnoreCase),
                fallbackCode,
                "系统地区回退",
                false);
            _expiresAt = DateTimeOffset.UtcNow.AddMinutes(5);
            return _cache;
        }
        finally
        {
            RefreshLock.Release();
        }
    }

    internal static string ParseCloudflareCountry(string trace)
    {
        foreach (string line in trace.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            if (!line.StartsWith("loc=", StringComparison.OrdinalIgnoreCase)) continue;
            return NormalizeCountryCode(line[4..]);
        }
        throw new InvalidDataException("IP 地区响应缺少 loc 字段。");
    }

    internal static string ParseCountryIsCountry(string json)
    {
        using JsonDocument document = JsonDocument.Parse(json, new JsonDocumentOptions { MaxDepth = 8 });
        string? code = document.RootElement.GetProperty("country").GetString();
        return NormalizeCountryCode(code);
    }

    private static async Task<NetworkRegion> DetectWithCloudflareAsync(CancellationToken cancellationToken)
    {
        string trace = await GetTextAsync(CloudflareTraceUri, cancellationToken).ConfigureAwait(false);
        string country = ParseCloudflareCountry(trace);
        return new NetworkRegion(country == "CN", country, "Cloudflare IP 地区", true);
    }

    private static async Task<NetworkRegion> DetectWithCountryIsAsync(CancellationToken cancellationToken)
    {
        string json = await GetTextAsync(CountryIsUri, cancellationToken).ConfigureAwait(false);
        string country = ParseCountryIsCountry(json);
        return new NetworkRegion(country == "CN", country, "Country.is IP 地区", true);
    }

    private static async Task<string> GetTextAsync(Uri uri, CancellationToken cancellationToken)
    {
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(4));
        using HttpResponseMessage response = await Client.GetAsync(
            uri,
            HttpCompletionOption.ResponseHeadersRead,
            timeout.Token).ConfigureAwait(false);
        response.EnsureSuccessStatusCode();
        if (response.Content.Headers.ContentLength is > MaximumResponseBytes)
            throw new InvalidDataException("IP 地区响应过大。");

        byte[] bytes = await response.Content.ReadAsByteArrayAsync(timeout.Token).ConfigureAwait(false);
        if (bytes.Length > MaximumResponseBytes) throw new InvalidDataException("IP 地区响应过大。");
        return System.Text.Encoding.UTF8.GetString(bytes);
    }

    private static string NormalizeCountryCode(string? value)
    {
        string code = value?.Trim().ToUpperInvariant() ?? string.Empty;
        if (code.Length != 2 || !code.All(char.IsAsciiLetter))
            throw new InvalidDataException("IP 地区代码无效。");
        return code;
    }

    private static string GetSystemRegionCode()
    {
        try
        {
            return NormalizeCountryCode(RegionInfo.CurrentRegion.TwoLetterISORegionName);
        }
        catch (Exception exception) when (exception is ArgumentException or InvalidDataException)
        {
            return "ZZ";
        }
    }

    private static bool IsRecoverable(Exception exception, CancellationToken callerToken) =>
        !callerToken.IsCancellationRequested
        && exception is HttpRequestException
            or TaskCanceledException
            or JsonException
            or InvalidDataException
            or KeyNotFoundException;

    private static HttpClient CreateClient()
    {
        var handler = new HttpClientHandler
        {
            AutomaticDecompression = System.Net.DecompressionMethods.All
        };
        var client = new HttpClient(handler);
        client.DefaultRequestHeaders.UserAgent.ParseAdd("TGLab-ShiFouRenTong/1.0");
        client.DefaultRequestHeaders.Accept.ParseAdd("text/plain");
        client.DefaultRequestHeaders.Accept.ParseAdd("application/json");
        return client;
    }
}
