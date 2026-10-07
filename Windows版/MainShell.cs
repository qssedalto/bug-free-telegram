using Microsoft.Win32;

namespace 是否认同;

internal sealed class MainForm : Form
{
    private readonly bool _previewMode;
    private AmountDisplay _amount = null!;
    private FittedTextControl _titleLabel = null!;
    private FittedTextControl _questionLabel = null!;
    private Label _dailyQuote = null!;
    private Label _archiveLabel = null!;
    private Label _recentChoiceLabel = null!;
    private Label _achievementsLabel = null!;
    private Label _agreeRouteStatus = null!;
    private Label _strongAgreeRouteStatus = null!;
    private Label _disagreeRouteStatus = null!;
    private Label _storagePillLabel = null!;
    private Label _marketPillLabel = null!;
    private Label _themePillLabel = null!;
    private Label _shortcutsLabel = null!;
    private RoundedPanel _themePill = null!;
    private TableLayoutPanel _header = null!;
    private FlowLayoutPanel _statusPanel = null!;
    private RoundedButton _agreeButton = null!;
    private RoundedButton _strongAgreeButton = null!;
    private RoundedButton _disagreeButton = null!;
    private FlowLayoutPanel _contentFlow = null!;
    private RoundedPanel _storyColumn = null!;
    private RoundedPanel _sidebarColumn = null!;
    private RoundedPanel _achievementCard = null!;
    private MiniTrendControl _miniTrend = null!;
    private RouteProgressControl _routeProgress = null!;
    private FormBorderStyle _previousBorderStyle;
    private Rectangle _previousBounds;
    private bool _fullScreen;
    private bool _warning;
    private int _titleClicks;
    private int _miniClicks;
    private readonly Dictionary<string, int> _branchCounts = new(StringComparer.Ordinal);
    private readonly Queue<string> _recentBranches = new();
    private readonly HashSet<string> _sessionEggs = new(StringComparer.Ordinal);
    private readonly System.Windows.Forms.Timer _achievementFlashTimer = new() { Interval = 90 };
    private int _achievementFlashStep;
    private int _lastAchievementCount = -1;

    internal MainForm(bool previewMode = false)
    {
        _previewMode = previewMode;
        _achievementFlashTimer.Tick += (_, _) => TickAchievementFlash();
        RefreshAmount();
        Text = LocalizedText.Title(AppServices.Settings);
        StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(920, 700);
        ClientSize = new Size(1320, 900);
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Microsoft YaHei UI", 11F);
        KeyPreview = true;
        Controls.Add(BuildLayout());
        if (!_previewMode) RestoreWindowPlacement();
        ApplySettings();

        KeyDown += OnKeyDown;
        Shown += (_, _) => { UpdateResponsiveLayout(); RefreshHomeData(); };
        SizeChanged += (_, _) => UpdateResponsiveLayout();
        Activated += (_, _) => Theme.Apply(this, _warning);
        FormClosing += OnFormClosing;
        FormClosed += OnFormClosed;
        AppServices.SettingsChanged += OnSettingsChanged;
        AppServices.StoryReset += OnStoryReset;
        SystemEvents.UserPreferenceChanged += OnUserPreferenceChanged;
    }

    private Control BuildLayout()
    {
        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 3,
            Padding = new Padding(26, 18, 26, 18)
        };
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 88));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 56));

        _header = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 3, RowCount = 1, AccessibleName = "compact-font" };
        _header.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 38));
        _header.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 29));
        _header.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33));
        _titleLabel = new FittedTextControl
        {
            Dock = DockStyle.Fill,
            MaximumFontSize = 20F,
            MinimumFontSize = 9F,
            TextStyle = FontStyle.Bold,
            TextAlign = ContentAlignment.MiddleLeft,
            Padding = new Padding(8, 0, 0, 0),
            AccessibleName = "compact-font"
        };
        _titleLabel.Click += (_, _) => CheckEasterEgg();
        _statusPanel = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.LeftToRight,
            WrapContents = false,
            Padding = new Padding(0, 20, 0, 0)
        };
        _statusPanel.Controls.Add(CreateStatusPill("● 本地", out _storagePillLabel));
        _statusPanel.Controls.Add(CreateStatusPill("行情按需", out _marketPillLabel));
        _themePill = CreateStatusPill("系统主题", out _themePillLabel);
        _statusPanel.Controls.Add(_themePill);
        var tools = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            FlowDirection = FlowDirection.RightToLeft,
            WrapContents = false,
            Padding = new Padding(0, 17, 0, 0)
        };
        tools.Controls.Add(ToolButton("设置", (_, _) => ShowSettings()));
        tools.Controls.Add(ToolButton("数据", (_, _) => ShowDashboard()));
        tools.Controls.Add(ToolButton("直接展示金额", (_, _) => ShowMiniWindow(), 160));
        _header.Controls.Add(_titleLabel, 0, 0);
        _header.Controls.Add(_statusPanel, 1, 0);
        _header.Controls.Add(tools, 2, 0);

        _contentFlow = new FlowLayoutPanel
        {
            Dock = DockStyle.Fill,
            AutoScroll = true,
            FlowDirection = FlowDirection.LeftToRight,
            WrapContents = true,
            Padding = new Padding(0, 4, 0, 4)
        };

        _storyColumn = BuildStoryColumn();
        _sidebarColumn = BuildSidebarColumn();
        _contentFlow.Controls.Add(_storyColumn);
        _contentFlow.Controls.Add(_sidebarColumn);

        var footer = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 1, AccessibleName = "compact-font" };
        footer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 72));
        footer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 28));
        _dailyQuote = new Label
        {
            Dock = DockStyle.Fill,
            Font = new Font(Font.FontFamily, 10F, FontStyle.Italic),
            TextAlign = ContentAlignment.MiddleLeft,
            Padding = new Padding(12, 0, 8, 0)
        };
        _dailyQuote.DoubleClick += (_, _) =>
            ShowEgg("每日台词背面", StoryContent.RandomEasterEgg(), "翻看每日台词背面");
        _shortcutsLabel = new Label
        {
            Text = "F11 全屏  ·  F12 隐藏终端  ·  双击台词",
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.MiddleRight,
            Font = new Font(Font.FontFamily, 9F),
            Padding = new Padding(4)
        };
        footer.Controls.Add(_dailyQuote, 0, 0);
        footer.Controls.Add(_shortcutsLabel, 1, 0);
        root.Controls.Add(_header, 0, 0);
        root.Controls.Add(_contentFlow, 0, 1);
        root.Controls.Add(footer, 0, 2);
        return root;
    }

    private RoundedPanel BuildStoryColumn()
    {
        var panel = new RoundedPanel
        {
            Tag = "card",
            CornerRadius = 24,
            BorderThickness = 1,
            Padding = new Padding(22),
            Margin = new Padding(6),
            AccessibleName = "compact-font"
        };
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 5, ColumnCount = 1 };
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 142));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 33.333F));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 33.333F));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 33.334F));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 200));

        var questionArea = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 2, ColumnCount = 1 };
        questionArea.RowStyles.Add(new RowStyle(SizeType.Absolute, 38));
        questionArea.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        questionArea.Controls.Add(new Label
        {
            Text = "今日问题  ·  请选择一条时间线",
            Dock = DockStyle.Fill,
            Font = new Font(Font.FontFamily, 10F, FontStyle.Bold),
            TextAlign = ContentAlignment.BottomCenter
        }, 0, 0);
        _questionLabel = new FittedTextControl
        {
            Dock = DockStyle.Fill,
            MaximumFontSize = 19F,
            MinimumFontSize = 11F,
            TextStyle = FontStyle.Bold,
            TextAlign = ContentAlignment.MiddleCenter,
            Padding = new Padding(18, 2, 18, 8),
            AccessibleName = "compact-font"
        };
        questionArea.Controls.Add(_questionLabel, 0, 1);

        layout.Controls.Add(questionArea, 0, 0);
        layout.Controls.Add(BuildBranchCard("●", "档案调查路线", "调查金额档案与随机记录", Color.FromArgb(10, 132, 255), "认同", ShowConfirmation, out _agreeButton, out _agreeRouteStatus), 0, 1);
        layout.Controls.Add(BuildBranchCard("●", "共振与同盟路线", "进入多阶段观点共振剧情", Color.FromArgb(48, 209, 88), "非常认同", ShowImmediateRecognition, out _strongAgreeButton, out _strongAgreeRouteStatus), 0, 2);
        layout.Controls.Add(BuildBranchCard("●", "警报与逃离路线", "触发倒计时与随机逃离结局", Color.FromArgb(255, 69, 58), "不认同", ShowWarning, out _disagreeButton, out _disagreeRouteStatus), 0, 3);

        var trendCard = new RoundedPanel { Tag = "card", Dock = DockStyle.Fill, CornerRadius = 18, BorderThickness = 1, Margin = new Padding(7, 9, 7, 2), Padding = new Padding(14, 8, 14, 8), Cursor = Cursors.Hand };
        var trendLayout = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 1, ColumnCount = 2 };
        trendLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 190));
        trendLayout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        var trendTitle = new Label { Text = "近七日增长\n查看完整图表", Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft, Font = new Font(Font.FontFamily, 9F, FontStyle.Bold) };
        _miniTrend = new MiniTrendControl
        {
            Dock = DockStyle.Fill,
            Font = new Font(Font.FontFamily, 8F),
            Tag = "inherit",
            AccessibleName = "mini-trend"
        };
        trendLayout.Controls.Add(trendTitle, 0, 0);
        trendLayout.Controls.Add(_miniTrend, 1, 0);
        trendCard.Controls.Add(trendLayout);
        WireClick(trendCard, (_, _) => ShowDashboard());
        EnableCardHover(trendCard, Color.FromArgb(AppServices.Settings.AccentArgb));
        layout.Controls.Add(trendCard, 0, 4);
        panel.Controls.Add(layout);
        return panel;
    }

    private RoundedPanel BuildSidebarColumn()
    {
        var panel = new RoundedPanel
        {
            Tag = "card",
            CornerRadius = 24,
            BorderThickness = 1,
            Padding = new Padding(14),
            Margin = new Padding(6),
            AccessibleName = "compact-font"
        };
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 4, ColumnCount = 1 };
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 32));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 22));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 24));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 22));

        layout.Controls.Add(BuildInfoCard("📁  今日档案", out _archiveLabel, null), 0, 0);
        var routeCard = new RoundedPanel { Tag = "card", Dock = DockStyle.Fill, CornerRadius = 18, BorderThickness = 1, Margin = new Padding(6), Padding = new Padding(14, 10, 14, 10) };
        var routeLayout = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 2, ColumnCount = 1 };
        routeLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 34));
        routeLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        routeLayout.Controls.Add(new Label { Text = "🧭  本次路线进度", Dock = DockStyle.Fill, Font = new Font(Font.FontFamily, 10F, FontStyle.Bold), TextAlign = ContentAlignment.MiddleLeft }, 0, 0);
        _routeProgress = new RouteProgressControl { Dock = DockStyle.Fill, Font = new Font(Font.FontFamily, 8.5F), Tag = "inherit" };
        routeLayout.Controls.Add(_routeProgress, 0, 1);
        routeCard.Controls.Add(routeLayout);
        layout.Controls.Add(routeCard, 0, 1);
        layout.Controls.Add(BuildInfoCard("🕘  最近选择", out _recentChoiceLabel, (_, _) => ShowDashboard()), 0, 2);
        _achievementCard = BuildInfoCard("🏆  成就陈列架", out _achievementsLabel, (_, _) => ShowDashboard());
        layout.Controls.Add(_achievementCard, 0, 3);
        panel.Controls.Add(layout);
        return panel;
    }

    private RoundedPanel BuildBranchCard(
        string icon,
        string title,
        string description,
        Color color,
        string buttonText,
        EventHandler click,
        out RoundedButton button,
        out Label status)
    {
        var card = new RoundedPanel { Tag = $"branch:{color.ToArgb()}", Dock = DockStyle.Fill, CornerRadius = 18, BorderThickness = 2, Margin = new Padding(7), Padding = new Padding(12), Cursor = Cursors.Hand };
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 1, ColumnCount = 3 };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 62));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 196));
        var iconLabel = new Label { Text = icon, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleCenter, Font = new Font("Segoe UI Symbol", 27F, FontStyle.Bold), ForeColor = color, BackColor = Color.Transparent, Tag = "accent" };
        var text = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 3, ColumnCount = 1 };
        text.RowStyles.Add(new RowStyle(SizeType.Percent, 36));
        text.RowStyles.Add(new RowStyle(SizeType.Percent, 30));
        text.RowStyles.Add(new RowStyle(SizeType.Percent, 34));
        var titleLabel = new Label { Text = title, Dock = DockStyle.Fill, Font = new Font(Font.FontFamily, 11F, FontStyle.Bold), TextAlign = ContentAlignment.BottomLeft, Tag = "inherit" };
        var descriptionLabel = new Label { Text = description, Dock = DockStyle.Fill, Font = new Font(Font.FontFamily, 8.5F), TextAlign = ContentAlignment.MiddleLeft, Tag = "inherit" };
        status = new Label { Dock = DockStyle.Fill, Font = new Font(Font.FontFamily, 7F, FontStyle.Italic), TextAlign = ContentAlignment.TopLeft, Tag = "inherit", AutoEllipsis = true };
        text.Controls.Add(titleLabel, 0, 0);
        text.Controls.Add(descriptionLabel, 0, 1);
        text.Controls.Add(status, 0, 2);
        button = ActionButton(buttonText, color, click);
        button.Size = new Size(176, 60);
        button.MinimumSize = new Size(176, 60);
        layout.Controls.Add(iconLabel, 0, 0);
        layout.Controls.Add(text, 1, 0);
        layout.Controls.Add(button, 2, 0);
        card.Controls.Add(layout);
        WireClick(card, click, button);
        EnableCardHover(card, color, button);
        return card;
    }

    private RoundedPanel BuildInfoCard(string title, out Label body, EventHandler? click)
    {
        var card = new RoundedPanel { Tag = "card", Dock = DockStyle.Fill, CornerRadius = 18, BorderThickness = 1, Margin = new Padding(6), Padding = new Padding(14, 10, 14, 10) };
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 2, ColumnCount = 1 };
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 36));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        var titleLabel = new Label { Text = title, Dock = DockStyle.Fill, Font = new Font(Font.FontFamily, 10F, FontStyle.Bold), TextAlign = ContentAlignment.MiddleLeft };
        body = new Label { Dock = DockStyle.Fill, Font = new Font(Font.FontFamily, 9.5F), TextAlign = ContentAlignment.TopLeft, Padding = new Padding(2, 4, 2, 2), UseCompatibleTextRendering = true, AutoEllipsis = true };
        layout.Controls.Add(titleLabel, 0, 0);
        layout.Controls.Add(body, 0, 1);
        card.Controls.Add(layout);
        if (click is not null)
        {
            WireClick(card, click);
            EnableCardHover(card, Color.FromArgb(AppServices.Settings.AccentArgb));
        }
        return card;
    }

    private RoundedPanel CreateStatusPill(string text, out Label label)
    {
        var pill = new RoundedPanel { Tag = "card", Size = new Size(110, 32), CornerRadius = 16, BorderThickness = 1, Margin = new Padding(3, 0, 3, 0), Padding = new Padding(1) };
        label = new Label { Text = text, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleCenter, Font = new Font(Font.FontFamily, 8F, FontStyle.Bold), Tag = "inherit" };
        pill.Controls.Add(label);
        return pill;
    }

    private static void WireClick(Control root, EventHandler click, Control? excluded = null)
    {
        if (ReferenceEquals(root, excluded)) return;
        root.Cursor = Cursors.Hand;
        root.Click += click;
        foreach (Control child in root.Controls) WireClick(child, click, excluded);
    }

    private static void EnableCardHover(RoundedPanel card, Color color, Control? excluded = null)
    {
        void Enter(object? sender, EventArgs e)
        {
            card.BorderThickness = 3;
            card.BorderColor = Color.FromArgb(210, color);
            card.Invalidate();
        }

        void Leave(object? sender, EventArgs e)
        {
            if (card.IsDisposed) return;
            Point pointer = card.PointToClient(Cursor.Position);
            if (card.ClientRectangle.Contains(pointer)) return;
            card.BorderThickness = card.Tag is string role && role.StartsWith("branch:", StringComparison.Ordinal) ? 2 : 1;
            card.Invalidate();
        }

        void Attach(Control control)
        {
            if (ReferenceEquals(control, excluded)) return;
            control.MouseEnter += Enter;
            control.MouseLeave += Leave;
            foreach (Control child in control.Controls) Attach(child);
        }
        Attach(card);
    }

    private void UpdateResponsiveLayout()
    {
        if (_contentFlow is null || _storyColumn is null || _sidebarColumn is null) return;
        int scrollbarAllowance = _contentFlow.VerticalScroll.Visible ? SystemInformation.VerticalScrollBarWidth : 0;
        int availableWidth = Math.Max(
            1,
            _contentFlow.ClientSize.Width
                - _contentFlow.Padding.Horizontal
                - scrollbarAllowance);
        bool wide = availableWidth >= 1040;
        _contentFlow.SuspendLayout();
        if (wide)
        {
            _header.ColumnStyles[0].Width = 38;
            _header.ColumnStyles[1].Width = 29;
            _header.ColumnStyles[2].Width = 33;
            _statusPanel.Visible = true;
            const int combinedHorizontalMargins = 24;
            int usableWidth = Math.Max(760, availableWidth - combinedHorizontalMargins);
            int storyWidth = (int)Math.Floor(usableWidth * 0.64F);
            int sidebarWidth = usableWidth - storyWidth;
            // Preserve the intrinsic height of the question, route cards and
            // trend chart. A shorter host window scrolls instead of squeezing
            // those components until their text or plot disappears.
            int height = Math.Max(800, _contentFlow.ClientSize.Height - 14);
            _storyColumn.Size = new Size(storyWidth, height);
            _sidebarColumn.Size = new Size(sidebarWidth, height);
            _themePill.Visible = true;
            _shortcutsLabel.Text = "F11全屏  ·  F12彩蛋  ·  双击台词";
        }
        else
        {
            _header.ColumnStyles[0].Width = 34;
            _header.ColumnStyles[1].Width = 0;
            _header.ColumnStyles[2].Width = 66;
            _statusPanel.Visible = false;
            const int singleColumnHorizontalMargins = 12;
            int width = Math.Max(1, availableWidth - singleColumnHorizontalMargins);
            _storyColumn.Size = new Size(width, 800);
            _sidebarColumn.Size = new Size(width, 700);
            _themePill.Visible = false;
            _shortcutsLabel.Text = "F11全屏  ·  F12彩蛋";
        }
        _contentFlow.ResumeLayout(true);
    }

    private void RefreshHomeData()
    {
        if (_archiveLabel is null) return;
        AppSettings settings = AppServices.Settings;
        DateOnly today = DateOnly.FromDateTime(DateTime.Today);
        int elapsed = DebtEngine.DaysForDate(today, settings) + 1;
        _archiveLabel.Text = $"{today:yyyy年MM月dd日  dddd}\n"
            + $"运行第 {elapsed:N0} 天  ·  连续签到 {AppServices.Database.CurrentStreak} 天";

        int agreeSession = _branchCounts.GetValueOrDefault("认同");
        int strongSession = _branchCounts.GetValueOrDefault("非常认同");
        int disagreeSession = _branchCounts.GetValueOrDefault("不认同");
        int agreeTotal = AppServices.Database.Choices.Count(choice => choice.Choice == "认同");
        int strongTotal = AppServices.Database.Choices.Count(choice => choice.Choice == "非常认同");
        int disagreeTotal = AppServices.Database.Choices.Count(choice => choice.Choice == "不认同");
        _agreeRouteStatus.Text = agreeSession == 0 ? "本次尚未进入" : $"本次已进入 {agreeSession:N0} 次";
        _strongAgreeRouteStatus.Text = strongSession == 0 ? "本次尚未进入" : $"本次已进入 {strongSession:N0} 次";
        _disagreeRouteStatus.Text = disagreeSession == 0 ? "本次尚未进入" : $"本次已进入 {disagreeSession:N0} 次 · 第四次有隐藏路线";
        _routeProgress.SetCounts(
            agreeTotal,
            strongTotal,
            disagreeTotal,
            StoryContent.AgreeCombinationCount,
            StoryContent.StrongAgreeCombinationCount,
            StoryContent.WarningCombinationCount);

        ChoiceRecord? recent = AppServices.Database.Choices.LastOrDefault();
        _recentChoiceLabel.Text = recent is null
            ? "还没有选择记录。\n按下任意剧情按钮开始第一条时间线。"
            : $"{recent.Time:MM-dd  HH:mm}\n{recent.Choice}\n{LimitForCard(recent.Result, 46)}";

        string[] achievements = AppServices.Database.Achievements.TakeLast(4).ToArray();
        _achievementsLabel.Text = achievements.Length == 0
            ? "◇ 尚未解锁成就\n连续选择、探索标题与日期会留下线索。"
            : string.Join("  ·  ", achievements.Select(item => "◆ " + item))
                + $"\n\n已解锁 {AppServices.Database.Achievements.Count} 项 · 仍有隐藏内容";
        int achievementCount = AppServices.Database.Achievements.Count;
        if (_lastAchievementCount >= 0
            && achievementCount > _lastAchievementCount
            && !settings.ReduceMotion)
        {
            _achievementFlashStep = 0;
            _achievementFlashTimer.Start();
        }
        _lastAchievementCount = achievementCount;

        var trend = new List<double>();
        for (int day = 6; day >= 0; day--)
            trend.Add(DebtEngine.Log10ForChart(DebtEngine.AmountForDate(today.AddDays(-day), settings)));
        _miniTrend.LineColor = Color.FromArgb(settings.AccentArgb);
        _miniTrend.SetPoints(trend);

        _storagePillLabel.Text = "● 已保存";
        _marketPillLabel.Text = "行情按需";
        _themePillLabel.Text = settings.Theme switch
        {
            ThemeMode.Light => "浅色",
            ThemeMode.Dark => "深色",
            ThemeMode.PureBlack => "纯黑",
            _ => "系统主题"
        };
        _storyColumn.Invalidate(true);
        _sidebarColumn.Invalidate(true);
    }

    private static string LimitForCard(string value, int maximum) =>
        value.Length <= maximum ? value : value[..maximum] + "…";

    private void TickAchievementFlash()
    {
        _achievementFlashStep++;
        bool bright = _achievementFlashStep % 2 == 1;
        _achievementCard.BorderThickness = bright ? 4 : 2;
        _achievementCard.BorderColor = bright
            ? Color.FromArgb(AppServices.Settings.AccentArgb)
            : Color.FromArgb(130, Color.FromArgb(AppServices.Settings.AccentArgb));
        _achievementCard.Invalidate();
        if (_achievementFlashStep < 8) return;
        _achievementFlashTimer.Stop();
        _achievementCard.BorderThickness = 1;
        Theme.Apply(this, _warning);
    }

    private static RoundedButton ActionButton(string text, Color color, EventHandler click)
    {
        var button = new RoundedButton
        {
            Text = text,
            Size = new Size(250, 64),
            BackColor = color,
            ForeColor = Color.White,
            Font = new Font("Microsoft YaHei UI", 13F, FontStyle.Bold),
            Tag = "accent",
            Anchor = AnchorStyles.None,
            CornerRadius = 16
        };
        button.FlatAppearance.MouseOverBackColor = ControlPaint.Light(color, 0.08F);
        button.FlatAppearance.MouseDownBackColor = ControlPaint.Dark(color, 0.08F);
        button.Click += click;
        return button;
    }

    private static RoundedButton ToolButton(string text, EventHandler click, int width = 86)
    {
        var color = Color.FromArgb(AppServices.Settings.AccentArgb);
        var button = ActionButton(text, color, click);
        button.Size = new Size(width, 46);
        button.Font = new Font("Microsoft YaHei UI", 9F, FontStyle.Bold);
        button.Margin = new Padding(3);
        return button;
    }

    private void ShowConfirmation(object? sender, EventArgs e)
    {
        RegisterBranch("认同");
        AgreeStory story = StoryContent.NextAgree(AppServices.Settings);
        AppServices.RecordChoice("认同", story.Title);
        RefreshHomeData();
        Play(System.Media.SystemSounds.Asterisk);
        using var dialog = new ConfirmationDialog(_amount, story);
        ShowAnimated(dialog);
        RefreshHomeData();
    }

    private void ShowImmediateRecognition(object? sender, EventArgs e)
    {
        RegisterBranch("非常认同");
        StorySequence story = StoryContent.NextStrongAgree(AppServices.Settings);
        IReadOnlyList<string> lines = string.IsNullOrWhiteSpace(AppServices.Settings.CustomStoryText)
            ? story.Lines
            : story.Lines.Concat([AppServices.Settings.CustomStoryText]).ToArray();
        AppServices.RecordChoice("非常认同", story.Result);
        RefreshHomeData();
        using var dialog = new MessageDialog(story.Title, story.ButtonText, lines, false);
        ShowAnimated(dialog);
        RefreshHomeData();
    }

    private void ShowWarning(object? sender, EventArgs e)
    {
        int count = RegisterBranch("不认同");
        _warning = true;
        Theme.Apply(this, true);
        bool secretRoute = count > 0 && count % 4 == 0;
        WarningStory story = StoryContent.NextWarning(AppServices.Settings, LocalizedText.Person(AppServices.Settings), secretRoute);
        AppServices.RecordChoice("不认同", story.Title);
        RefreshHomeData();
        Play(System.Media.SystemSounds.Exclamation);
        using var dialog = new WarningDialog(story);
        ShowAnimated(dialog);
        _warning = false;
        Theme.Apply(this);
        RefreshHomeData();
    }

    private void ShowAnimated(Form dialog)
    {
        if (AppServices.Settings.ReduceMotion)
        {
            dialog.ShowDialog(this);
            return;
        }
        dialog.Opacity = 0;
        var timer = new System.Windows.Forms.Timer { Interval = 16 };
        timer.Tick += (_, _) =>
        {
            dialog.Opacity = Math.Min(1, dialog.Opacity + 0.09);
            if (dialog.Opacity >= 1) timer.Stop();
        };
        dialog.Shown += (_, _) => timer.Start();
        dialog.FormClosed += (_, _) => timer.Dispose();
        dialog.ShowDialog(this);
    }

    private void ShowDashboard()
    {
        using var form = new DataDashboardForm();
        form.ShowDialog(this);
        RefreshHomeData();
    }

    private void ShowSettings()
    {
        using var form = new SettingsForm();
        form.ShowDialog(this);
        RefreshHomeData();
    }

    private void ShowMiniWindow()
    {
        _miniClicks++;
        new MiniAmountForm().Show(this);
        if (_miniClicks == 3)
            ShowEgg("迷你彩蛋", "🔬 你连续打开了三个迷你窗口。金额观测站授予你“窗口收藏家”称号。", "窗口收藏家");
    }

    private void ApplySettings()
    {
        AppSettings settings = AppServices.Settings;
        Text = LocalizedText.Title(settings);
        _titleLabel.Text = LocalizedText.Title(settings);
        _questionLabel.Text = LocalizedText.Question(settings);
        _agreeButton.Text = settings.English ? "Agree" : "认同";
        _strongAgreeButton.Text = settings.English ? "Strongly agree" : "非常认同";
        _disagreeButton.Text = settings.English ? "Disagree" : "不认同";
        string[] quotes = LocalizedText.DailyQuotes(settings);
        _dailyQuote.Text = quotes[DateTime.Today.DayOfYear % quotes.Length];
        if (DateTime.Today.Month == 6 && DateTime.Today.Day == 19)
            _dailyQuote.Text = settings.English ? "Anchor day: n = 7." : "锚点日彩蛋：今天是 n = 7 的起始纪念日。";
        else if (DateTime.Today.Month == 6 && DateTime.Today.Day == 21)
            _dailyQuote.Text = settings.English ? "Archive 1111 is active today." : "1111 彩蛋：这一天在原始时间线中的金额为 ￥1,111。";
        TopMost = settings.AlwaysOnTop;
        Theme.Apply(this, _warning);
        ApplyFontScale(this, (float)settings.FontScale);
        RefreshHomeData();
        UpdateResponsiveLayout();
        if (settings.FullScreenDemo && !_fullScreen) ToggleFullScreen();
        else if (!settings.FullScreenDemo && _fullScreen) ToggleFullScreen();
    }

    private static void ApplyFontScale(Control root, float scale, bool compact = false)
    {
        foreach (Control child in root.Controls)
        {
            bool childCompact = compact || child.AccessibleName == "compact-font";
            if (child.Font is not null)
            {
                const string prefix = "base-font:";
                float baseSize = child.Font.Size;
                if (child.AccessibleDescription?.StartsWith(prefix, StringComparison.Ordinal) == true
                    && float.TryParse(
                        child.AccessibleDescription[prefix.Length..],
                        System.Globalization.NumberStyles.Float,
                        System.Globalization.CultureInfo.InvariantCulture,
                        out float stored))
                {
                    baseSize = stored;
                }
                else
                {
                    child.AccessibleDescription = prefix + baseSize.ToString(System.Globalization.CultureInfo.InvariantCulture);
                }
                float effectiveScale = childCompact ? 0.70F + (scale * 0.20F) : scale;
                child.Font = new Font(child.Font.FontFamily, Math.Clamp(baseSize * effectiveScale, 8F, 30F), child.Font.Style);
            }
            ApplyFontScale(child, scale, childCompact);
        }
    }

    private void RefreshAmount() =>
        _amount = DebtEngine.AmountForDate(DateOnly.FromDateTime(DateTime.Today), AppServices.Settings);

    private void OnSettingsChanged(object? sender, EventArgs e)
    {
        if (IsDisposed) return;
        RefreshAmount();
        ApplySettings();
    }

    private void OnStoryReset(object? sender, EventArgs e)
    {
        _branchCounts.Clear();
        _recentBranches.Clear();
        _sessionEggs.Clear();
        _titleClicks = 0;
        _miniClicks = 0;
        _lastAchievementCount = AppServices.Database.Achievements.Count;
        RefreshHomeData();
    }

    private void CheckEasterEgg()
    {
        _titleClicks++;
        int[] checkpoints = [3, 5, 8, 13, 21];
        if (!checkpoints.Contains(_titleClicks)) return;
        ShowEgg($"标题彩蛋 {_titleClicks}", StoryContent.RandomEasterEgg(), $"标题点击 {_titleClicks} 次");
    }

    private int RegisterBranch(string branch)
    {
        _branchCounts.TryGetValue(branch, out int count);
        count++;
        _branchCounts[branch] = count;
        _recentBranches.Enqueue(branch);
        while (_recentBranches.Count > 5) _recentBranches.Dequeue();

        if (branch == "认同" && count == 3)
            ShowEgg("温和路线彩蛋", "📘 你连续三次选择认同，档案室送来一本只有空白页的观察笔记。", "温和观察者");
        else if (branch == "非常认同" && count == 3)
            ShowEgg("绿色路线彩蛋", "💚 赞同能量达到三级，绿色按钮短暂获得了自我意识。", "坚定同盟");
        else if (branch == "不认同" && count == 3)
            ShowEgg("红色路线彩蛋", "🚨 追踪系统开始怀疑：也许你是在故意收集不同的逃离结局。", "逃离专家");

        string sequence = string.Join(">", _recentBranches);
        if (sequence == "认同>非常认同>不认同>认同>不认同")
            ShowEgg("隐藏档案 1111", "📼 正确顺序已输入。隐藏档案显示：2023-06-21 的金额正是 ￥1,111。", "解码 1111");
        else if (_branchCounts.Values.Sum() == 12)
            ShowEgg("十二次选择", "🕰️ 你在三个分支间作出了十二次选择，时间线决定把你登记为正式观察员。", "时间线观察员");
        else if (Random.Shared.Next(30) == 0)
            ShowEgg("随机彩蛋", StoryContent.RandomEasterEgg(), "偶遇随机彩蛋");
        return count;
    }

    private void ShowEgg(string title, string message, string achievement)
    {
        string key = title + achievement;
        if (!_sessionEggs.Add(key)) return;
        AppServices.UnlockAchievement(achievement);
        AppServices.RecordChoice("隐藏彩蛋", achievement);
        Play(System.Media.SystemSounds.Asterisk);
        MessageBox.Show(this, message, title, MessageBoxButtons.OK, MessageBoxIcon.Information);
        RefreshHomeData();
    }

    private void ToggleFullScreen()
    {
        if (!_fullScreen)
        {
            _previousBounds = Bounds;
            _previousBorderStyle = FormBorderStyle;
            FormBorderStyle = FormBorderStyle.None;
            WindowState = FormWindowState.Normal;
            Bounds = Screen.FromControl(this).Bounds;
            _fullScreen = true;
        }
        else
        {
            FormBorderStyle = _previousBorderStyle;
            Bounds = _previousBounds;
            _fullScreen = false;
        }
    }

    private void OnKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.KeyCode == Keys.F11)
        {
            ToggleFullScreen();
            e.Handled = true;
        }
        else if (e.KeyCode == Keys.F12)
        {
            ShowEgg("F12 隐藏终端", "⌨️ 隐藏终端只返回了一句话：所有金额计算仍受 99 位安全上限保护。", "发现隐藏终端");
            e.Handled = true;
        }
    }

    private void RestoreWindowPlacement()
    {
        AppSettings settings = AppServices.Settings;
        var bounds = new Rectangle(settings.WindowX, settings.WindowY, settings.WindowWidth, settings.WindowHeight);
        bool visible = Screen.AllScreens.Any(screen => screen.WorkingArea.IntersectsWith(bounds));
        if (visible)
        {
            StartPosition = FormStartPosition.Manual;
            Bounds = bounds;
        }
        if (settings.WindowMaximized) WindowState = FormWindowState.Maximized;
    }

    private void SaveWindowPlacement()
    {
        if (_fullScreen) return;
        AppSettings value = AppServices.Settings;
        Rectangle bounds = WindowState == FormWindowState.Normal ? Bounds : RestoreBounds;
        value.WindowX = bounds.X;
        value.WindowY = bounds.Y;
        value.WindowWidth = bounds.Width;
        value.WindowHeight = bounds.Height;
        value.WindowMaximized = WindowState == FormWindowState.Maximized;
        AppServices.UpdateSettings(value);
    }

    private void OnFormClosing(object? sender, FormClosingEventArgs e)
    {
        if (!_previewMode) SaveWindowPlacement();
    }

    private void OnFormClosed(object? sender, FormClosedEventArgs e)
    {
        _achievementFlashTimer.Dispose();
        AppServices.SettingsChanged -= OnSettingsChanged;
        AppServices.StoryReset -= OnStoryReset;
        SystemEvents.UserPreferenceChanged -= OnUserPreferenceChanged;
    }

    private void OnUserPreferenceChanged(object sender, UserPreferenceChangedEventArgs e)
    {
        if (!IsDisposed) BeginInvoke(() => Theme.Apply(this, _warning));
    }

    private static void Play(System.Media.SystemSound sound)
    {
        if (AppServices.Settings.SoundEnabled) sound.Play();
    }
}
