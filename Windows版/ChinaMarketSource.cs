using System.Globalization;
using System.Net;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace 是否认同;

internal sealed record ChinaFiatQuote(
    IReadOnlyDictionary<string, string> FiatPerCny,
    string CnyPerUsd,
    DateTimeOffset UpdatedAt);

internal sealed record ChinaGoldQuote(
    string CnyPerGram,
    DateTimeOffset UpdatedAt);

internal static partial class ChinaMarketSource
{
    private const int MaximumResponseBytes = 512 * 1024;
    private static readonly Uri BankOfChinaUri = new("https://www.boc.cn/sourcedb/whpj/");
    private static readonly Uri ShanghaiGoldUri = new("https://www.sge.com.cn/graph/quotations");
    private static readonly HttpClient Client = CreateClient();
    private static readonly SemaphoreSlim FiatLock = new(1, 1);
    private static readonly SemaphoreSlim GoldLock = new(1, 1);
    private static ChinaFiatQuote? _fiatCache;
    private static ChinaGoldQuote? _goldCache;
    private static DateTimeOffset _fiatExpiresAt;
    private static DateTimeOffset _goldExpiresAt;

    private static readonly IReadOnlyDictionary<string, string> CurrencyNames =
        new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["美元"] = "USD",
            ["欧元"] = "EUR",
            ["日元"] = "JPY",
            ["港币"] = "HKD"
        };

    internal static async Task<ChinaFiatQuote> GetFiatAsync(CancellationToken cancellationToken)
    {
        if (_fiatCache is not null && DateTimeOffset.UtcNow < _fiatExpiresAt) return _fiatCache;
        await FiatLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_fiatCache is not null && DateTimeOffset.UtcNow < _fiatExpiresAt) return _fiatCache;
            string html = await GetTextAsync(BankOfChinaUri, cancellationToken).ConfigureAwait(false);
            _fiatCache = ParseBankOfChinaHtml(html);
            _fiatExpiresAt = DateTimeOffset.UtcNow.AddMinutes(5);
            return _fiatCache;
        }
        catch when (_fiatCache is not null && !cancellationToken.IsCancellationRequested)
        {
            return _fiatCache;
        }
        finally
        {
            FiatLock.Release();
        }
    }

    internal static async Task<ChinaGoldQuote> GetGoldAsync(CancellationToken cancellationToken)
    {
        if (_goldCache is not null && DateTimeOffset.UtcNow < _goldExpiresAt) return _goldCache;
        await GoldLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_goldCache is not null && DateTimeOffset.UtcNow < _goldExpiresAt) return _goldCache;
            string json = await GetTextAsync(ShanghaiGoldUri, cancellationToken).ConfigureAwait(false);
            _goldCache = ParseShanghaiGoldJson(json);
            _goldExpiresAt = DateTimeOffset.UtcNow.AddMinutes(2);
            return _goldCache;
        }
        catch when (_goldCache is not null && !cancellationToken.IsCancellationRequested)
        {
            return _goldCache;
        }
        finally
        {
            GoldLock.Release();
        }
    }

    internal static ChinaFiatQuote ParseBankOfChinaHtml(string html)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(html);
        var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        decimal cnyPerUsd = 0;
        DateTimeOffset updatedAt = DateTimeOffset.UtcNow;
        bool foundTimestamp = false;

        foreach (Match rowMatch in TableRowRegex().Matches(html))
        {
            List<string> cells = TableCellRegex().Matches(rowMatch.Groups[1].Value)
                .Select(match => CleanCell(match.Groups[1].Value))
                .ToList();
            if (cells.Count < 7 || !CurrencyNames.TryGetValue(cells[0], out string? currency)) continue;

            if (!decimal.TryParse(cells[5], NumberStyles.Float, CultureInfo.InvariantCulture, out decimal cnyPerHundred)
                || cnyPerHundred <= 0
                || cnyPerHundred > 1_000_000m)
            {
                throw new InvalidDataException($"中国银行 {cells[0]} 折算价无效。");
            }

            decimal foreignPerCny = 100m / cnyPerHundred;
            result[currency] = Normalize(foreignPerCny);
            if (currency == "USD") cnyPerUsd = cnyPerHundred / 100m;

            if (TryParseChinaTime(cells[6], out DateTimeOffset rowTime)
                && (!foundTimestamp || rowTime > updatedAt))
            {
                updatedAt = rowTime;
                foundTimestamp = true;
            }
        }

        if (result.Count != CurrencyNames.Count || cnyPerUsd <= 0)
            throw new InvalidDataException("中国银行页面缺少所需外汇牌价。");

        return new ChinaFiatQuote(result, Normalize(cnyPerUsd), updatedAt);
    }

    internal static ChinaGoldQuote ParseShanghaiGoldJson(string json)
    {
        using JsonDocument document = JsonDocument.Parse(json, new JsonDocumentOptions { MaxDepth = 16 });
        JsonElement root = document.RootElement;
        string? contract = root.GetProperty("heyue").GetString();
        if (!string.Equals(contract, "Au99.99", StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException("上海黄金交易所返回了错误的合约。");

        decimal latest = 0;
        JsonElement data = root.GetProperty("data");
        for (int index = data.GetArrayLength() - 1; index >= 0; index--)
        {
            JsonElement item = data[index];
            if ((item.ValueKind == JsonValueKind.Number && item.TryGetDecimal(out latest))
                || (item.ValueKind == JsonValueKind.String
                    && decimal.TryParse(item.GetString(), NumberStyles.Float, CultureInfo.InvariantCulture, out latest)))
            {
                if (latest > 0 && latest < 1_000_000m) break;
            }
            latest = 0;
        }
        if (latest <= 0) throw new InvalidDataException("上海黄金交易所行情没有有效价格。");

        DateTimeOffset updatedAt = DateTimeOffset.UtcNow;
        if (root.TryGetProperty("delaystr", out JsonElement timeElement)
            && TryParseChinaTime(timeElement.GetString(), out DateTimeOffset parsed))
        {
            updatedAt = parsed;
        }
        return new ChinaGoldQuote(Normalize(latest), updatedAt);
    }

    private static async Task<string> GetTextAsync(Uri uri, CancellationToken cancellationToken)
    {
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(8));
        using HttpResponseMessage response = await Client.GetAsync(
            uri,
            HttpCompletionOption.ResponseHeadersRead,
            timeout.Token).ConfigureAwait(false);
        response.EnsureSuccessStatusCode();
        if (response.Content.Headers.ContentLength is > MaximumResponseBytes)
            throw new InvalidDataException("中国行情响应过大。");

        byte[] bytes = await response.Content.ReadAsByteArrayAsync(timeout.Token).ConfigureAwait(false);
        if (bytes.Length > MaximumResponseBytes) throw new InvalidDataException("中国行情响应过大。");
        return Encoding.UTF8.GetString(bytes);
    }

    private static string CleanCell(string html) =>
        WebUtility.HtmlDecode(HtmlTagRegex().Replace(html, string.Empty))
            .Replace("&nbsp;", " ", StringComparison.OrdinalIgnoreCase)
            .Trim();

    private static bool TryParseChinaTime(string? value, out DateTimeOffset result)
    {
        result = default;
        if (string.IsNullOrWhiteSpace(value)) return false;
        string[] formats = ["yyyy/MM/dd HH:mm:ss", "yyyy年MM月dd日 HH:mm:ss"];
        if (!DateTime.TryParseExact(
                value.Trim(),
                formats,
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out DateTime local)) return false;
        result = new DateTimeOffset(DateTime.SpecifyKind(local, DateTimeKind.Unspecified), TimeSpan.FromHours(8));
        return true;
    }

    private static string Normalize(decimal value) =>
        value.ToString("0.##################", CultureInfo.InvariantCulture);

    private static HttpClient CreateClient()
    {
        var handler = new HttpClientHandler
        {
            AutomaticDecompression = DecompressionMethods.All
        };
        var client = new HttpClient(handler);
        client.DefaultRequestHeaders.UserAgent.ParseAdd("TGLab-ShiFouRenTong/1.0");
        client.DefaultRequestHeaders.Accept.ParseAdd("text/html");
        client.DefaultRequestHeaders.Accept.ParseAdd("application/json");
        return client;
    }

    [GeneratedRegex(@"<tr\b[^>]*>(.*?)</tr>", RegexOptions.IgnoreCase | RegexOptions.Singleline)]
    private static partial Regex TableRowRegex();

    [GeneratedRegex(@"<td\b[^>]*>(.*?)</td>", RegexOptions.IgnoreCase | RegexOptions.Singleline)]
    private static partial Regex TableCellRegex();

    [GeneratedRegex(@"<[^>]+>", RegexOptions.Singleline)]
    private static partial Regex HtmlTagRegex();
}
