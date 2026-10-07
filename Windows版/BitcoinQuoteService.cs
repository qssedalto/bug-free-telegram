using System.Globalization;
using System.Numerics;
using System.Text.Json;

namespace 是否认同;

internal sealed record BitcoinQuote(
    string CnyPerBitcoin,
    string Source,
    DateTimeOffset UpdatedAt,
    bool IsStale = false);

internal static class BitcoinQuoteService
{
    private const int MaximumResponseBytes = 512 * 1024;
    private static readonly Uri CoinbaseUri = new("https://api.coinbase.com/v2/exchange-rates?currency=BTC");
    private static readonly Uri CoinGeckoUri = new(
        "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=cny&include_last_updated_at=true");
    private static readonly Uri MexcUri = new("https://api.mexc.com/api/v3/ticker/price?symbol=BTCUSDT");
    private static readonly HttpClient Client = CreateClient();
    private static readonly SemaphoreSlim RefreshLock = new(1, 1);
    private static BitcoinQuote? _cachedQuote;
    private static DateTimeOffset _cacheExpiresAt;

    internal static async Task<BitcoinQuote> GetAsync(CancellationToken cancellationToken)
    {
        DateTimeOffset now = DateTimeOffset.UtcNow;
        if (_cachedQuote is not null && now < _cacheExpiresAt) return _cachedQuote;

        await RefreshLock.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            now = DateTimeOffset.UtcNow;
            if (_cachedQuote is not null && now < _cacheExpiresAt) return _cachedQuote;

            NetworkRegion region = await NetworkRegionService.GetAsync(cancellationToken).ConfigureAwait(false);
            Func<CancellationToken, Task<BitcoinQuote>>[] sources = region.IsChina
                ? [FetchMexcWithBankOfChinaAsync, FetchCoinbaseAsync, FetchCoinGeckoAsync]
                : [FetchCoinbaseAsync, FetchCoinGeckoAsync, FetchMexcWithBankOfChinaAsync];

            Exception? firstFailure = null;
            foreach (Func<CancellationToken, Task<BitcoinQuote>> source in sources)
            {
                try
                {
                    BitcoinQuote quote = await source(cancellationToken).ConfigureAwait(false);
                    _cachedQuote = quote;
                    _cacheExpiresAt = now.AddMinutes(1);
                    return quote;
                }
                catch (Exception exception) when (IsRecoverable(exception, cancellationToken))
                {
                    firstFailure ??= exception;
                }
            }

            if (_cachedQuote is not null)
            {
                return _cachedQuote with { IsStale = true };
            }

            throw new InvalidOperationException("无法获取 BTC/CNY 行情。", firstFailure);
        }
        finally
        {
            RefreshLock.Release();
        }
    }

    private static async Task<BitcoinQuote> FetchCoinbaseAsync(CancellationToken cancellationToken)
    {
        using JsonDocument document = await GetJsonAsync(CoinbaseUri, cancellationToken).ConfigureAwait(false);
        JsonElement data = document.RootElement.GetProperty("data");
        if (!string.Equals(data.GetProperty("currency").GetString(), "BTC", StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException("Coinbase 返回了错误的基础货币。");

        string rawPrice = data.GetProperty("rates").GetProperty("CNY").GetString()
            ?? throw new InvalidDataException("Coinbase 响应缺少 CNY 行情。");
        return new BitcoinQuote(NormalizePrice(rawPrice), "Coinbase", DateTimeOffset.UtcNow);
    }

    private static async Task<BitcoinQuote> FetchCoinGeckoAsync(CancellationToken cancellationToken)
    {
        using JsonDocument document = await GetJsonAsync(CoinGeckoUri, cancellationToken).ConfigureAwait(false);
        JsonElement bitcoin = document.RootElement.GetProperty("bitcoin");
        string rawPrice = bitcoin.GetProperty("cny").GetRawText();
        DateTimeOffset updatedAt = DateTimeOffset.UtcNow;
        if (bitcoin.TryGetProperty("last_updated_at", out JsonElement timestamp)
            && timestamp.TryGetInt64(out long seconds))
        {
            updatedAt = DateTimeOffset.FromUnixTimeSeconds(seconds);
        }
        return new BitcoinQuote(NormalizePrice(rawPrice), "CoinGecko", updatedAt);
    }

    private static async Task<BitcoinQuote> FetchMexcWithBankOfChinaAsync(CancellationToken cancellationToken)
    {
        Task<ChinaFiatQuote> fiatTask = ChinaMarketSource.GetFiatAsync(cancellationToken);
        using JsonDocument document = await GetJsonAsync(MexcUri, cancellationToken).ConfigureAwait(false);
        ChinaFiatQuote fiat = await fiatTask.ConfigureAwait(false);

        JsonElement root = document.RootElement;
        if (!string.Equals(root.GetProperty("symbol").GetString(), "BTCUSDT", StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException("MEXC 返回了错误的交易对。");
        string rawUsdtPrice = root.GetProperty("price").GetString()
            ?? throw new InvalidDataException("MEXC 响应缺少 BTC/USDT 行情。");
        if (!decimal.TryParse(rawUsdtPrice, NumberStyles.Float, CultureInfo.InvariantCulture, out decimal usdtPrice)
            || !decimal.TryParse(fiat.CnyPerUsd, NumberStyles.Float, CultureInfo.InvariantCulture, out decimal cnyPerUsd)
            || usdtPrice <= 0
            || cnyPerUsd <= 0)
        {
            throw new InvalidDataException("中国 BTC 换算行情无效。");
        }

        decimal cnyPrice = usdtPrice * cnyPerUsd;
        return new BitcoinQuote(
            NormalizePrice(cnyPrice.ToString(CultureInfo.InvariantCulture)),
            "MEXC BTC/USDT + 中国银行美元折算价",
            fiat.UpdatedAt);
    }

    private static async Task<JsonDocument> GetJsonAsync(Uri uri, CancellationToken cancellationToken)
    {
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(8));
        using HttpResponseMessage response = await Client.GetAsync(
            uri,
            HttpCompletionOption.ResponseHeadersRead,
            timeout.Token).ConfigureAwait(false);
        response.EnsureSuccessStatusCode();

        if (response.Content.Headers.ContentLength is > MaximumResponseBytes)
            throw new InvalidDataException("行情响应过大。");

        await using Stream stream = await response.Content.ReadAsStreamAsync(timeout.Token).ConfigureAwait(false);
        return await JsonDocument.ParseAsync(
            stream,
            new JsonDocumentOptions { MaxDepth = 16 },
            timeout.Token).ConfigureAwait(false);
    }

    private static string NormalizePrice(string rawPrice)
    {
        if (!decimal.TryParse(rawPrice, NumberStyles.Float, CultureInfo.InvariantCulture, out decimal price)
            || price <= 0
            || price > 1_000_000_000_000m)
        {
            throw new InvalidDataException("行情价格无效。");
        }
        return price.ToString("0.##################", CultureInfo.InvariantCulture);
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

internal static class BitcoinMath
{
    private static readonly BigInteger BitcoinDisplayScale = new(100_000);

    internal static string ConvertCnyToBitcoin(string cnyDigits, string cnyPerBitcoin)
    {
        if (!BigInteger.TryParse(cnyDigits, NumberStyles.None, CultureInfo.InvariantCulture, out BigInteger cny)
            || cny < 0)
        {
            throw new ArgumentException("人民币金额无效。", nameof(cnyDigits));
        }

        (BigInteger priceUnits, BigInteger priceScale) = ParsePositiveDecimal(cnyPerBitcoin);
        BigInteger numerator = cny * priceScale * BitcoinDisplayScale;
        BigInteger rounded = BigInteger.DivRem(numerator, priceUnits, out BigInteger remainder);
        if ((remainder * 2) >= priceUnits) rounded += BigInteger.One;

        BigInteger whole = BigInteger.DivRem(rounded, BitcoinDisplayScale, out BigInteger fraction);
        return $"{GroupDigits(whole.ToString(CultureInfo.InvariantCulture))}.{fraction.ToString("D5", CultureInfo.InvariantCulture)}";
    }

    internal static string FormatCnyPrice(string price)
    {
        decimal value = decimal.Parse(price, NumberStyles.Float, CultureInfo.InvariantCulture);
        return value.ToString("N2", CultureInfo.InvariantCulture);
    }

    private static (BigInteger Units, BigInteger Scale) ParsePositiveDecimal(string value)
    {
        string[] parts = value.Split('.', 2);
        if (parts.Length is < 1 or > 2
            || parts[0].Length == 0
            || !parts.All(part => part.All(char.IsAsciiDigit)))
        {
            throw new FormatException("BTC/CNY 行情格式无效。");
        }

        string fraction = parts.Length == 2 ? parts[1].TrimEnd('0') : string.Empty;
        if (fraction.Length > 18) fraction = fraction[..18];
        string combined = parts[0] + fraction;
        if (!BigInteger.TryParse(combined, NumberStyles.None, CultureInfo.InvariantCulture, out BigInteger units)
            || units <= 0)
        {
            throw new FormatException("BTC/CNY 行情必须大于零。");
        }

        return (units, BigInteger.Pow(10, fraction.Length));
    }

    private static string GroupDigits(string digits)
    {
        var result = new System.Text.StringBuilder(digits.Length + (digits.Length / 3));
        for (int index = 0; index < digits.Length; index++)
        {
            if (index > 0 && ((digits.Length - index) % 3) == 0) result.Append(',');
            result.Append(digits[index]);
        }
        return result.ToString();
    }
}
