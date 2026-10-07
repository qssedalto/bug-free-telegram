using System.Text.Json;
using System.Text.Json.Serialization;
using Android.Content;

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
    public int AccentArgb { get; set; } = unchecked((int)0xFFAF52DE);
    public float FontScale { get; set; } = 1F;
    public bool HighContrast { get; set; }
    public bool ReduceMotion { get; set; }
    public bool SoundEnabled { get; set; } = true;
    public bool FullScreenDemo { get; set; }
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

internal static class AppState
{
    private static readonly object Sync = new();
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() }
    };
    private static string _dataDirectory = string.Empty;
    private static string SettingsPath => Path.Combine(_dataDirectory, "settings.json");
    private static string HistoryPath => Path.Combine(_dataDirectory, "history.json");

    internal static AppSettings Settings { get; private set; } = new();
    internal static RuntimeDatabase Database { get; private set; } = new();

    internal static void Initialize(Context context)
    {
        _dataDirectory = context.FilesDir?.AbsolutePath
            ?? throw new InvalidOperationException("Android 应用数据目录不可用。");
        Settings = Load<AppSettings>(SettingsPath, 128 * 1024) ?? new();
        Database = Load<RuntimeDatabase>(HistoryPath, 4 * 1024 * 1024) ?? new();
        MigrateQuestionText();
        InitializeDailyData();
    }

    internal static void InitializeDailyData()
    {
        lock (Sync)
        {
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
            int index = Database.Snapshots.FindIndex(item => item.Date == today);
            var snapshot = new DailySnapshot(today, amount.Digits);
            if (index >= 0) Database.Snapshots[index] = snapshot;
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
            settings.FontScale = Math.Clamp(settings.FontScale, 0.75F, 1.75F);
            Settings = settings;
            Save(SettingsPath, Settings);
        }
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

    private static void SaveDatabase() => Save(HistoryPath, Database);

    private static void Save<T>(string path, T value)
    {
        try
        {
            Directory.CreateDirectory(_dataDirectory);
            string temporary = path + ".tmp";
            File.WriteAllText(temporary, JsonSerializer.Serialize(value, JsonOptions));
            File.Move(temporary, path, true);
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
        }
    }
}

internal static class LocalizedText
{
    internal static string Title(AppSettings settings) =>
        settings.English ? "Questions about A" : settings.WindowTitle;

    internal static string Person(AppSettings settings) =>
        settings.NeutralMode ? (settings.English ? "a fictional character" : "虚构角色") : settings.PersonName;

    internal static string Question(AppSettings settings)
    {
        if (settings.NeutralMode)
            return settings.English
                ? "Do you agree this is an interesting hypothesis?"
                : "是否认同这是一个有趣的假设？";
        if (!string.IsNullOrWhiteSpace(settings.Question)) return settings.Question;
        return settings.English
            ? $"Do you agree with the statement about {Person(settings)}?"
            : $"是否认同关于{Person(settings)}的说法？";
    }

    internal static string[] DailyQuotes(AppSettings settings) => settings.English
        ? ["Every number tells a story.", "Today's choice becomes tomorrow's history.", "Every button remembers a path."]
        :
        [
            "每一个数字都有它的故事。", "今天的选择会成为明天的历史。", "时间每天都在给答案。",
            "别忘了看看今天的金额。", "有些彩蛋只会出现在耐心的人面前。", "三个按钮记得三条不同的时间线。",
            "重复相同选择不一定得到相同故事。", "数据面板里藏着过去，预测页里住着未来。",
            "金额封顶了，想象力没有。", "2023-06-21：档案编号 1111。"
        ];
}
