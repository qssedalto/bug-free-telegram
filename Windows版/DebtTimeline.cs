using System.Numerics;

namespace 是否认同;

internal static class DebtTimeline
{
    internal const int DefaultN = 7;
    internal const int MaxTrackedDays = 100_000;
    internal static readonly DateOnly StartDate = new(2023, 6, 19);

    internal static int NForDate(DateOnly date)
    {
        int elapsedDays = date.DayNumber - StartDate.DayNumber;
        int safeDays = Math.Clamp(elapsedDays, 0, MaxTrackedDays);
        return checked(DefaultN + safeDays);
    }
}

internal static class SafeCalculation
{
    internal const int MaximumDigits = 99;
    private static readonly BigInteger MaximumAmount = BigInteger.Pow(10, MaximumDigits) - BigInteger.One;

    internal static AmountDisplay CalculateAmount(int n)
    {
        int safeN = Math.Clamp(n, DebtTimeline.DefaultN, DebtTimeline.DefaultN + DebtTimeline.MaxTrackedDays);
        if (safeN >= 5000)
        {
            string maximumDigits = MaximumAmount.ToString(System.Globalization.CultureInfo.InvariantCulture);
            return new AmountDisplay(maximumDigits, ChineseMoney.ToUppercase(maximumDigits), true);
        }

        // 原式四项统一到分母 20^(n-1)，使用 BigInteger 精确计算，
        // 因此不会发生 Int32、Int64 或浮点数溢出。
        int commonExponent = safeN - 5;
        BigInteger factor = BigInteger.Pow(21, commonExponent);
        BigInteger bracket =
            (686 * BigInteger.Pow(21, 2) * BigInteger.Pow(20, 2))
            + (70 * BigInteger.Pow(21, 4))
            + (49 * 21 * BigInteger.Pow(20, 3))
            + (21 * BigInteger.Pow(20, 4));
        BigInteger numerator = factor * bracket;
        BigInteger denominator = BigInteger.Pow(20, safeN - 1);
        BigInteger rounded = BigInteger.DivRem(numerator, denominator, out BigInteger remainder);

        // 所有值为正；余数达到一半时按原 lround 行为向上取整。
        if ((remainder * 2) >= denominator)
        {
            rounded += BigInteger.One;
        }

        bool isCapped = rounded > MaximumAmount;
        BigInteger displayed = isCapped ? MaximumAmount : rounded;
        string digits = displayed.ToString(System.Globalization.CultureInfo.InvariantCulture);
        return new AmountDisplay(digits, ChineseMoney.ToUppercase(digits), isCapped);
    }
}

internal sealed record AmountDisplay(string Digits, string Chinese, bool IsCapped)
{
    internal string GroupedDigits
    {
        get
        {
            var result = new System.Text.StringBuilder(Digits.Length + (Digits.Length / 3));
            for (int index = 0; index < Digits.Length; index++)
            {
                if (index > 0 && ((Digits.Length - index) % 3) == 0) result.Append(',');
                result.Append(Digits[index]);
            }
            return result.ToString();
        }
    }
}

internal static class ChineseMoney
{
    private static readonly string[] Numerals =
        ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"];
    private static readonly string[] InnerUnits = ["", "十", "百", "千"];
    private static readonly string[] GroupUnits =
    [
        "", "万", "亿", "兆", "京", "垓", "秭", "穰", "沟", "涧", "正", "载", "极",
        "恒河沙", "阿僧祇", "那由他", "不可思议", "无量大数",
        "万无量大数", "亿无量大数", "兆无量大数", "京无量大数",
        "垓无量大数", "秭无量大数", "穰无量大数"
    ];

    internal static string ToUppercase(string digits)
    {
        string normalized = digits.TrimStart('0');
        if (normalized.Length == 0) return "零元";
        if (normalized.Length > SafeCalculation.MaximumDigits)
            throw new ArgumentOutOfRangeException(nameof(digits), "Amount exceeds 99 digits.");

        var groups = new List<int>();
        for (int end = normalized.Length; end > 0;)
        {
            int start = Math.Max(0, end - 4);
            groups.Add(int.Parse(normalized.AsSpan(start, end - start), System.Globalization.CultureInfo.InvariantCulture));
            end = start;
        }

        var result = new System.Text.StringBuilder();
        bool zeroPending = false;
        for (int index = groups.Count - 1; index >= 0; index--)
        {
            int group = groups[index];
            if (group == 0)
            {
                if (result.Length > 0) zeroPending = true;
                continue;
            }

            if (result.Length > 0 && (zeroPending || group < 1000)) result.Append('零');
            result.Append(GroupText(group));
            result.Append(GroupUnits[index]);
            zeroPending = false;
        }
        return result.Append('元').ToString();
    }

    private static string GroupText(int value)
    {
        var result = new System.Text.StringBuilder();
        bool zeroPending = false;
        int[] divisors = [1, 10, 100, 1000];
        for (int position = 3; position >= 0; position--)
        {
            int digit = (value / divisors[position]) % 10;
            if (digit == 0)
            {
                if (result.Length > 0) zeroPending = true;
            }
            else
            {
                if (zeroPending) result.Append('零');
                result.Append(Numerals[digit]);
                result.Append(InnerUnits[position]);
                zeroPending = false;
            }
        }
        return result.ToString();
    }
}
