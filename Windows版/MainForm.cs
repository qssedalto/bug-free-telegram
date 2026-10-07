using Microsoft.Win32;

namespace 是否认同;

internal sealed class LegacyMainForm : Form
{
    private readonly AmountDisplay _amount;
    private bool _warning;

    internal LegacyMainForm()
    {
        int n = DebtTimeline.NForDate(DateOnly.FromDateTime(DateTime.Today));
        _amount = SafeCalculation.CalculateAmount(n);

        Text = "开发者の问题🙋";
        StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(920, 700);
        ClientSize = new Size(1180, 820);
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Microsoft YaHei UI", 11F, FontStyle.Regular, GraphicsUnit.Point);

        Controls.Add(BuildLayout());
        Theme.Apply(this);

        Activated += (_, _) => ApplyCurrentTheme();
        SystemEvents.UserPreferenceChanged += OnUserPreferenceChanged;
        FormClosed += (_, _) => SystemEvents.UserPreferenceChanged -= OnUserPreferenceChanged;
    }

    private Control BuildLayout()
    {
        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 4,
            Padding = new Padding(34, 22, 34, 30)
        };
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 105));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 55));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 286));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 45));

        var title = new Label
        {
            Text = "开发者の问题🙋",
            Dock = DockStyle.Fill,
            AutoSize = false,
            Font = new Font(Font.FontFamily, 24F, FontStyle.Bold),
            TextAlign = ContentAlignment.MiddleLeft,
            Padding = new Padding(8, 0, 0, 0),
            UseCompatibleTextRendering = true
        };

        var question = new Label
        {
            Text = "是否认同焦晨阳是大傻福？",
            Dock = DockStyle.Fill,
            AutoSize = false,
            Font = new Font(Font.FontFamily, 22F, FontStyle.Bold),
            TextAlign = ContentAlignment.MiddleCenter,
            Padding = new Padding(24),
            UseCompatibleTextRendering = true
        };

        var buttons = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 3,
            Tag = "inherit"
        };
        buttons.RowStyles.Add(new RowStyle(SizeType.Percent, 33.333F));
        buttons.RowStyles.Add(new RowStyle(SizeType.Percent, 33.333F));
        buttons.RowStyles.Add(new RowStyle(SizeType.Percent, 33.334F));
        buttons.Controls.Add(ActionButton("认同", Color.FromArgb(10, 132, 255), ShowConfirmation), 0, 0);
        buttons.Controls.Add(ActionButton("非常认同", Color.FromArgb(48, 209, 88), ShowImmediateRecognition), 0, 1);
        buttons.Controls.Add(ActionButton("不认同", Color.FromArgb(255, 69, 58), ShowWarning), 0, 2);

        root.Controls.Add(title, 0, 0);
        root.Controls.Add(question, 0, 1);
        root.Controls.Add(buttons, 0, 2);
        return root;
    }

    private static RoundedButton ActionButton(string text, Color color, EventHandler action)
    {
        var button = new RoundedButton
        {
            Text = text,
            Size = new Size(250, 64),
            BackColor = color,
            ForeColor = Color.White,
            Font = new Font("Microsoft YaHei UI", 13F, FontStyle.Bold),
            Tag = "themeAccent",
            Anchor = AnchorStyles.None,
            CornerRadius = 16
        };
        button.FlatAppearance.MouseOverBackColor = ControlPaint.Light(color, 0.08F);
        button.FlatAppearance.MouseDownBackColor = ControlPaint.Dark(color, 0.08F);
        button.Click += action;
        return button;
    }

    private void ShowConfirmation(object? sender, EventArgs e)
    {
        using var dialog = new ConfirmationDialog(_amount);
        dialog.ShowDialog(this);
    }

    private void ShowImmediateRecognition(object? sender, EventArgs e)
    {
        using var dialog = new MessageDialog(
            "你的观点非常赞",
            "正确的",
            "那么请你尝试按一下不认同按钮",
            warning: false);
        dialog.ShowDialog(this);
    }

    private void ShowWarning(object? sender, EventArgs e)
    {
        _warning = true;
        ApplyCurrentTheme();
        using var dialog = new MessageDialog(
            "警告⚠️ 你已被 SCP-♾️ 焦晨阳追杀！请尽快逃离！",
            "逃离",
            (string?)null,
            warning: true);
        dialog.ShowDialog(this);
        _warning = false;
        ApplyCurrentTheme();
    }

    private void OnUserPreferenceChanged(object sender, UserPreferenceChangedEventArgs e)
    {
        if (IsDisposed) return;
        if (InvokeRequired) BeginInvoke(ApplyCurrentTheme);
        else ApplyCurrentTheme();
    }

    private void ApplyCurrentTheme() => Theme.Apply(this, _warning);
}

internal sealed class ConfirmationDialog : Form
{
    private readonly AmountDisplay _amount;
    private readonly TableLayoutPanel _details;
    private readonly AmountLineControl _amountLine;
    private readonly AmountLineControl _bitcoinLine;
    private readonly RoundedButton _copyBitcoinButton;
    private readonly RoundedButton _actionButton;
    private readonly Label _endingLabel;
    private readonly AgreeStory _story;
    private readonly CancellationTokenSource _quoteCancellation = new();
    private string? _latestBitcoin;
    private int _stage;
    private bool _suppressPersistence;

    internal ConfirmationDialog(AmountDisplay amount, AgreeStory? story = null)
    {
        _amount = amount;
        _story = story ?? StoryContent.NextAgree(AppServices.Settings);
        Text = _story.Title;
        StartPosition = FormStartPosition.CenterParent;
        ShowInTaskbar = false;
        MinimizeBox = false;
        MaximizeBox = false;
        MinimumSize = new Size(1180, 800);
        ClientSize = new Size(1460, 920);
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Microsoft YaHei UI", 11F, FontStyle.Regular, GraphicsUnit.Point);
        ResizeForStage(0);

        var root = DialogLayout.CreateRoot();
        root.RowStyles[0].Height = 170;
        root.RowStyles[2].Height = 110;
        var heading = DialogLayout.Heading(Text, 20F);
        _amountLine = new AmountLineControl
        {
            Text = $"￥{_amount.GroupedDigits} 元",
            Dock = DockStyle.Fill,
            MaximumFontSize = 18F,
            MinimumFontSize = 7F,
            Tag = "inherit"
        };
        _bitcoinLine = new AmountLineControl
        {
            Text = "相当于：等待获取实时比特币行情…",
            Dock = DockStyle.Fill,
            MaximumFontSize = 14F,
            MinimumFontSize = 7F,
            Tag = "inherit"
        };
        RoundedButton copyCny = SmallButton("复制人民币", (_, _) => CopyText($"￥{_amount.GroupedDigits} 元"));
        _copyBitcoinButton = SmallButton("复制 BTC", (_, _) => { if (_latestBitcoin is not null) CopyText(_latestBitcoin + " BTC"); });
        _copyBitcoinButton.Enabled = false;
        var copyPanel = new FlowLayoutPanel
        {
            Anchor = AnchorStyles.None,
            AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink,
            FlowDirection = FlowDirection.LeftToRight,
            WrapContents = false,
            Padding = new Padding(0),
            Tag = "inherit"
        };
        copyPanel.Controls.Add(copyCny);
        copyPanel.Controls.Add(_copyBitcoinButton);
        _details = BuildDetails(_amountLine, _bitcoinLine, copyPanel);
        _details.Visible = false;
        _endingLabel = DialogLayout.Text(_story.Epilogue, 16F);
        _endingLabel.Visible = false;
        _actionButton = DialogLayout.Button(_story.FirstButtonText, OnButtonClick);

        root.Controls.Add(heading, 0, 0);
        root.Controls.Add(_details, 0, 1);
        root.Controls.Add(_endingLabel, 0, 1);
        root.Controls.Add(_actionButton, 0, 2);
        Controls.Add(root);

        Theme.Apply(this);
    }

    private TableLayoutPanel BuildDetails(
        AmountLineControl amountLine,
        AmountLineControl bitcoinLine,
        FlowLayoutPanel copyPanel)
    {
        var details = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 6,
            Padding = new Padding(24, 0, 24, 0),
            Tag = "inherit"
        };
        details.RowStyles.Add(new RowStyle(SizeType.Absolute, 128));
        details.RowStyles.Add(new RowStyle(SizeType.Absolute, 82));
        details.RowStyles.Add(new RowStyle(SizeType.Absolute, 68));
        details.RowStyles.Add(new RowStyle(SizeType.Absolute, 44));
        details.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        details.RowStyles.Add(new RowStyle(SizeType.Absolute, 72));

        string intro = $"{_story.Prelude}\n{_story.DetailIntroduction}";
        details.Controls.Add(DialogLayout.Text(intro, 12.5F), 0, 0);
        details.Controls.Add(amountLine, 0, 1);
        details.Controls.Add(bitcoinLine, 0, 2);
        details.Controls.Add(copyPanel, 0, 3);
        details.Controls.Add(DialogLayout.Text(
            $"人民币：{_amount.Chinese}{(_amount.IsCapped ? "\n（金额已达到99位上限）" : string.Empty)}",
            12F), 0, 4);
        details.Controls.Add(DialogLayout.Text(_story.Acknowledgement, 12F), 0, 5);
        return details;
    }

    private void OnButtonClick(object? sender, EventArgs e)
    {
        if (_stage >= 2)
        {
            Close();
            return;
        }

        if (_stage == 1)
        {
            _stage = 2;
            _details.Visible = false;
            _endingLabel.Visible = true;
            _endingLabel.BringToFront();
            _actionButton.Text = AppServices.Settings.English ? "Close" : "关闭";
            ResizeForStage(2);
            if (!_suppressPersistence) AppServices.RecordChoice("认同结尾", _story.Epilogue);
            return;
        }

        _stage = 1;
        ResizeForStage(1);
        _details.Visible = true;
        _amountLine.AnimateNumber("￥", _amount.Digits, " 元");
        _amountLine.Visible = true;
        _amountLine.BringToFront();
        _actionButton.Text = _story.RevealButtonText;
        _details.PerformLayout();
        _amountLine.Invalidate();
        _amountLine.Update();
        _ = LoadBitcoinQuoteAsync();
    }

    private void ResizeForStage(int stage)
    {
        if (stage == 0)
        {
            SmartDialogSizing.Apply(
                this,
                [Text, _story.FirstButtonText],
                new Size(900, 620),
                new Size(1040, 680),
                18F);
        }
        else if (stage == 1)
        {
            SmartDialogSizing.Apply(
                this,
                [_story.Prelude, _amount.Digits, _amount.Chinese, _story.RevealButtonText],
                new Size(1180, 800),
                new Size(1460, 920),
                13F);
        }
        else
        {
            SmartDialogSizing.Apply(
                this,
                [_story.Epilogue, AppServices.Settings.English ? "Close" : "关闭"],
                new Size(900, 620),
                new Size(1040, 680),
                16F);
        }
        if (Visible && Owner is not null) SmartDialogSizing.FitToOwnerScreen(this);
        PerformLayout();
    }

    internal void RevealForPreview() => OnButtonClick(null, EventArgs.Empty);
    internal void AdvanceForPreview()
    {
        _suppressPersistence = true;
        try { OnButtonClick(null, EventArgs.Empty); }
        finally { _suppressPersistence = false; }
    }
    internal bool QuoteFinishedForPreview => !_bitcoinLine.Text.Contains("等待", StringComparison.Ordinal);

    private async Task LoadBitcoinQuoteAsync()
    {
        try
        {
            BitcoinQuote quote = await BitcoinQuoteService.GetAsync(_quoteCancellation.Token);
            string bitcoins = BitcoinMath.ConvertCnyToBitcoin(_amount.Digits, quote.CnyPerBitcoin);
            if (IsDisposed || _quoteCancellation.IsCancellationRequested) return;

            _bitcoinLine.Text = $"相当于：{bitcoins} BTC";
            _latestBitcoin = bitcoins;
            _copyBitcoinButton.Enabled = true;
            _bitcoinLine.Invalidate();
        }
        catch (OperationCanceledException) when (_quoteCancellation.IsCancellationRequested)
        {
        }
        catch
        {
            if (IsDisposed || _quoteCancellation.IsCancellationRequested) return;
            _bitcoinLine.Text = "比特币估值暂不可用，请检查网络后重试";
            _bitcoinLine.Invalidate();
        }
    }

    private static RoundedButton SmallButton(string text, EventHandler click)
    {
        RoundedButton button = DialogLayout.Button(text, click);
        button.Size = new Size(155, 38);
        button.Font = new Font("Microsoft YaHei UI", 9F, FontStyle.Bold);
        button.Margin = new Padding(8, 2, 8, 2);
        return button;
    }

    private void CopyText(string text)
    {
        try { Clipboard.SetText(text); }
        catch (System.Runtime.InteropServices.ExternalException) { }
    }

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        if (Owner is null) return;
        SmartDialogSizing.FitToOwnerScreen(this);
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        _quoteCancellation.Cancel();
        _quoteCancellation.Dispose();
        base.OnFormClosed(e);
    }
}

internal sealed class MessageDialog : Form
{
    private readonly string[] _messages;
    private readonly Label _message;
    private readonly RoundedButton _actionButton;
    private readonly bool _warning;
    private int _messageIndex;

    internal MessageDialog(string title, string buttonText, string? secondMessage, bool warning)
        : this(title, buttonText, secondMessage is null ? [] : [secondMessage], warning, false)
    {
    }

    internal MessageDialog(string title, string buttonText, IReadOnlyList<string> messages, bool warning)
        : this(title, buttonText, messages, warning, true)
    {
    }

    private MessageDialog(string title, string buttonText, IReadOnlyList<string> messages, bool warning, bool showFirst)
    {
        _messages = messages.Where(text => !string.IsNullOrWhiteSpace(text)).ToArray();
        _messageIndex = showFirst && _messages.Length > 0 ? 0 : -1;
        _warning = warning;
        Text = title;
        StartPosition = FormStartPosition.CenterParent;
        ShowInTaskbar = false;
        MinimizeBox = false;
        MaximizeBox = false;
        MinimumSize = new Size(940, 650);
        ClientSize = new Size(1080, 720);
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Microsoft YaHei UI", 11F, FontStyle.Regular, GraphicsUnit.Point);
        ResizeForCurrentMessage(buttonText);

        var root = DialogLayout.CreateRoot();
        _message = DialogLayout.Text(_messageIndex >= 0 ? _messages[_messageIndex] : string.Empty, 15F);
        _actionButton = DialogLayout.Button(buttonText, OnButtonClick);
        root.Controls.Add(DialogLayout.Heading(title, warning ? 19F : 20F), 0, 0);
        root.Controls.Add(_message, 0, 1);
        root.Controls.Add(_actionButton, 0, 2);
        Controls.Add(root);
        Theme.Apply(this, warning);
    }

    private void OnButtonClick(object? sender, EventArgs e)
    {
        int next = _messageIndex + 1;
        if (next < _messages.Length)
        {
            _messageIndex = next;
            _message.Text = _messages[_messageIndex];
            _actionButton.Text = _messageIndex == _messages.Length - 1
                ? (AppServices.Settings.English ? "Finish" : "结束")
                : (AppServices.Settings.English ? "Continue" : "继续");
            ResizeForCurrentMessage(_actionButton.Text);
        }
        else
        {
            Close();
        }
    }

    private void ResizeForCurrentMessage(string buttonText)
    {
        string current = _messageIndex >= 0 && _messageIndex < _messages.Length
            ? _messages[_messageIndex]
            : string.Empty;
        SmartDialogSizing.Apply(
            this,
            [Text, current, buttonText],
            new Size(880, 600),
            new Size(980, 660),
            15F);
        if (Visible && Owner is not null) SmartDialogSizing.FitToOwnerScreen(this);
        PerformLayout();
    }

    internal void AdvanceForPreview() => OnButtonClick(null, EventArgs.Empty);

    protected override void OnActivated(EventArgs e)
    {
        base.OnActivated(e);
        Theme.Apply(this, _warning);
    }

    protected override void OnShown(EventArgs e)
    {
        SmartDialogSizing.FitToOwnerScreen(this);
        base.OnShown(e);
    }
}

internal static class DialogLayout
{
    internal static TableLayoutPanel CreateRoot()
    {
        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            ColumnCount = 1,
            RowCount = 3,
            Padding = new Padding(58, 38, 58, 42)
        };
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 150));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 94));
        return root;
    }

    internal static Label Heading(string text, float fontSize) => new()
    {
        Text = text,
        Dock = DockStyle.Fill,
        AutoSize = false,
        Font = new Font("Microsoft YaHei UI", fontSize, FontStyle.Bold),
        TextAlign = ContentAlignment.MiddleCenter,
        Padding = new Padding(20),
        UseCompatibleTextRendering = true
    };

    internal static Label Text(string text, float fontSize) => new()
    {
        Text = text,
        Dock = DockStyle.Fill,
        AutoSize = false,
        Font = new Font("Microsoft YaHei UI", fontSize, FontStyle.Bold),
        TextAlign = ContentAlignment.MiddleCenter,
        Padding = new Padding(10),
        UseCompatibleTextRendering = true
    };

    internal static RoundedButton Button(string text, EventHandler click)
    {
        var button = new RoundedButton
        {
            Text = text,
            Size = new Size(230, 64),
            BackColor = Color.FromArgb(175, 82, 222),
            ForeColor = Color.White,
            Font = new Font("Microsoft YaHei UI", 13F, FontStyle.Bold),
            Tag = "themeAccent",
            Anchor = AnchorStyles.None,
            CornerRadius = 16
        };
        button.FlatAppearance.MouseOverBackColor = Color.FromArgb(191, 99, 231);
        button.FlatAppearance.MouseDownBackColor = Color.FromArgb(151, 63, 198);
        button.Click += click;
        return button;
    }
}
