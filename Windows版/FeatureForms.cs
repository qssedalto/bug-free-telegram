namespace 是否认同;

internal sealed class SettingsForm : Form
{
    private readonly DateTimePicker _startDate = new();
    private readonly TextBox _initialAmount = new();
    private readonly TextBox _windowTitle = new();
    private readonly TextBox _question = new();
    private readonly TextBox _personName = new();
    private readonly TextBox _customStory = new();
    private readonly ComboBox _theme = new();
    private readonly NumericUpDown _fontScale = new();
    private readonly CheckBox _highContrast = new();
    private readonly CheckBox _reduceMotion = new();
    private readonly CheckBox _sound = new();
    private readonly CheckBox _alwaysOnTop = new();
    private readonly CheckBox _fullScreen = new();
    private readonly CheckBox _english = new();
    private readonly CheckBox _neutral = new();
    private int _accentArgb;

    internal SettingsForm()
    {
        Text = "设置";
        StartPosition = FormStartPosition.CenterParent;
        ClientSize = new Size(900, 820);
        MinimumSize = new Size(760, 680);
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Microsoft YaHei UI", 10F);
        Controls.Add(BuildLayout());
        LoadValues();
        Theme.Apply(this);
    }

    private Control BuildLayout()
    {
        var root = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 3, ColumnCount = 1, Padding = new Padding(36) };
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 62));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 76));
        var fields = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            AutoScroll = true,
            ColumnCount = 2,
            RowCount = 17,
            Padding = new Padding(12)
        };
        fields.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 220));
        fields.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        AddRow(fields, 0, "起始日期", _startDate);
        AddRow(fields, 1, "初始金额（元）", _initialAmount);
        AddRow(fields, 2, "窗口标题", _windowTitle);
        AddRow(fields, 3, "问题文字", _question);
        AddRow(fields, 4, "人物名称", _personName);
        _customStory.Multiline = true;
        _customStory.Height = 70;
        AddRow(fields, 5, "自定义剧情文字", _customStory, 82);
        _theme.DropDownStyle = ComboBoxStyle.DropDownList;
        _theme.DataSource = Enum.GetValues<ThemeMode>();
        AddRow(fields, 6, "主题", _theme);
        _fontScale.Minimum = 75;
        _fontScale.Maximum = 175;
        _fontScale.Increment = 5;
        AddRow(fields, 7, "字号缩放（%）", _fontScale);
        AddRow(fields, 8, "高对比度", _highContrast);
        AddRow(fields, 9, "减少动画", _reduceMotion);
        AddRow(fields, 10, "启用音效", _sound);
        AddRow(fields, 11, "窗口始终置顶", _alwaysOnTop);
        AddRow(fields, 12, "启动全屏演示", _fullScreen);
        AddRow(fields, 13, "英文界面", _english);
        AddRow(fields, 14, "中性/虚构角色模式", _neutral);
        var accent = DialogLayout.Button("选择强调色", (_, _) => ChooseAccent());
        accent.Size = new Size(190, 48);
        AddRow(fields, 15, "自定义强调色", accent, 60);
        var note = DialogLayout.Text("设置会保存在本机；窗口大小、位置和显示器也会自动记忆。", 9F);
        AddRow(fields, 16, "说明", note, 60);

        var actions = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.RightToLeft, Padding = new Padding(8) };
        actions.Controls.Add(DialogLayout.Button("保存", (_, _) => SaveValues()));
        actions.Controls.Add(DialogLayout.Button("取消", (_, _) => Close()));
        var copyright = new RoundedPanel
        {
            Tag = "card",
            Dock = DockStyle.Fill,
            CornerRadius = 16,
            BorderThickness = 1,
            Margin = new Padding(8, 5, 8, 5),
            Padding = new Padding(8)
        };
        copyright.Controls.Add(new Label
        {
            Text = "© 天国智造 · 版权所有",
            AccessibleName = "copyright",
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.MiddleCenter,
            Font = new Font("Microsoft YaHei UI", 12F, FontStyle.Bold),
            UseCompatibleTextRendering = true
        });
        root.Controls.Add(fields, 0, 0);
        root.Controls.Add(copyright, 0, 1);
        root.Controls.Add(actions, 0, 2);
        return root;
    }

    private static void AddRow(TableLayoutPanel table, int row, string label, Control control, int height = 52)
    {
        table.RowStyles.Add(new RowStyle(SizeType.Absolute, height));
        table.Controls.Add(new Label { Text = label, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft }, 0, row);
        control.Dock = DockStyle.Fill;
        control.Margin = new Padding(8);
        table.Controls.Add(control, 1, row);
    }

    private void LoadValues()
    {
        AppSettings value = AppServices.Settings;
        _startDate.Value = value.StartDate.ToDateTime(TimeOnly.MinValue);
        _initialAmount.Text = value.InitialAmount;
        _windowTitle.Text = value.WindowTitle;
        _question.Text = value.Question;
        _personName.Text = value.PersonName;
        _customStory.Text = value.CustomStoryText;
        _theme.SelectedItem = value.Theme;
        _fontScale.Value = Math.Clamp(value.FontScale * 100m, 75m, 175m);
        _highContrast.Checked = value.HighContrast;
        _reduceMotion.Checked = value.ReduceMotion;
        _sound.Checked = value.SoundEnabled;
        _alwaysOnTop.Checked = value.AlwaysOnTop;
        _fullScreen.Checked = value.FullScreenDemo;
        _english.Checked = value.English;
        _neutral.Checked = value.NeutralMode;
        _accentArgb = value.AccentArgb;
    }

    private void SaveValues()
    {
        if (!decimal.TryParse(_initialAmount.Text, out decimal initial) || initial <= 0)
        {
            MessageBox.Show(this, "初始金额必须是大于零的数字。", "设置", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        var settings = new AppSettings
        {
            StartDate = DateOnly.FromDateTime(_startDate.Value),
            InitialAmount = initial.ToString(System.Globalization.CultureInfo.InvariantCulture),
            WindowTitle = Limit(_windowTitle.Text, 80, "开发者の问题🙋"),
            Question = Limit(_question.Text, 160, "是否认同这是一个有趣的问题？"),
            PersonName = Limit(_personName.Text, 40, "虚构角色"),
            CustomStoryText = Limit(_customStory.Text, 1000, string.Empty),
            Theme = _theme.SelectedItem is ThemeMode mode ? mode : ThemeMode.System,
            FontScale = _fontScale.Value / 100m,
            HighContrast = _highContrast.Checked,
            ReduceMotion = _reduceMotion.Checked,
            SoundEnabled = _sound.Checked,
            AlwaysOnTop = _alwaysOnTop.Checked,
            FullScreenDemo = _fullScreen.Checked,
            English = _english.Checked,
            NeutralMode = _neutral.Checked,
            AccentArgb = _accentArgb,
            WindowX = AppServices.Settings.WindowX,
            WindowY = AppServices.Settings.WindowY,
            WindowWidth = AppServices.Settings.WindowWidth,
            WindowHeight = AppServices.Settings.WindowHeight,
            WindowMaximized = AppServices.Settings.WindowMaximized
        };
        AppServices.UpdateSettings(settings);
        DialogResult = DialogResult.OK;
        Close();
    }

    private void ChooseAccent()
    {
        using var picker = new ColorDialog { Color = Color.FromArgb(_accentArgb), FullOpen = true };
        if (picker.ShowDialog(this) == DialogResult.OK) _accentArgb = picker.Color.ToArgb();
    }

    private static string Limit(string value, int length, string fallback)
    {
        string clean = value.Trim();
        if (clean.Length == 0) return fallback;
        return clean.Length <= length ? clean : clean[..length];
    }
}

internal sealed class DataDashboardForm : Form
{
    private readonly AmountDisplay? _sizingAmount;
    private readonly Label _overview = new();
    private readonly Label _market = new();
    private readonly TrendChart _chart = new();
    private readonly ListBox _history = new();
    private readonly CancellationTokenSource _cancellation = new();
    private string[] _amountSizingLines = [];

    internal DataDashboardForm(AmountDisplay? sizingAmount = null, bool loadMarkets = true)
    {
        _sizingAmount = sizingAmount;
        Text = "数据面板";
        StartPosition = FormStartPosition.CenterParent;
        ClientSize = new Size(1180, 820);
        MinimumSize = new Size(940, 680);
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Microsoft YaHei UI", 10F);
        Controls.Add(BuildLayout());
        Populate();
        Theme.Apply(this);
        if (loadMarkets) _ = LoadMarketsAsync();
    }

    private Control BuildLayout()
    {
        var tabs = new TabControl { Dock = DockStyle.Fill, Padding = new Point(18, 8) };
        var summary = new TabPage("概览");
        var trend = new TabPage("增长折线图");
        var history = new TabPage("历史与成就");

        var summaryLayout = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 2, ColumnCount = 1, Padding = new Padding(30) };
        summaryLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 56));
        summaryLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 44));
        _overview.Dock = DockStyle.Fill;
        _overview.Font = new Font(Font.FontFamily, 14F, FontStyle.Bold);
        _overview.TextAlign = ContentAlignment.MiddleLeft;
        _overview.UseCompatibleTextRendering = true;
        _overview.Padding = new Padding(8);
        _market.Dock = DockStyle.Fill;
        _market.Font = new Font(Font.FontFamily, 12F, FontStyle.Bold);
        _market.TextAlign = ContentAlignment.MiddleLeft;
        _market.UseCompatibleTextRendering = true;
        _market.Padding = new Padding(8);
        summaryLayout.Controls.Add(_overview, 0, 0);
        summaryLayout.Controls.Add(_market, 0, 1);
        summary.Controls.Add(summaryLayout);

        _chart.Dock = DockStyle.Fill;
        _chart.Padding = new Padding(45);
        trend.Controls.Add(_chart);

        var historyLayout = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 2, ColumnCount = 1, Padding = new Padding(30) };
        historyLayout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        historyLayout.RowStyles.Add(new RowStyle(SizeType.Absolute, 80));
        _history.Dock = DockStyle.Fill;
        _history.Font = new Font("Microsoft YaHei UI", 11F);
        var reset = DialogLayout.Button("重新开始剧情", (_, _) => { AppServices.ResetStory(); Populate(); });
        reset.Size = new Size(340, 64);
        reset.MinimumSize = new Size(340, 64);
        historyLayout.Controls.Add(_history, 0, 0);
        historyLayout.Controls.Add(reset, 0, 1);
        history.Controls.Add(historyLayout);

        tabs.TabPages.Add(summary);
        tabs.TabPages.Add(trend);
        tabs.TabPages.Add(history);
        return tabs;
    }

    private void Populate()
    {
        AppSettings settings = AppServices.Settings;
        DateOnly today = DateOnly.FromDateTime(DateTime.Today);
        AmountDisplay current = _sizingAmount ?? DebtEngine.AmountForDate(today, settings);
        string Compare(int days) => DebtEngine.AmountForDate(today.AddDays(-days), settings).GroupedDigits;
        string Predict(int days) => DebtEngine.AmountForDate(today.AddDays(days), settings).GroupedDigits;
        int elapsed = DebtEngine.DaysForDate(today, settings);
        _amountSizingLines =
        [
            $"当前：￥{current.GroupedDigits}",
            $"昨日：￥{Compare(1)}",
            $"七日前：￥{Compare(7)}",
            $"三十日前：￥{Compare(30)}",
            $"明日预测：￥{Predict(1)}",
            $"一周后：￥{Predict(7)}",
            $"一年后：￥{Predict(365)}"
        ];
        _overview.Text = $"当前运行：{elapsed + 1:N0} 天\n"
            + $"公式：初始金额 × 1.05 ^ 经过天数，按元四舍五入，最高 99 位\n\n"
            + string.Join("\n", _amountSizingLines.Take(4)) + "\n\n"
            + string.Join("\n", _amountSizingLines.Skip(4));
        _market.Text = "正在获取美元、欧元、日元、港币和黄金行情…";
        FitWindowToAmounts(_amountSizingLines);

        var points = new List<(DateOnly Date, double Value)>();
        for (int day = 30; day >= 0; day--)
        {
            DateOnly date = today.AddDays(-day);
            points.Add((date, DebtEngine.Log10ForChart(DebtEngine.AmountForDate(date, settings))));
        }
        _chart.SetPoints(points);

        _history.Items.Clear();
        _history.Items.Add($"连续签到：{AppServices.Database.CurrentStreak} 天");
        _history.Items.Add($"成就：{string.Join("、", AppServices.Database.Achievements.DefaultIfEmpty("暂无"))}");
        _history.Items.Add("—— 选择记录 ——");
        foreach (ChoiceRecord choice in AppServices.Database.Choices.OrderByDescending(item => item.Time).Take(100))
            _history.Items.Add($"{choice.Time:yyyy-MM-dd HH:mm}  {choice.Choice} → {choice.Result}");
    }

    private async Task LoadMarketsAsync()
    {
        try
        {
            MarketConversions rates = await MarketConversionService.GetAsync(_cancellation.Token);
            AmountDisplay amount = DebtEngine.AmountForDate(DateOnly.FromDateTime(DateTime.Today), AppServices.Settings);
            string usd = ArbitraryMoneyMath.Multiply(amount.Digits, rates.FiatPerCny["USD"], 2);
            string eur = ArbitraryMoneyMath.Multiply(amount.Digits, rates.FiatPerCny["EUR"], 2);
            string jpy = ArbitraryMoneyMath.Multiply(amount.Digits, rates.FiatPerCny["JPY"], 2);
            string hkd = ArbitraryMoneyMath.Multiply(amount.Digits, rates.FiatPerCny["HKD"], 2);
            string gold = rates.GoldCnyPerGram is null
                ? "暂不可用"
                : ArbitraryMoneyMath.DivideByIntegerFactor(amount.Digits, rates.GoldCnyPerGram, 1_000_000, 6) + " 吨";
            if (IsDisposed) return;
            _market.Text = $"多币种实时估值\n美元：${usd}\n欧元：€{eur}\n日元：¥{jpy}\n港币：HK${hkd}\n黄金重量：{gold}\n行情源：{rates.Source}";
            FitWindowToAmounts(_amountSizingLines.Concat(
            [
                $"美元：${usd}",
                $"欧元：€{eur}",
                $"日元：¥{jpy}",
                $"港币：HK${hkd}",
                $"黄金重量：{gold}",
                $"行情源：{rates.Source}"
            ]));
        }
        catch
        {
            if (!IsDisposed) _market.Text = "多币种行情暂不可用，请检查网络。";
        }
    }

    private void FitWindowToAmounts(IEnumerable<string> lines)
    {
        Rectangle work = Screen.FromPoint(Cursor.Position).WorkingArea;
        int maximumClientWidth = Math.Max(940, work.Width - 96);
        int maximumClientHeight = Math.Max(680, work.Height - 96);
        int longest = lines
            .DefaultIfEmpty(string.Empty)
            .Max(line => TextRenderer.MeasureText(
                line,
                _overview.Font,
                new Size(int.MaxValue, int.MaxValue),
                TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix).Width);
        int clientWidth = Math.Clamp(longest + 190, 1180, maximumClientWidth);
        int usableTextWidth = Math.Max(400, clientWidth - 150);
        int extraWraps = Math.Max(0, (int)Math.Ceiling(longest / (double)usableTextWidth) - 1);
        int clientHeight = Math.Clamp(820 + extraWraps * 120, 680, maximumClientHeight);
        MaximumSize = new Size(work.Width - 40, work.Height - 40);
        ClientSize = new Size(clientWidth, clientHeight);
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        _cancellation.Cancel();
        _cancellation.Dispose();
        base.OnFormClosed(e);
    }
}

internal sealed class TrendChart : Control
{
    private IReadOnlyList<(DateOnly Date, double Value)> _points = [];

    internal void SetPoints(IReadOnlyList<(DateOnly Date, double Value)> points)
    {
        _points = points;
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        Rectangle area = Rectangle.Inflate(ClientRectangle, -65, -65);
        if (_points.Count < 2 || area.Width <= 0 || area.Height <= 0) return;
        double min = _points.Min(item => item.Value);
        double max = _points.Max(item => item.Value);
        if (Math.Abs(max - min) < 0.0001) max = min + 1;
        using var axis = new Pen(Color.FromArgb(110, ForeColor), 1);
        using var line = new Pen(Color.FromArgb(AppServices.Settings.AccentArgb), 4);
        e.Graphics.DrawLine(axis, area.Left, area.Bottom, area.Right, area.Bottom);
        e.Graphics.DrawLine(axis, area.Left, area.Top, area.Left, area.Bottom);
        PointF[] points = _points.Select((item, index) => new PointF(
            area.Left + (area.Width * index / (float)(_points.Count - 1)),
            area.Bottom - (float)((item.Value - min) / (max - min) * area.Height))).ToArray();
        e.Graphics.DrawLines(line, points);
        string start = _points[0].Date.ToString("MM-dd");
        string end = _points[^1].Date.ToString("MM-dd");
        using var textBrush = new SolidBrush(ForeColor);
        using var titleFont = new Font(Font, FontStyle.Bold);
        e.Graphics.DrawString(start, Font, textBrush, area.Left, area.Bottom + 12);
        SizeF endSize = e.Graphics.MeasureString(end, Font);
        e.Graphics.DrawString(end, Font, textBrush, area.Right - endSize.Width, area.Bottom + 12);
        e.Graphics.DrawString("欠款增长（对数刻度）", titleFont, textBrush, area.Left, area.Top - 36);
    }
}

internal sealed class MiniAmountForm : Form
{
    private readonly AmountLineControl _amountLine = new();
    private readonly System.Windows.Forms.Timer _dateTimer = new() { Interval = 60_000 };
    private DateOnly _displayedDate;

    internal MiniAmountForm(AmountDisplay? previewAmount = null)
    {
        Text = "欠款迷你窗口";
        StartPosition = FormStartPosition.CenterParent;
        TopMost = true;
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Microsoft YaHei UI", 10F);

        var layout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            RowCount = 2,
            ColumnCount = 1,
            Padding = new Padding(24, 18, 24, 22)
        };
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 62));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        layout.Controls.Add(new Label
        {
            Text = "当前欠款",
            Dock = DockStyle.Fill,
            TextAlign = ContentAlignment.MiddleCenter,
            Font = new Font("Microsoft YaHei UI", 17F, FontStyle.Bold),
            UseCompatibleTextRendering = true
        }, 0, 0);
        _amountLine.Dock = DockStyle.Fill;
        _amountLine.MaximumFontSize = 20F;
        _amountLine.MinimumFontSize = 7F;
        layout.Controls.Add(_amountLine, 0, 1);
        Controls.Add(layout);

        if (previewAmount is null)
        {
            RefreshAmountAndFit();
            _dateTimer.Tick += (_, _) =>
            {
                DateOnly today = DateOnly.FromDateTime(DateTime.Today);
                if (today != _displayedDate) RefreshAmountAndFit();
            };
            _dateTimer.Start();
            AppServices.SettingsChanged += OnSettingsChanged;
        }
        else
        {
            ApplyAmount(previewAmount);
        }
        Theme.Apply(this);
    }

    private void RefreshAmountAndFit()
    {
        _displayedDate = DateOnly.FromDateTime(DateTime.Today);
        ApplyAmount(DebtEngine.AmountForDate(_displayedDate, AppServices.Settings));
    }

    private void ApplyAmount(AmountDisplay amount)
    {
        string text = $"￥{amount.GroupedDigits} 元";
        _amountLine.Text = text;
        Rectangle work = Screen.FromPoint(Cursor.Position).WorkingArea;
        float scale = (float)Math.Clamp(AppServices.Settings.FontScale, 0.75M, 1.75M);
        _amountLine.MaximumFontSize = Math.Clamp(20F * scale, 15F, 28F);
        using var measureFont = new Font("Microsoft YaHei UI", _amountLine.MaximumFontSize, FontStyle.Bold);
        int measuredWidth = TextRenderer.MeasureText(
            text,
            measureFont,
            new Size(int.MaxValue, int.MaxValue),
            TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix).Width;
        int maximumClientWidth = Math.Max(520, work.Width - 80);
        int clientWidth = Math.Clamp(measuredWidth + 110, 620, maximumClientWidth);
        int clientHeight = Math.Clamp((int)(220 * Math.Min(scale, 1.25F)), 210, Math.Max(210, work.Height - 100));
        MinimumSize = new Size(Math.Min(520, maximumClientWidth), 190);
        MaximumSize = new Size(work.Width - 40, work.Height - 40);
        ClientSize = new Size(clientWidth, clientHeight);
        _amountLine.Invalidate();
    }

    private void OnSettingsChanged(object? sender, EventArgs e)
    {
        if (IsDisposed) return;
        RefreshAmountAndFit();
        Theme.Apply(this);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _dateTimer.Dispose();
            AppServices.SettingsChanged -= OnSettingsChanged;
        }
        base.Dispose(disposing);
    }
}
