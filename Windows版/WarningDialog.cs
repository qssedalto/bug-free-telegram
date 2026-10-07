namespace 是否认同;

internal sealed class WarningDialog : Form
{
    private readonly IReadOnlyList<string> _escapeResults;
    private readonly Label _countdown;
    private readonly Label _result;
    private readonly RoundedButton _escape;
    private readonly System.Windows.Forms.Timer _countdownTimer = new() { Interval = 1000 };
    private readonly System.Windows.Forms.Timer _pulseTimer = new() { Interval = 45 };
    private int _seconds = 10;
    private int _pulseStep;
    private int _countdownClicks;
    private bool _finished;

    internal WarningDialog(WarningStory story)
    {
        _escapeResults = story.EscapeResults;
        Text = story.Title;
        StartPosition = FormStartPosition.CenterParent;
        ClientSize = new Size(1080, 720);
        MinimumSize = new Size(940, 650);
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Microsoft YaHei UI", 11F);
        SmartDialogSizing.Apply(
            this,
            [story.Title, story.Prompt, "逃离倒计时：10 秒", "逃离"],
            new Size(900, 620),
            new Size(1040, 680),
            14F);
        var root = DialogLayout.CreateRoot();
        root.RowStyles[0].Height = 175;
        var title = DialogLayout.Heading(story.Title, 19F);
        var center = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 3, ColumnCount = 1 };
        center.RowStyles.Add(new RowStyle(SizeType.Absolute, 115));
        center.RowStyles.Add(new RowStyle(SizeType.Absolute, 75));
        center.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        var prompt = DialogLayout.Text(story.Prompt, 14F);
        _countdown = DialogLayout.Text("逃离倒计时：10 秒", 17F);
        _result = DialogLayout.Text(string.Empty, 14F);
        _countdown.Click += (_, _) => CheckCountdownEgg();
        center.Controls.Add(prompt, 0, 0);
        center.Controls.Add(_countdown, 0, 1);
        center.Controls.Add(_result, 0, 2);
        _escape = DialogLayout.Button("逃离", OnEscape);
        root.Controls.Add(title, 0, 0);
        root.Controls.Add(center, 0, 1);
        root.Controls.Add(_escape, 0, 2);
        Controls.Add(root);
        Theme.Apply(this, true);

        _countdownTimer.Tick += (_, _) => TickCountdown();
        _pulseTimer.Tick += (_, _) => TickPulse();
        Shown += (_, _) =>
        {
            _countdownTimer.Start();
            if (!AppServices.Settings.ReduceMotion) _pulseTimer.Start();
        };
    }

    private void TickCountdown()
    {
        _seconds--;
        _countdown.Text = $"逃离倒计时：{Math.Max(0, _seconds)} 秒";
        if (_seconds <= 0) FinishEscape("倒计时结束，系统自动为你选择了一条逃离路线。");
    }

    private void TickPulse()
    {
        _pulseStep = (_pulseStep + 1) % 120;
        double wave = (Math.Sin(_pulseStep / 120d * Math.PI * 2) + 1) / 2;
        int red = 185 + (int)(25 * wave);
        BackColor = Color.FromArgb(red, 32, 40);
    }

    private void OnEscape(object? sender, EventArgs e)
    {
        if (_finished) { Close(); return; }
        FinishEscape(_escapeResults[Random.Shared.Next(_escapeResults.Count)]);
    }

    private void CheckCountdownEgg()
    {
        _countdownClicks++;
        if (_countdownClicks != 4 || _finished) return;
        _seconds += 5;
        _countdown.Text = $"隐藏加时：{_seconds} 秒";
        _result.Text = "⏳ 你敲了四次倒计时，系统偷偷多给了五秒。";
        AppServices.UnlockAchievement("倒计时操纵者");
        AppServices.RecordChoice("警告彩蛋", "获得五秒隐藏加时");
    }

    private void FinishEscape(string result, bool persist = true)
    {
        if (_finished) return;
        _finished = true;
        _countdownTimer.Stop();
        _pulseTimer.Stop();
        _countdown.Text = "警报已解除";
        _result.Text = result;
        _escape.Text = "关闭";
        ResizeForResult(result);
        if (persist) AppServices.RecordChoice("逃离结果", result);
    }

    internal void FinishForPreview(string result) => FinishEscape(result, persist: false);

    private void ResizeForResult(string result)
    {
        SmartDialogSizing.Apply(
            this,
            [Text, "警报已解除", result, "关闭"],
            new Size(880, 600),
            new Size(980, 660),
            14F);
        if (Visible && Owner is not null) SmartDialogSizing.FitToOwnerScreen(this);
        PerformLayout();
    }

    protected override void OnShown(EventArgs e)
    {
        SmartDialogSizing.FitToOwnerScreen(this);
        base.OnShown(e);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _countdownTimer.Dispose();
            _pulseTimer.Dispose();
        }
        base.Dispose(disposing);
    }
}
