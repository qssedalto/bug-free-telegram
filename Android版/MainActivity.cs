using System.Globalization;
using Android.App;
using Android.Content;
using Android.Content.PM;
using Android.Content.Res;
using Android.Graphics;
using Android.Graphics.Drawables;
using Android.OS;
using Android.Text;
using Android.Views;
using Android.Views.InputMethods;
using Android.Widget;

namespace 是否认同;

[Activity(
    Label = "@string/app_name",
    MainLauncher = true,
    Exported = true,
    ConfigurationChanges = ConfigChanges.Orientation | ConfigChanges.ScreenSize | ConfigChanges.UiMode)]
public sealed class MainActivity : Activity
{
    private AppPalette _palette = null!;
    private AmountDisplay _amount = null!;
    private readonly Dictionary<string, int> _branchCounts = new(StringComparer.Ordinal);
    private readonly Queue<string> _recentBranches = new();
    private readonly HashSet<string> _sessionEggs = new(StringComparer.Ordinal);
    private int _titleClicks;
    private int _miniClicks;
    private long _lastQuoteTap;

    private bool IsTablet => (Resources?.Configuration?.SmallestScreenWidthDp ?? 0) >= 600;

    protected override void OnCreate(Bundle? savedInstanceState)
    {
        base.OnCreate(savedInstanceState);
        AppState.Initialize(this);
        RefreshAmount();
        ApplyFullScreen();
        Render();
    }

    public override void OnConfigurationChanged(Configuration newConfig)
    {
        base.OnConfigurationChanged(newConfig);
        Render();
    }

    private void RefreshAmount() =>
        _amount = DebtEngine.AmountForDate(DateOnly.FromDateTime(DateTime.Today), AppState.Settings);

    private void Render()
    {
        RefreshAmount();
        _palette = AppPalette.Create(this, AppState.Settings);
        ApplySystemBars();

        var scroll = new ScrollView(this)
        {
            FillViewport = true,
            Background = new ColorDrawable(_palette.Background)
        };
        var content = Ui.VBox(this);
        int edge = Ui.Dp(this, IsTablet ? 28 : 16);
        content.SetPadding(edge, Ui.Dp(this, 18), edge, Ui.Dp(this, 28));

        TextView title = Ui.Text(this, _palette, LocalizedText.Title(AppState.Settings), IsTablet ? 30 : 25, true);
        title.SetPadding(Ui.Dp(this, 5), Ui.Dp(this, 4), Ui.Dp(this, 5), Ui.Dp(this, 6));
        title.Click += (_, _) => CheckTitleEgg();
        content.AddView(title, MatchWrap());

        LinearLayout status = Ui.HBox(this);
        status.AddView(StatusChip("● 已保存"), Weighted());
        status.AddView(StatusChip("行情按需"), Weighted());
        status.AddView(StatusChip(ThemeLabel()), Weighted());
        Ui.AddWithMargin(content, status, 4);

        LinearLayout tools = Ui.HBox(this);
        tools.AddView(ToolButton("金额", (_, _) => ShowMiniAmount()), Weighted(4));
        tools.AddView(ToolButton("数据", (_, _) => ShowDataDashboard()), Weighted(4));
        tools.AddView(ToolButton("设置", (_, _) => ShowSettings()), Weighted(4));
        tools.AddView(ToolButton("全屏", (_, _) => ToggleFullScreen()), Weighted(4));
        Ui.AddWithMargin(content, tools, 8);

        LinearLayout questionCard = Ui.Card(this, _palette, IsTablet ? 26 : 20);
        questionCard.AddView(Ui.Text(this, _palette, "今日问题  ·  请选择一条时间线", 13, true, GravityFlags.Center), MatchWrap());
        TextView question = Ui.Text(this, _palette, LocalizedText.Question(AppState.Settings), IsTablet ? 25 : 21, true, GravityFlags.Center);
        question.SetPadding(0, Ui.Dp(this, 18), 0, Ui.Dp(this, 10));
        questionCard.AddView(question, MatchWrap());
        Ui.AddWithMargin(content, questionCard, 14);

        LinearLayout routes = new(this)
        {
            Orientation = IsTablet ? Android.Widget.Orientation.Horizontal : Android.Widget.Orientation.Vertical
        };
        routes.SetGravity(GravityFlags.Top);
        AddRoute(routes, "档案调查路线", "调查金额档案与随机记录", "认同", Color.Rgb(10, 132, 255), "认同", ShowAgreeRoute);
        AddRoute(routes, "共振与同盟路线", "进入多阶段观点共振剧情", "非常认同", Color.Rgb(48, 209, 88), "非常认同", ShowStrongAgreeRoute);
        AddRoute(routes, "警报与逃离路线", "触发倒计时与随机逃离结局", "不认同", Color.Rgb(255, 69, 58), "不认同", ShowWarningRoute);
        Ui.AddWithMargin(content, routes, 4);

        LinearLayout amountCard = Ui.Card(this, _palette);
        amountCard.AddView(Ui.Text(this, _palette, "今日欠款", 15, true), MatchWrap());
        TextView amountText = Ui.Text(this, _palette, $"￥{_amount.GroupedDigits} 元", IsTablet ? 23 : 18, true);
        amountText.SetTextColor(_palette.Accent);
        amountText.SetPadding(0, Ui.Dp(this, 10), 0, 0);
        amountCard.AddView(amountText, MatchWrap());
        amountCard.Click += (_, _) => ShowMiniAmount();
        Ui.AddWithMargin(content, amountCard, 10);

        LinearLayout trendCard = Ui.Card(this, _palette);
        trendCard.AddView(Ui.Text(this, _palette, "近七日增长  ·  点击查看完整图表", 15, true), MatchWrap());
        var trend = new TrendView(this);
        var points = new List<double>();
        DateOnly today = DateOnly.FromDateTime(DateTime.Today);
        for (int day = 6; day >= 0; day--)
            points.Add(DebtEngine.Log10ForChart(DebtEngine.AmountForDate(today.AddDays(-day), AppState.Settings)));
        trend.SetPoints(points, _palette.Accent, "7 日前", "今天");
        trendCard.AddView(trend, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MatchParent, Ui.Dp(this, 155)));
        trendCard.Click += (_, _) => ShowDataDashboard();
        Ui.AddWithMargin(content, trendCard, 10);

        AddHomeInformation(content);

        string[] quotes = LocalizedText.DailyQuotes(AppState.Settings);
        string quoteText = quotes[DateTime.Today.DayOfYear % quotes.Length];
        if (DateTime.Today.Month == 6 && DateTime.Today.Day == 19)
            quoteText = "锚点日彩蛋：今天是 n = 7 的起始纪念日。";
        else if (DateTime.Today.Month == 6 && DateTime.Today.Day == 21)
            quoteText = "1111 彩蛋：原始时间线中的金额为 ￥1,111。";
        TextView quote = Ui.Text(this, _palette, quoteText + "\n\n轻点两次查看台词背面", 13, false, GravityFlags.Center);
        quote.SetPadding(Ui.Dp(this, 12), Ui.Dp(this, 18), Ui.Dp(this, 12), Ui.Dp(this, 18));
        quote.Click += (_, _) => CheckQuoteDoubleTap();
        content.AddView(quote, MatchWrap());

        TextView copyright = Ui.Text(this, _palette, "© 天国智造 · TGLab", 12, true, GravityFlags.Center);
        copyright.SetTextColor(_palette.Secondary);
        content.AddView(copyright, MatchWrap());

        scroll.AddView(content);
        SetContentView(scroll);
    }

    private void AddRoute(
        LinearLayout parent,
        string title,
        string description,
        string branch,
        Color color,
        string buttonText,
        Action action)
    {
        LinearLayout card = Ui.Card(this, _palette, 16);
        card.AddView(Ui.Text(this, _palette, title, 16, true), MatchWrap());
        TextView descriptionView = Ui.Text(this, _palette, description, 12);
        descriptionView.SetTextColor(_palette.Secondary);
        card.AddView(descriptionView, MatchWrap(4));
        int sessionCount = _branchCounts.GetValueOrDefault(branch);
        string status = sessionCount == 0 ? "本次尚未进入" : $"本次已进入 {sessionCount:N0} 次";
        if (branch == "不认同" && sessionCount > 0) status += " · 第四次有隐藏路线";
        TextView statusView = Ui.Text(this, _palette, status, 11);
        statusView.SetTextColor(_palette.Secondary);
        card.AddView(statusView, MatchWrap(4));
        Button button = Ui.Button(this, _palette, AppState.Settings.English ? EnglishBranch(branch) : buttonText, color);
        button.Click += (_, _) => action();
        card.AddView(button, MatchWrap(8));
        card.Click += (_, _) => action();

        LinearLayout.LayoutParams parameters = IsTablet
            ? new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WrapContent, 1F)
            : MatchWrap();
        parameters.SetMargins(Ui.Dp(this, 4), Ui.Dp(this, 6), Ui.Dp(this, 4), Ui.Dp(this, 6));
        parent.AddView(card, parameters);
    }

    private void AddHomeInformation(LinearLayout content)
    {
        DateOnly today = DateOnly.FromDateTime(DateTime.Today);
        int elapsed = DebtEngine.DaysForDate(today, AppState.Settings) + 1;
        AddInfoCard(content, "📁  今日档案", $"{today:yyyy年MM月dd日}\n运行第 {elapsed:N0} 天  ·  连续签到 {AppState.Database.CurrentStreak} 天");

        int agree = AppState.Database.Choices.Count(item => item.Choice == "认同");
        int strong = AppState.Database.Choices.Count(item => item.Choice == "非常认同");
        int disagree = AppState.Database.Choices.Count(item => item.Choice == "不认同");
        LinearLayout progressCard = Ui.Card(this, _palette);
        progressCard.AddView(Ui.Text(this, _palette, "🧭  路线探索进度", 15, true), MatchWrap());
        AddProgress(progressCard, "蓝色档案路线", agree, StoryContent.AgreeCombinationCount, Color.Rgb(10, 132, 255));
        AddProgress(progressCard, "绿色同盟路线", strong, StoryContent.StrongAgreeCombinationCount, Color.Rgb(48, 209, 88));
        AddProgress(progressCard, "红色逃离路线", disagree, StoryContent.WarningCombinationCount, Color.Rgb(255, 69, 58));
        Ui.AddWithMargin(content, progressCard, 10);

        ChoiceRecord? recent = AppState.Database.Choices.LastOrDefault();
        AddInfoCard(content, "🕘  最近选择", recent is null
            ? "还没有选择记录。按下任意剧情按钮开始第一条时间线。"
            : $"{recent.Time:MM-dd HH:mm}  {recent.Choice}\n{Limit(recent.Result, 90)}", ShowDataDashboard);

        string[] achievements = AppState.Database.Achievements.TakeLast(5).ToArray();
        AddInfoCard(content, "🏆  成就陈列架", achievements.Length == 0
            ? "尚未解锁成就。连续选择、探索标题与日期会留下线索。"
            : string.Join("  ·  ", achievements.Select(item => "◆ " + item)) + $"\n已解锁 {AppState.Database.Achievements.Count} 项", ShowDataDashboard);
    }

    private void AddInfoCard(LinearLayout parent, string title, string body, Action? action = null)
    {
        LinearLayout card = Ui.Card(this, _palette);
        card.AddView(Ui.Text(this, _palette, title, 15, true), MatchWrap());
        TextView bodyView = Ui.Text(this, _palette, body, 13);
        bodyView.SetPadding(0, Ui.Dp(this, 8), 0, 0);
        card.AddView(bodyView, MatchWrap());
        if (action is not null) card.Click += (_, _) => action();
        Ui.AddWithMargin(parent, card, 10);
    }

    private void AddProgress(LinearLayout parent, string title, int value, int maximum, Color color)
    {
        TextView label = Ui.Text(this, _palette, $"{title}  {value:N0} / {maximum:N0}", 12, true);
        parent.AddView(label, MatchWrap(8));
        var bar = new ProgressBar(this, null, Android.Resource.Attribute.ProgressBarStyleHorizontal)
        {
            Max = maximum,
            Progress = Math.Min(value, maximum)
        };
        parent.AddView(bar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MatchParent, Ui.Dp(this, 12)));
    }

    private void ShowAgreeRoute()
    {
        RegisterBranch("认同");
        AgreeStory story = StoryContent.NextAgree(AppState.Settings);
        AppState.RecordChoice("认同", story.Title);
        Render();
        ShowActionDialog(story.Title, story.Prelude, story.FirstButtonText, () => ShowAgreeDetails(story));
    }

    private void ShowAgreeDetails(AgreeStory story)
    {
        AppPalette palette = AppPalette.Create(this, AppState.Settings);
        LinearLayout body = Ui.VBox(this);
        body.AddView(Ui.Text(this, palette, story.DetailIntroduction, 15, true), MatchWrap());
        TextView amount = Ui.Text(this, palette, $"￥{_amount.GroupedDigits} 元", IsTablet ? 24 : 18, true, GravityFlags.Center);
        amount.SetTextColor(palette.Accent);
        body.AddView(amount, MatchWrap(16));
        TextView bitcoin = Ui.Text(this, palette, "相当于：等待获取实时比特币行情…", 15, true, GravityFlags.Center);
        body.AddView(bitcoin, MatchWrap(8));

        LinearLayout copyRow = Ui.HBox(this);
        Button copyCny = Ui.Button(this, palette, "复制人民币");
        Button copyBtc = Ui.Button(this, palette, "复制 BTC");
        copyBtc.Enabled = false;
        copyCny.Click += (_, _) => CopyToClipboard("人民币", $"￥{_amount.GroupedDigits} 元");
        copyRow.AddView(copyCny, Weighted(8));
        copyRow.AddView(copyBtc, Weighted(8));
        body.AddView(copyRow, MatchWrap(8));

        string capped = _amount.IsCapped ? "\n（金额已达到 99 位上限）" : string.Empty;
        body.AddView(Ui.Text(this, palette, $"人民币：{_amount.Chinese}{capped}\n\n{story.Acknowledgement}", 14), MatchWrap(12));

        (Dialog dialog, LinearLayout actions) = CreateDialogFrame(story.Title, body, palette);
        Button finish = Ui.Button(this, palette, story.RevealButtonText);
        finish.Click += (_, _) =>
        {
            dialog.Dismiss();
            AppState.RecordChoice("认同结尾", story.Epilogue);
            Render();
            ShowActionDialog(story.Title, story.Epilogue, "关闭", null);
        };
        actions.AddView(finish, Weighted());
        Button close = Ui.Button(this, palette, "稍后", palette.Secondary);
        close.Click += (_, _) => dialog.Dismiss();
        actions.AddView(close, Weighted(8));

        CancellationTokenSource cancellation = new();
        dialog.DismissEvent += (_, _) => cancellation.Cancel();
        _ = LoadBitcoinAsync(bitcoin, copyBtc, cancellation.Token);
        return;

        async Task LoadBitcoinAsync(TextView target, Button copyButton, CancellationToken token)
        {
            try
            {
                BitcoinQuote quote = await BitcoinQuoteService.GetAsync(token);
                string value = BitcoinMath.ConvertCnyToBitcoin(_amount.Digits, quote.CnyPerBitcoin);
                RunOnUiThread(() =>
                {
                    if (dialog.IsShowing)
                    {
                        target.Text = $"相当于：{value} BTC";
                        copyButton.Enabled = true;
                        copyButton.Click += (_, _) => CopyToClipboard("BTC", value + " BTC");
                    }
                });
            }
            catch (System.OperationCanceledException)
            {
            }
            catch
            {
                RunOnUiThread(() =>
                {
                    if (dialog.IsShowing) target.Text = "比特币估值暂不可用，请检查网络后重试";
                });
            }
        }
    }

    private void ShowStrongAgreeRoute()
    {
        RegisterBranch("非常认同");
        StorySequence story = StoryContent.NextStrongAgree(AppState.Settings);
        IReadOnlyList<string> lines = string.IsNullOrWhiteSpace(AppState.Settings.CustomStoryText)
            ? story.Lines
            : story.Lines.Concat([AppState.Settings.CustomStoryText]).ToArray();
        AppState.RecordChoice("非常认同", story.Result);
        Render();
        ShowStrongStage(story, lines, 0);
    }

    private void ShowStrongStage(StorySequence story, IReadOnlyList<string> lines, int index)
    {
        if (index >= lines.Count) return;
        string button = index == lines.Count - 1 ? "结束" : index == 0 ? story.ButtonText : "继续";
        ShowActionDialog(story.Title, lines[index], button,
            index == lines.Count - 1 ? null : () => ShowStrongStage(story, lines, index + 1));
    }

    private void ShowWarningRoute()
    {
        int count = RegisterBranch("不认同");
        bool secret = count > 0 && count % 4 == 0;
        WarningStory story = StoryContent.NextWarning(AppState.Settings, LocalizedText.Person(AppState.Settings), secret);
        AppState.RecordChoice("不认同", story.Title);
        Render();
        ShowWarningDialog(story);
    }

    private void ShowWarningDialog(WarningStory story)
    {
        var warningPalette = new AppPalette(
            Color.Rgb(190, 35, 44), Color.Rgb(220, 45, 54), Color.White,
            Color.Rgb(255, 220, 220), Color.Rgb(255, 125, 128), Color.Rgb(175, 82, 222), true);
        LinearLayout body = Ui.VBox(this);
        body.AddView(Ui.Text(this, warningPalette, story.Prompt, 16, true, GravityFlags.Center), MatchWrap());
        TextView countdown = Ui.Text(this, warningPalette, "逃离倒计时：10 秒", 20, true, GravityFlags.Center);
        TextView result = Ui.Text(this, warningPalette, string.Empty, 15, false, GravityFlags.Center);
        body.AddView(countdown, MatchWrap(18));
        body.AddView(result, MatchWrap(12));
        (Dialog dialog, LinearLayout actions) = CreateDialogFrame(story.Title, body, warningPalette);
        Button escape = Ui.Button(this, warningPalette, "逃离");
        actions.AddView(escape, Weighted());

        int seconds = 10;
        int clicks = 0;
        bool finished = false;
        System.Threading.Timer? timer = null;

        void Finish(string text)
        {
            if (finished) return;
            finished = true;
            timer?.Dispose();
            countdown.Text = "警报已解除";
            result.Text = text;
            escape.Text = "关闭";
            AppState.RecordChoice("逃离结果", text);
        }

        escape.Click += (_, _) =>
        {
            if (finished) { dialog.Dismiss(); Render(); return; }
            Finish(story.EscapeResults[Random.Shared.Next(story.EscapeResults.Count)]);
        };
        countdown.Click += (_, _) =>
        {
            clicks++;
            if (clicks != 4 || finished) return;
            seconds += 5;
            countdown.Text = $"隐藏加时：{seconds} 秒";
            result.Text = "你敲了四次倒计时，系统偷偷多给了五秒。";
            AppState.UnlockAchievement("倒计时操纵者");
            AppState.RecordChoice("警告彩蛋", "获得五秒隐藏加时");
        };
        timer = new System.Threading.Timer(_ => RunOnUiThread(() =>
        {
            if (!dialog.IsShowing || finished) return;
            seconds--;
            countdown.Text = $"逃离倒计时：{Math.Max(0, seconds)} 秒";
            if (seconds <= 0) Finish("倒计时结束，系统自动为你选择了一条逃离路线。");
        }), null, 1000, 1000);
        dialog.DismissEvent += (_, _) => timer.Dispose();
    }

    private void ShowMiniAmount()
    {
        _miniClicks++;
        float size = _amount.Digits.Length switch { > 70 => 13, > 45 => 15, > 28 => 17, _ => 22 };
        if (_miniClicks == 3)
            UnlockAndShow("窗口收藏家", "你连续打开了三个迷你金额窗口。金额观测站已记录这件事。");
        ShowActionDialog("欠款迷你窗口", $"￥{_amount.GroupedDigits} 元", "关闭", null, size);
    }

    private void ShowDataDashboard()
    {
        DateOnly today = DateOnly.FromDateTime(DateTime.Today);
        string Compare(int days) => DebtEngine.AmountForDate(today.AddDays(-days), AppState.Settings).GroupedDigits;
        string Predict(int days) => DebtEngine.AmountForDate(today.AddDays(days), AppState.Settings).GroupedDigits;
        int elapsed = DebtEngine.DaysForDate(today, AppState.Settings) + 1;

        LinearLayout body = Ui.VBox(this);
        body.AddView(Ui.Text(this, _palette,
            $"概览\n\n当前运行：{elapsed:N0} 天\n公式：初始金额 × 1.05 ^ 经过天数\n按元四舍五入，最高 99 位\n\n" +
            $"当前：￥{_amount.GroupedDigits}\n昨日：￥{Compare(1)}\n七日前：￥{Compare(7)}\n三十日前：￥{Compare(30)}\n\n" +
            $"明日预测：￥{Predict(1)}\n一周后：￥{Predict(7)}\n一年后：￥{Predict(365)}", 14, true), MatchWrap());

        body.AddView(Ui.Text(this, _palette, "\n增长折线图（最近 30 天，对数刻度）", 16, true), MatchWrap());
        var chart = new TrendView(this);
        var points = new List<double>();
        for (int day = 30; day >= 0; day--)
            points.Add(DebtEngine.Log10ForChart(DebtEngine.AmountForDate(today.AddDays(-day), AppState.Settings)));
        chart.SetPoints(points, _palette.Accent, today.AddDays(-30).ToString("MM-dd"), today.ToString("MM-dd"));
        body.AddView(chart, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MatchParent, Ui.Dp(this, 210)));

        TextView markets = Ui.Text(this, _palette, "正在获取美元、欧元、日元、港币和黄金行情…", 14, true);
        body.AddView(markets, MatchWrap(14));

        string achievements = string.Join("、", AppState.Database.Achievements.DefaultIfEmpty("暂无"));
        string history = string.Join("\n", AppState.Database.Choices.OrderByDescending(item => item.Time).Take(100)
            .Select(item => $"{item.Time:yyyy-MM-dd HH:mm}  {item.Choice} → {item.Result}"));
        body.AddView(Ui.Text(this, _palette,
            $"\n历史与成就\n\n连续签到：{AppState.Database.CurrentStreak} 天\n成就：{achievements}\n\n—— 最近选择 ——\n{(history.Length == 0 ? "暂无" : history)}", 13), MatchWrap());

        Button reset = Ui.Button(this, _palette, "重新开始剧情");
        body.AddView(reset, MatchWrap(18));
        (Dialog dialog, LinearLayout actions) = CreateDialogFrame("数据面板", body, _palette);
        Button close = Ui.Button(this, _palette, "关闭");
        close.Click += (_, _) => dialog.Dismiss();
        actions.AddView(close, Weighted());
        reset.Click += (_, _) =>
        {
            AppState.ResetStory();
            _branchCounts.Clear();
            _recentBranches.Clear();
            _sessionEggs.Clear();
            dialog.Dismiss();
            Render();
            Toast.MakeText(this, "剧情、成就和路线进度已重新开始", ToastLength.Long)?.Show();
        };
        _ = LoadMarketConversionsAsync();

        async Task LoadMarketConversionsAsync()
        {
            try
            {
                MarketConversions rates = await MarketConversionService.GetAsync(CancellationToken.None);
                string usd = ArbitraryMoneyMath.Multiply(_amount.Digits, rates.FiatPerCny["USD"], 2);
                string eur = ArbitraryMoneyMath.Multiply(_amount.Digits, rates.FiatPerCny["EUR"], 2);
                string jpy = ArbitraryMoneyMath.Multiply(_amount.Digits, rates.FiatPerCny["JPY"], 2);
                string hkd = ArbitraryMoneyMath.Multiply(_amount.Digits, rates.FiatPerCny["HKD"], 2);
                string gold = rates.GoldCnyPerGram is null
                    ? "暂不可用"
                    : ArbitraryMoneyMath.DivideByIntegerFactor(_amount.Digits, rates.GoldCnyPerGram, 1_000_000, 6) + " 吨";
                RunOnUiThread(() =>
                {
                    if (dialog.IsShowing)
                        markets.Text = $"多币种实时估值\n美元：${usd}\n欧元：€{eur}\n日元：¥{jpy}\n港币：HK${hkd}\n黄金重量：{gold}\n行情源：{rates.Source}";
                });
            }
            catch
            {
                RunOnUiThread(() => { if (dialog.IsShowing) markets.Text = "多币种行情暂不可用，请检查网络。"; });
            }
        }
    }

    private void ShowSettings()
    {
        AppSettings current = AppState.Settings;
        LinearLayout body = Ui.VBox(this);
        EditText startDate = AddInput(body, "起始日期（yyyy-MM-dd）", current.StartDate.ToString("yyyy-MM-dd"));
        EditText initial = AddInput(body, "初始金额（元）", current.InitialAmount, InputTypes.ClassNumber | InputTypes.NumberFlagDecimal);
        EditText title = AddInput(body, "窗口标题", current.WindowTitle);
        EditText question = AddInput(body, "问题文字", current.Question);
        EditText person = AddInput(body, "人物名称", current.PersonName);
        EditText custom = AddInput(body, "自定义剧情文字", current.CustomStoryText);
        custom.SetMinLines(3);

        TextView themeLabel = Ui.Text(this, _palette, "主题", 13, true);
        body.AddView(themeLabel, MatchWrap(12));
        Spinner theme = new(this);
        string[] themes = ["跟随系统", "浅色", "深色", "纯黑"];
        theme.Adapter = new ArrayAdapter<string>(this, Android.Resource.Layout.SimpleSpinnerDropDownItem, themes);
        theme.SetSelection((int)current.Theme);
        body.AddView(theme, MatchWrap());

        TextView accentLabel = Ui.Text(this, _palette, "强调色", 13, true);
        body.AddView(accentLabel, MatchWrap(12));
        Spinner accent = new(this);
        string[] accents = ["紫色", "蓝色", "青色", "橙色", "粉色"];
        int[] accentColors =
        [
            unchecked((int)0xFFAF52DE), unchecked((int)0xFF0A84FF), unchecked((int)0xFF00A6A6),
            unchecked((int)0xFFFF9500), unchecked((int)0xFFFF2D55)
        ];
        accent.Adapter = new ArrayAdapter<string>(this, Android.Resource.Layout.SimpleSpinnerDropDownItem, accents);
        int accentIndex = Array.IndexOf(accentColors, current.AccentArgb);
        accent.SetSelection(accentIndex < 0 ? 0 : accentIndex);
        body.AddView(accent, MatchWrap());

        TextView fontLabel = Ui.Text(this, _palette, $"字号缩放：{current.FontScale * 100:F0}%", 13, true);
        body.AddView(fontLabel, MatchWrap(12));
        SeekBar font = new(this) { Max = 100, Progress = (int)(current.FontScale * 100) - 75 };
        font.ProgressChanged += (_, e) => fontLabel.Text = $"字号缩放：{e.Progress + 75}%";
        body.AddView(font, MatchWrap());

        Switch highContrast = AddSwitch(body, "高对比度", current.HighContrast);
        Switch reduceMotion = AddSwitch(body, "减少动画", current.ReduceMotion);
        Switch sound = AddSwitch(body, "启用音效", current.SoundEnabled);
        Switch fullScreen = AddSwitch(body, "全屏演示", current.FullScreenDemo);
        Switch english = AddSwitch(body, "英文主界面", current.English);
        Switch neutral = AddSwitch(body, "中性/虚构角色模式", current.NeutralMode);

        body.AddView(Ui.Text(this, _palette, "© 天国智造 · TGLab", 13, true, GravityFlags.Center), MatchWrap(18));
        (Dialog dialog, LinearLayout actions) = CreateDialogFrame("设置", body, _palette);
        Button cancel = Ui.Button(this, _palette, "取消", _palette.Secondary);
        cancel.Click += (_, _) => dialog.Dismiss();
        Button save = Ui.Button(this, _palette, "保存");
        actions.AddView(cancel, Weighted(8));
        actions.AddView(save, Weighted(8));
        save.Click += (_, _) =>
        {
            if (!DateOnly.TryParseExact(startDate.Text?.Trim(), "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out DateOnly parsedDate))
            {
                startDate.Error = "请输入 yyyy-MM-dd 格式的日期";
                return;
            }
            if (!decimal.TryParse(initial.Text, NumberStyles.Number, CultureInfo.InvariantCulture, out decimal parsedAmount) || parsedAmount <= 0)
            {
                initial.Error = "初始金额必须是大于零的数字";
                return;
            }
            var updated = new AppSettings
            {
                StartDate = parsedDate,
                InitialAmount = parsedAmount.ToString(CultureInfo.InvariantCulture),
                WindowTitle = LimitOrFallback(title.Text, 80, "对于甲，有一些问题"),
                Question = LimitOrFallback(question.Text, 160, "是否认同甲是大傻福？"),
                PersonName = LimitOrFallback(person.Text, 40, "虚构角色"),
                CustomStoryText = LimitOrFallback(custom.Text, 1000, string.Empty),
                Theme = (ThemeMode)theme.SelectedItemPosition,
                AccentArgb = accentColors[Math.Clamp(accent.SelectedItemPosition, 0, accentColors.Length - 1)],
                FontScale = (font.Progress + 75) / 100F,
                HighContrast = highContrast.Checked,
                ReduceMotion = reduceMotion.Checked,
                SoundEnabled = sound.Checked,
                FullScreenDemo = fullScreen.Checked,
                English = english.Checked,
                NeutralMode = neutral.Checked
            };
            AppState.UpdateSettings(updated);
            dialog.Dismiss();
            ApplyFullScreen();
            Render();
        };
    }

    private EditText AddInput(LinearLayout body, string label, string value, InputTypes inputType = InputTypes.ClassText)
    {
        body.AddView(Ui.Text(this, _palette, label, 13, true), MatchWrap(12));
        var input = new EditText(this)
        {
            Text = value,
            InputType = inputType,
            BackgroundTintList = Android.Content.Res.ColorStateList.ValueOf(_palette.Accent)
        };
        input.SetTextColor(_palette.Foreground);
        input.SetHintTextColor(_palette.Secondary);
        input.SetTextSize(Android.Util.ComplexUnitType.Sp, 15F * AppState.Settings.FontScale);
        body.AddView(input, MatchWrap());
        return input;
    }

    private Switch AddSwitch(LinearLayout body, string label, bool value)
    {
        var toggle = new Switch(this) { Text = label, Checked = value };
        toggle.SetTextColor(_palette.Foreground);
        toggle.SetTextSize(Android.Util.ComplexUnitType.Sp, 14F * AppState.Settings.FontScale);
        body.AddView(toggle, MatchWrap(10));
        return toggle;
    }

    private void ShowActionDialog(string title, string message, string buttonText, Action? action, float messageSize = 16)
    {
        LinearLayout body = Ui.VBox(this);
        body.AddView(Ui.Text(this, _palette, message, messageSize, true, GravityFlags.Center), MatchWrap(10));
        (Dialog dialog, LinearLayout actions) = CreateDialogFrame(title, body, _palette);
        Button button = Ui.Button(this, _palette, buttonText);
        button.Click += (_, _) =>
        {
            dialog.Dismiss();
            action?.Invoke();
        };
        actions.AddView(button, Weighted());
    }

    private (Dialog Dialog, LinearLayout Actions) CreateDialogFrame(string title, LinearLayout body, AppPalette palette)
    {
        var root = Ui.VBox(this);
        int padding = Ui.Dp(this, IsTablet ? 26 : 18);
        root.SetPadding(padding, padding, padding, padding);
        root.Background = Ui.Rounded(palette.Card, 24, this, palette.Border);
        TextView heading = Ui.Text(this, palette, title, IsTablet ? 24 : 20, true, GravityFlags.Center);
        root.AddView(heading, MatchWrap());

        var scroll = new ScrollView(this) { FillViewport = true };
        body.SetPadding(0, Ui.Dp(this, 14), 0, Ui.Dp(this, 10));
        scroll.AddView(body);
        root.AddView(scroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MatchParent, 0, 1F));
        LinearLayout actions = Ui.HBox(this);
        root.AddView(actions, MatchWrap(10));

        var dialog = new Dialog(this);
        dialog.SetContentView(root);
        dialog.Window?.SetBackgroundDrawable(new ColorDrawable(Color.Transparent));
        dialog.Window?.AddFlags(WindowManagerFlags.DimBehind);
        dialog.Show();
        int width = Resources?.DisplayMetrics?.WidthPixels ?? ViewGroup.LayoutParams.MatchParent;
        int height = Resources?.DisplayMetrics?.HeightPixels ?? ViewGroup.LayoutParams.MatchParent;
        int targetWidth = IsTablet ? Math.Min(width - Ui.Dp(this, 80), Ui.Dp(this, 860)) : width - Ui.Dp(this, 24);
        int targetHeight = height - Ui.Dp(this, IsTablet ? 90 : 48);
        dialog.Window?.SetLayout(targetWidth, targetHeight);
        return (dialog, actions);
    }

    private int RegisterBranch(string branch)
    {
        int count = _branchCounts.GetValueOrDefault(branch) + 1;
        _branchCounts[branch] = count;
        _recentBranches.Enqueue(branch);
        while (_recentBranches.Count > 5) _recentBranches.Dequeue();

        if (branch == "认同" && count == 3)
            UnlockAndShow("温和观察者", "你连续三次选择认同，档案室送来一本空白观察笔记。");
        else if (branch == "非常认同" && count == 3)
            UnlockAndShow("坚定同盟", "赞同能量达到三级，绿色按钮短暂获得了自我意识。");
        else if (branch == "不认同" && count == 3)
            UnlockAndShow("逃离专家", "追踪系统开始怀疑：也许你正在收集不同的逃离结局。");

        string sequence = string.Join(">", _recentBranches);
        if (sequence == "认同>非常认同>不认同>认同>不认同")
            UnlockAndShow("解码 1111", "正确顺序已输入：2023-06-21 的金额正是 ￥1,111。");
        else if (_branchCounts.Values.Sum() == 12)
            UnlockAndShow("时间线观察员", "你在三个分支间作出了十二次选择。时间线已将你登记为观察员。");
        else if (Random.Shared.Next(30) == 0)
            UnlockAndShow("偶遇随机彩蛋", StoryContent.RandomEasterEgg());
        return count;
    }

    private void CheckTitleEgg()
    {
        _titleClicks++;
        if (!new[] { 3, 5, 8, 13, 21 }.Contains(_titleClicks)) return;
        UnlockAndShow($"标题点击 {_titleClicks} 次", StoryContent.RandomEasterEgg());
    }

    private void CheckQuoteDoubleTap()
    {
        long now = SystemClock.ElapsedRealtime();
        if (now - _lastQuoteTap <= 450)
        {
            _lastQuoteTap = 0;
            UnlockAndShow("翻看每日台词背面", StoryContent.RandomEasterEgg());
        }
        else
        {
            _lastQuoteTap = now;
        }
    }

    private void UnlockAndShow(string achievement, string message)
    {
        if (!_sessionEggs.Add(achievement)) return;
        AppState.UnlockAchievement(achievement);
        AppState.RecordChoice("隐藏彩蛋", achievement);
        Toast.MakeText(this, $"解锁成就：{achievement}\n{message}", ToastLength.Long)?.Show();
    }

    private void CopyToClipboard(string label, string text)
    {
        if (GetSystemService(ClipboardService) is Android.Content.ClipboardManager clipboard)
        {
            clipboard.PrimaryClip = ClipData.NewPlainText(label, text);
            Toast.MakeText(this, "已复制", ToastLength.Short)?.Show();
        }
    }

    private void ToggleFullScreen()
    {
        AppSettings settings = AppState.Settings;
        settings.FullScreenDemo = !settings.FullScreenDemo;
        AppState.UpdateSettings(settings);
        ApplyFullScreen();
        Render();
    }

    private void ApplyFullScreen()
    {
        if (Window is null) return;
        if (AppState.Settings.FullScreenDemo)
        {
            Window.AddFlags(WindowManagerFlags.Fullscreen);
            Window.DecorView.SystemUiFlags =
                SystemUiFlags.Fullscreen | SystemUiFlags.HideNavigation | SystemUiFlags.ImmersiveSticky;
        }
        else
        {
            Window.ClearFlags(WindowManagerFlags.Fullscreen);
            Window.DecorView.SystemUiFlags = SystemUiFlags.Visible;
        }
    }

    private void ApplySystemBars()
    {
        if (Window is null) return;
        Window.SetStatusBarColor(_palette.Background);
        Window.SetNavigationBarColor(_palette.Background);
        if (!AppState.Settings.FullScreenDemo)
            Window.DecorView.SystemUiFlags = _palette.Dark ? SystemUiFlags.Visible : SystemUiFlags.LightStatusBar;
    }

    private TextView StatusChip(string text)
    {
        TextView chip = Ui.Text(this, _palette, text, 10, true, GravityFlags.Center);
        chip.SetPadding(Ui.Dp(this, 5), Ui.Dp(this, 7), Ui.Dp(this, 5), Ui.Dp(this, 7));
        chip.Background = Ui.Rounded(_palette.Card, 14, this, _palette.Border);
        return chip;
    }

    private Button ToolButton(string text, EventHandler click)
    {
        Button button = Ui.Button(this, _palette, text);
        button.Click += click;
        return button;
    }

    private string ThemeLabel() => AppState.Settings.Theme switch
    {
        ThemeMode.Light => "浅色",
        ThemeMode.Dark => "深色",
        ThemeMode.PureBlack => "纯黑",
        _ => "系统主题"
    };

    private static string EnglishBranch(string branch) => branch switch
    {
        "认同" => "Agree",
        "非常认同" => "Strongly agree",
        _ => "Disagree"
    };

    private static string Limit(string value, int maximum) =>
        value.Length <= maximum ? value : value[..maximum] + "…";

    private static string LimitOrFallback(string? value, int maximum, string fallback)
    {
        string clean = value?.Trim() ?? string.Empty;
        if (clean.Length == 0) return fallback;
        return clean.Length <= maximum ? clean : clean[..maximum];
    }

    private LinearLayout.LayoutParams MatchWrap(int topDp = 0) =>
        new(ViewGroup.LayoutParams.MatchParent, ViewGroup.LayoutParams.WrapContent)
        {
            TopMargin = Ui.Dp(this, topDp)
        };

    private LinearLayout.LayoutParams Weighted(int marginDp = 3) =>
        new(0, ViewGroup.LayoutParams.WrapContent, 1F)
        {
            LeftMargin = Ui.Dp(this, marginDp),
            RightMargin = Ui.Dp(this, marginDp)
        };
}
