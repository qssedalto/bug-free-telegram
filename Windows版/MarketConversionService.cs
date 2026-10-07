using System.Globalization;
using System.Numerics;
using System.Text.Json;

namespace 是否认同;

internal sealed record MarketConversions(
    IReadOnlyDictionary<string, string> FiatPerCny,
    string? GoldCnyPerGram,
    DateTimeOffset UpdatedAt,
    string Source);

internal static class MarketConversionService
{
    private static readonly Uri FiatUri = new("https://api.coinbase.com/v2/exchange-rates?currency=CNY");
    private static readonly Uri GoldUri = new(
        "https://api.coingecko.com/api/v3/simple/price?ids=pax-gold&vs_currencies=cny&include_last_updated_at=true");
    private static readonly HttpClient Client = CreateClient();
    private static MarketConversions? _cache;
    private static DateTimeOffset _expiresAt;

    internal static async Task<MarketConversions> GetAsync(CancellationToken cancellationToken)
    {
        if (_cache is not null && DateTimeOffset.UtcNow < _expiresAt) return _cache;
        NetworkRegion region = await NetworkRegionService.GetAsync(cancellationToken).ConfigureAwait(false);
        Task<(IReadOnlyDictionary<string, string> Rates, DateTimeOffset Updated, string Source)> fiatTask =
            FetchFiatWithFallbackAsync(region.IsChina, cancellationToken);
        Task<(string? Gold, DateTimeOffset Updated, string Source)> goldTask =
            FetchGoldWithFallbackAsync(region.IsChina, cancellationToken);
        await Task.WhenAll(fiatTask, goldTask).ConfigureAwait(false);
        DateTimeOffset updated = fiatTask.Result.Updated > goldTask.Result.Updated
            ? fiatTask.Result.Updated
            : goldTask.Result.Updated;
        string source = $"{fiatTask.Result.Source}；{goldTask.Result.Source}";
        var result = new MarketConversions(fiatTask.Result.Rates, goldTask.Result.Gold, updated, source);
        _cache = result;
        _expiresAt = DateTimeOffset.UtcNow.AddMinutes(5);
        return result;
    }

    private static async Task<(IReadOnlyDictionary<string, string> Rates, DateTimeOffset Updated, string Source)>
        FetchFiatWithFallbackAsync(bool preferChina, CancellationToken cancellationToken)
    {
        Func<CancellationToken, Task<(IReadOnlyDictionary<string, string>, DateTimeOffset, string)>>[] sources = preferChina
            ? [FetchChinaFiatAsync, FetchInternationalFiatAsync]
            : [FetchInternationalFiatAsync, FetchChinaFiatAsync];
        Exception? firstFailure = null;
        foreach (var source in sources)
        {
            try
            {
                return await source(cancellationToken).ConfigureAwait(false);
            }
            catch (Exception exception) when (IsRecoverable(exception, cancellationToken))
            {
                firstFailure ??= exception;
            }
        }
        throw new InvalidOperationException("无法获取外币汇率。", firstFailure);
    }

    private static async Task<(string? Gold, DateTimeOffset Updated, string Source)>
        FetchGoldWithFallbackAsync(bool preferChina, CancellationToken cancellationToken)
    {
        Func<CancellationToken, Task<(string, DateTimeOffset, string)>>[] sources = preferChina
            ? [FetchChinaGoldAsync, FetchInternationalGoldAsync]
            : [FetchInternationalGoldAsync, FetchChinaGoldAsync];
        foreach (var source in sources)
        {
            try
            {
                return await source(cancellationToken).ConfigureAwait(false);
            }
            catch (Exception exception) when (IsRecoverable(exception, cancellationToken))
            {
            }
        }
        return (null, DateTimeOffset.UtcNow, "黄金行情暂不可用");
    }

    private static async Task<(IReadOnlyDictionary<string, string>, DateTimeOffset, string)>
        FetchChinaFiatAsync(CancellationToken cancellationToken)
    {
        ChinaFiatQuote quote = await ChinaMarketSource.GetFiatAsync(cancellationToken).ConfigureAwait(false);
        return (quote.FiatPerCny, quote.UpdatedAt, "中国银行外汇牌价");
    }

    private static async Task<(IReadOnlyDictionary<string, string>, DateTimeOffset, string)>
        FetchInternationalFiatAsync(CancellationToken cancellationToken)
    {
        using JsonDocument document = await GetJsonAsync(FiatUri, cancellationToken).ConfigureAwait(false);
        JsonElement rates = document.RootElement.GetProperty("data").GetProperty("rates");
        var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (string currency in new[] { "USD", "EUR", "JPY", "HKD" })
        {
            string value = rates.GetProperty(currency).GetString()
                ?? throw new InvalidDataException($"缺少 {currency} 汇率。");
            result[currency] = Normalize(value);
        }
        return (result, DateTimeOffset.UtcNow, "Coinbase 外汇行情");
    }

    private static async Task<(string, DateTimeOffset, string)> FetchChinaGoldAsync(
        CancellationToken cancellationToken)
    {
        ChinaGoldQuote quote = await ChinaMarketSource.GetGoldAsync(cancellationToken).ConfigureAwait(false);
        return (quote.CnyPerGram, quote.UpdatedAt, "上海黄金交易所 Au99.99");
    }

    private static async Task<(string, DateTimeOffset, string)> FetchInternationalGoldAsync(
        CancellationToken cancellationToken)
    {
        using JsonDocument document = await GetJsonAsync(GoldUri, cancellationToken).ConfigureAwait(false);
        JsonElement gold = document.RootElement.GetProperty("pax-gold");
        decimal cnyPerOunce = gold.GetProperty("cny").GetDecimal();
        if (cnyPerOunce <= 0) throw new InvalidDataException("国际黄金行情无效。");
        decimal cnyPerGram = cnyPerOunce / 31.1034768m;
        DateTimeOffset updated = DateTimeOffset.UtcNow;
        if (gold.TryGetProperty("last_updated_at", out JsonElement timestamp)
            && timestamp.TryGetInt64(out long seconds))
            updated = DateTimeOffset.FromUnixTimeSeconds(seconds);
        return (Normalize(cnyPerGram.ToString(CultureInfo.InvariantCulture)), updated, "CoinGecko PAX Gold");
    }

    private static async Task<JsonDocument> GetJsonAsync(Uri uri, CancellationToken cancellationToken)
    {
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(8));
        using HttpResponseMessage response = await Client.GetAsync(uri, HttpCompletionOption.ResponseHeadersRead, timeout.Token)
            .ConfigureAwait(false);
        response.EnsureSuccessStatusCode();
        if (response.Content.Headers.ContentLength is > 524_288) throw new InvalidDataException("行情响应过大。");
        await using Stream stream = await response.Content.ReadAsStreamAsync(timeout.Token).ConfigureAwait(false);
        return await JsonDocument.ParseAsync(stream, new JsonDocumentOptions { MaxDepth = 16 }, timeout.Token)
            .ConfigureAwait(false);
    }

    private static string Normalize(string value)
    {
        if (!decimal.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out decimal parsed) || parsed <= 0)
            throw new InvalidDataException("汇率无效。");
        return parsed.ToString("0.##################", CultureInfo.InvariantCulture);
    }

    private static bool IsRecoverable(Exception exception, CancellationToken callerToken) =>
        !callerToken.IsCancellationRequested
        && exception is HttpRequestException
            or TaskCanceledException
            or JsonException
            or InvalidDataException
            or FormatException
            or KeyNotFoundException
            or OverflowException;

    private static HttpClient CreateClient()
    {
        var client = new HttpClient();
        client.DefaultRequestHeaders.UserAgent.ParseAdd("TGLab-ShiFouRenTong/1.0");
        client.DefaultRequestHeaders.Accept.ParseAdd("application/json");
        return client;
    }
}

internal static class ArbitraryMoneyMath
{
    internal static string Multiply(string integerDigits, string multiplier, int decimals)
    {
        BigInteger amount = BigInteger.Parse(integerDigits, CultureInfo.InvariantCulture);
        (BigInteger units, BigInteger scale) = ParseDecimal(multiplier);
        BigInteger displayScale = BigInteger.Pow(10, decimals);
        BigInteger numerator = amount * units * displayScale;
        BigInteger rounded = BigInteger.DivRem(numerator, scale, out BigInteger remainder);
        if ((remainder * 2) >= scale) rounded += BigInteger.One;
        return FormatFixed(rounded, decimals);
    }

    internal static string Divide(string integerDigits, string divisor, int decimals)
    {
        BigInteger amount = BigInteger.Parse(integerDigits, CultureInfo.InvariantCulture);
        (BigInteger units, BigInteger scale) = ParseDecimal(divisor);
        BigInteger displayScale = BigInteger.Pow(10, decimals);
        BigInteger numerator = amount * scale * displayScale;
        BigInteger rounded = BigInteger.DivRem(numerator, units, out BigInteger remainder);
        if ((remainder * 2) >= units) rounded += BigInteger.One;
        return FormatFixed(rounded, decimals);
    }

    internal static string DivideByIntegerFactor(string integerDigits, string divisor, long factor, int decimals)
    {
        if (factor <= 0) throw new ArgumentOutOfRangeException(nameof(factor));
        BigInteger amount = BigInteger.Parse(integerDigits, CultureInfo.InvariantCulture);
        (BigInteger units, BigInteger scale) = ParseDecimal(divisor);
        BigInteger displayScale = BigInteger.Pow(10, decimals);
        BigInteger numerator = amount * scale * displayScale;
        BigInteger denominator = units * factor;
        BigInteger rounded = BigInteger.DivRem(numerator, denominator, out BigInteger remainder);
        if ((remainder * 2) >= denominator) rounded += BigInteger.One;
        return FormatFixed(rounded, decimals);
    }

    private static (BigInteger Units, BigInteger Scale) ParseDecimal(string value)
    {
        string[] parts = value.Split('.', 2);
        string fraction = parts.Length == 2 ? parts[1].TrimEnd('0') : string.Empty;
        if (parts.Length is < 1 or > 2 || parts[0].Length == 0
            || !parts.All(part => part.All(char.IsAsciiDigit)) || fraction.Length > 18)
            throw new FormatException("小数格式无效。");
        BigInteger units = BigInteger.Parse(parts[0] + fraction, CultureInfo.InvariantCulture);
        if (units <= 0) throw new FormatException("数值必须大于零。");
        return (units, BigInteger.Pow(10, fraction.Length));
    }

    private static string FormatFixed(BigInteger scaled, int decimals)
    {
        BigInteger scale = BigInteger.Pow(10, decimals);
        BigInteger whole = BigInteger.DivRem(scaled, scale, out BigInteger fraction);
        string grouped = Group(whole.ToString(CultureInfo.InvariantCulture));
        return decimals == 0 ? grouped : $"{grouped}.{fraction.ToString($"D{decimals}", CultureInfo.InvariantCulture)}";
    }

    private static string Group(string digits)
    {
        var result = new System.Text.StringBuilder();
        for (int index = 0; index < digits.Length; index++)
        {
            if (index > 0 && (digits.Length - index) % 3 == 0) result.Append(',');
            result.Append(digits[index]);
        }
        return result.ToString();
    }
}
