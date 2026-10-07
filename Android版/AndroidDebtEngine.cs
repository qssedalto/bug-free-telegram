using System.Numerics;

namespace 是否认同;

internal static class DebtEngine
{
    internal static int DaysForDate(DateOnly date, AppSettings settings) =>
        Math.Clamp(date.DayNumber - settings.StartDate.DayNumber, 0, DebtTimeline.MaxTrackedDays);

    internal static AmountDisplay AmountForDate(DateOnly date, AppSettings settings)
    {
        int days = DaysForDate(date, settings);
        if (settings.InitialAmount == "1008")
            return SafeCalculation.CalculateAmount(DebtTimeline.DefaultN + days);

        if (!TryParseInitialAmount(settings.InitialAmount, out BigInteger initialUnits, out BigInteger decimalScale))
            return SafeCalculation.CalculateAmount(DebtTimeline.DefaultN + days);

        if (days >= 5000) return SafeCalculation.CalculateAmount(int.MaxValue);
        BigInteger numerator = initialUnits * BigInteger.Pow(21, days);
        BigInteger denominator = decimalScale * BigInteger.Pow(20, days);
        BigInteger rounded = BigInteger.DivRem(numerator, denominator, out BigInteger remainder);
        if ((remainder * 2) >= denominator) rounded += BigInteger.One;
        string digits = rounded.ToString(System.Globalization.CultureInfo.InvariantCulture);
        if (digits.Length > SafeCalculation.MaximumDigits) return SafeCalculation.CalculateAmount(int.MaxValue);
        return new AmountDisplay(digits, ChineseMoney.ToUppercase(digits), false);
    }

    internal static double Log10ForChart(AmountDisplay amount)
    {
        string digits = amount.Digits;
        int take = Math.Min(15, digits.Length);
        double leading = double.Parse(digits[..take], System.Globalization.CultureInfo.InvariantCulture);
        return Math.Log10(leading) + digits.Length - take;
    }

    private static bool TryParseInitialAmount(string text, out BigInteger units, out BigInteger scale)
    {
        units = BigInteger.Zero;
        scale = BigInteger.One;
        string[] parts = text.Trim().Split('.', 2);
        if (parts.Length is < 1 or > 2 || parts.Any(part => !part.All(char.IsAsciiDigit))) return false;
        string fraction = parts.Length == 2 ? parts[1] : string.Empty;
        if (fraction.Length > 8) fraction = fraction[..8];
        if (!BigInteger.TryParse(parts[0] + fraction, out units) || units <= 0) return false;
        scale = BigInteger.Pow(10, fraction.Length);
        return true;
    }
}
