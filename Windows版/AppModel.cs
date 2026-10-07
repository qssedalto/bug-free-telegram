using System.Numerics;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace 是否认同;

internal enum ThemeMode
{
    System,
    Light,
    Dark,
    PureBlack
}

internal sealed class AppSettings
{
    public DateOnly StartDate { get; set; } = new(2023, 6, 19);
    public string InitialAmount { get; set; } = "1008";
    public string WindowTitle { get; set; } = "对于甲，有一些问题";
    public string Question { get; set; } = "是否认同甲是大傻福？";
    public string PersonName { get; set; } = "焦晨阳";
    public string CustomStoryText { get; set; } = string.Empty;
    public bool English { get; set; }
    public bool NeutralMode { get; set; }
    public ThemeMode Theme { get; set; } = ThemeMode.System;
    public int AccentArgb { get; set; } = Color.FromArgb(175, 82, 222).ToArgb();
    public decimal FontScale { get; set; } = 1m;
    public bool HighContrast { get; set; }
    public bool ReduceMotion { get; set; }
    public bool SoundEnabled { get; set; } = true;
    public bool AlwaysOnTop { get; set; }
    public bool FullScreenDemo { get; set; }
    public int WindowX { get; set; } = -1;
    public int WindowY { get; set; } = -1;
    public int WindowWidth { get; set; } = 1180;
    public int WindowHeight { get; set; } = 820;
    public bool WindowMaximized { get; set; }
}

internal sealed record DailySnapshot(DateOnly Date, string AmountDigits);
internal sealed record ChoiceRecord(DateTimeOffset Time, string Choice, string Result);

internal sealed class RuntimeDatabase
{
    public DateOnly? LastCheckIn { get; set; }
    public int CurrentStreak { get; set; }
    public List<string> Achievements { get; set; } = [];
    public List<DailySnapshot> Snapshots { get; set; } = [];
    public List<ChoiceRecord> Choices { get; set; } = [];
}

internal static class AppServices
{
    private static readonly object Sync = new();
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() }
    };
    private static readonly string DataDirectory = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "TGLab",
        "是否认同");
    private static readonly string SettingsPath = Path.Combine(DataDirectory, "settings.json");
    private static readonly string DatabasePath = Path.Combine(DataDirectory, "history.json");

    internal static AppSettings Settings { get; private set; } = Load<AppSettings>(SettingsPath, 128 * 1024) ?? new();
    internal static RuntimeDatabase Database { get; private set; } = Load<RuntimeDatabase>(DatabasePath, 4 * 1024 * 1024) ?? new();
    internal static event EventHandler? SettingsChanged;
    internal static event EventHandler? StoryReset;

    internal static void InitializeDailyData()
    {
        lock (Sync)
        {
            MigrateQuestionText();
            DateOnly today = DateOnly.FromDateTime(DateTime.Today);
            if (Database.LastCheckIn is DateOnly last)
            {
                int gap = today.DayNumber - last.DayNumber;
                if (gap == 1) Database.CurrentStreak++;
                else if (gap > 1) Database.CurrentStreak = 1;
            }
            else
            {
                Database.CurrentStreak = 1;
            }
            Database.LastCheckIn = today;

            AmountDisplay amount = DebtEngine.AmountForDate(today, Settings);
            int snapshotIndex = Database.Snapshots.FindIndex(item => item.Date == today);
            var snapshot = new DailySnapshot(today, amount.Digits);
            if (snapshotIndex >= 0) Database.Snapshots[snapshotIndex] = snapshot;
            else Database.Snapshots.Add(snapshot);
            Database.Snapshots = Database.Snapshots.OrderBy(item => item.Date).TakeLast(3660).ToList();

            Unlock(Database.CurrentStreak >= 7, "连续七日");
            Unlock(amount.Digits.Length >= 10, "十位数里程碑");
            Unlock(amount.Digits.Length >= 20, "二十位数里程碑");
            SaveDatabase();
        }
    }

    internal static void UpdateSettings(AppSettings settings)
    {
        lock (Sync)
        {
            settings.FontScale = Math.Clamp(settings.FontScale, 0.75m, 1.75m);
            settings.WindowWidth = Math.Clamp(settings.WindowWidth, 920, 6000);
            settings.WindowHeight = Math.Clamp(settings.WindowHeight, 700, 4000);
            Settings = settings;
            Save(SettingsPath, Settings);
        }
        SettingsChanged?.Invoke(null, EventArgs.Empty);
        InitializeDailyData();
    }

    internal static void RecordChoice(string choice, string result)
    {
        lock (Sync)
        {
            Database.Choices.Add(new ChoiceRecord(DateTimeOffset.Now, choice, result));
            Database.Choices = Database.Choices.TakeLast(1000).ToList();
            Unlock(Database.Choices.Count >= 10, "十次选择");
            SaveDatabase();
        }
    }

    internal static void UnlockAchievement(string name)
    {
        lock (Sync)
        {
            Unlock(!string.IsNullOrWhiteSpace(name), name.Trim());
            SaveDatabase();
        }
    }

    internal static void ResetStory()
    {
        lock (Sync)
        {
            Database.Choices.Clear();
            Database.Achievements.Clear();
            Database.CurrentStreak = 1;
            SaveDatabase();
        }
        StoryReset?.Invoke(null, EventArgs.Empty);
    }

    private static void Unlock(bool condition, string name)
    {
        if (condition && !Database.Achievements.Contains(name, StringComparer.Ordinal))
            Database.Achievements.Add(name);
    }

    private static void MigrateQuestionText()
    {
        const string legacyWord = "\u50bb\u903c";
        if (!Settings.Question.Contains(legacyWord, StringComparison.Ordinal)) return;
        Settings.Question = Settings.Question.Replace(legacyWord, "傻福", StringComparison.Ordinal);
        Save(SettingsPath, Settings);
    }

    private static T? Load<T>(string path, long maximumBytes)
    {
        try
        {
            var info = new FileInfo(path);
            if (!info.Exists || info.Length <= 0 || info.Length > maximumBytes) return default;
            return JsonSerializer.Deserialize<T>(File.ReadAllText(path), JsonOptions);
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException or JsonException)
        {
            return default;
        }
    }

    private static void SaveDatabase() => Save(DatabasePath, Database);

    private static void Save<T>(string path, T value)
    {
        try
        {
            Directory.CreateDirectory(DataDirectory);
            string temp = path + ".tmp";
            File.WriteAllText(temp, JsonSerializer.Serialize(value, JsonOptions));
            File.Move(temp, path, true);
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
        }
    }
}

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

internal static class LocalizedText
{
    internal static string Title(AppSettings settings) => settings.English ? "Developer's Question" : settings.WindowTitle;
    internal static string Person(AppSettings settings) => settings.NeutralMode ? (settings.English ? "a fictional character" : "虚构角色") : settings.PersonName;
    internal static string Question(AppSettings settings)
    {
        if (settings.NeutralMode) return settings.English ? "Do you agree this is an interesting hypothesis?" : "是否认同这是一个有趣的假设？";
        if (!string.IsNullOrWhiteSpace(settings.Question)) return settings.Question;
        return settings.English ? $"Do you agree with the statement about {Person(settings)}?" : $"是否认同关于{Person(settings)}的说法？";
    }

    internal static string[] DailyQuotes(AppSettings settings) => settings.English
        ? ["Every number tells a story.", "Today's choice becomes tomorrow's history.", "Reality grows one day at a time.", "Every button remembers a different path.", "Some archives only open after the third visit."]
        :
        [
            "每一个数字都有它的故事。", "今天的选择会成为明天的历史。", "时间每天都在给答案。",
            "别忘了看看今天的金额。", "有些彩蛋只会出现在耐心的人面前。", "三个按钮记得三条不同的时间线。",
            "标题好像可以点击，而且不止一次。", "红色路线危险，但它的结局最多。", "绿色按钮偶尔会说出自己是按钮。",
            "温和地认同，也能打开一座档案室。", "试着双击这句话，也许它还有背面。", "F11 属于舞台，F12 属于秘密。",
            "重复相同选择并不一定得到相同故事。", "第十二次选择之后，时间线会记住你。", "倒计时也许经不起连续敲击。",
            "迷你窗口开得太多，也会形成一个小小的宇宙。", "历史记录不会评价你的答案，只负责记住。", "金额封顶了，想象力没有。",
            "有时随机彩蛋会先找到你。", "2023-06-21：档案编号 1111。", "圆角之内，剧情仍在继续。",
            "每次逃离都可能从一扇不同的门结束。", "数据面板里藏着过去，预测页里住着未来。", "复制一个数字，也等于带走一份证据。"
        ];
}
