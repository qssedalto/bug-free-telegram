using System.Drawing.Drawing2D;

namespace 是否认同;

internal static class RoundedGeometry
{
    internal static GraphicsPath CreatePath(Rectangle bounds, int radius)
    {
        var path = new GraphicsPath();
        if (bounds.Width <= 0 || bounds.Height <= 0) return path;

        int diameter = Math.Min(Math.Max(2, radius * 2), Math.Min(bounds.Width, bounds.Height));
        var arc = new Rectangle(bounds.Location, new Size(diameter, diameter));
        path.AddArc(arc, 180, 90);
        arc.X = bounds.Right - diameter;
        path.AddArc(arc, 270, 90);
        arc.Y = bounds.Bottom - diameter;
        path.AddArc(arc, 0, 90);
        arc.X = bounds.Left;
        path.AddArc(arc, 90, 90);
        path.CloseFigure();
        return path;
    }
}

internal sealed class RoundedPanel : Panel
{
    private int _cornerRadius = 26;

    internal int CornerRadius
    {
        get => _cornerRadius;
        set { _cornerRadius = Math.Max(1, value); UpdateRegion(); Invalidate(); }
    }

    internal Color BorderColor { get; set; } = Color.Transparent;
    internal int BorderThickness { get; set; } = 1;

    public RoundedPanel()
    {
        DoubleBuffered = true;
        Resize += (_, _) => UpdateRegion();
    }

    private void UpdateRegion()
    {
        if (ClientSize.Width <= 0 || ClientSize.Height <= 0) return;
        using GraphicsPath path = RoundedGeometry.CreatePath(ClientRectangle, CornerRadius);
        Region?.Dispose();
        Region = new Region(path);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        if (BorderThickness <= 0 || BorderColor == Color.Transparent) return;
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        Rectangle borderBounds = Rectangle.Inflate(ClientRectangle, -1, -1);
        using GraphicsPath path = RoundedGeometry.CreatePath(borderBounds, CornerRadius - 1);
        using var pen = new Pen(BorderColor, BorderThickness);
        e.Graphics.DrawPath(pen, path);
    }
}

internal sealed class RoundedButton : Button
{
    private int _cornerRadius = 14;
    private readonly System.Windows.Forms.Timer _bounceTimer = new() { Interval = 16 };
    private Size _restingSize;
    private float _targetScale = 1F;

    internal int CornerRadius
    {
        get => _cornerRadius;
        set { _cornerRadius = Math.Max(1, value); UpdateRegion(); }
    }

    public RoundedButton()
    {
        FlatStyle = FlatStyle.Flat;
        FlatAppearance.BorderSize = 0;
        UseVisualStyleBackColor = false;
        Cursor = Cursors.Hand;
        Resize += (_, _) => UpdateRegion();
        HandleCreated += (_, _) => { if (_restingSize.IsEmpty) _restingSize = Size; };
        _bounceTimer.Tick += (_, _) => AnimateBounce();
    }

    protected override void OnMouseDown(MouseEventArgs mevent)
    {
        base.OnMouseDown(mevent);
        if (AppServices.Settings.ReduceMotion) return;
        if (_restingSize.IsEmpty) _restingSize = Size;
        _targetScale = 0.94F;
        _bounceTimer.Start();
    }

    protected override void OnMouseUp(MouseEventArgs mevent)
    {
        base.OnMouseUp(mevent);
        if (AppServices.Settings.ReduceMotion) return;
        _targetScale = 1F;
        _bounceTimer.Start();
    }

    private void AnimateBounce()
    {
        if (_restingSize.IsEmpty) { _bounceTimer.Stop(); return; }
        Size target = new(
            Math.Max(1, (int)(_restingSize.Width * _targetScale)),
            Math.Max(1, (int)(_restingSize.Height * _targetScale)));
        int width = Size.Width + (int)Math.Round((target.Width - Size.Width) * 0.45);
        int height = Size.Height + (int)Math.Round((target.Height - Size.Height) * 0.45);
        Size = new Size(width, height);
        if (Math.Abs(Size.Width - target.Width) <= 1 && Math.Abs(Size.Height - target.Height) <= 1)
        {
            Size = target;
            _bounceTimer.Stop();
        }
    }

    private void UpdateRegion()
    {
        if (ClientSize.Width <= 0 || ClientSize.Height <= 0) return;
        using GraphicsPath path = RoundedGeometry.CreatePath(ClientRectangle, CornerRadius);
        Region?.Dispose();
        Region = new Region(path);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) _bounceTimer.Dispose();
        base.Dispose(disposing);
    }
}

internal sealed class AmountLineControl : Control
{
    private readonly System.Windows.Forms.Timer _numberTimer = new() { Interval = 22 };
    private System.Numerics.BigInteger _targetNumber;
    private string _numberPrefix = string.Empty;
    private string _numberSuffix = string.Empty;
    private int _numberFrame;
    internal float MaximumFontSize { get; set; } = 18F;
    internal float MinimumFontSize { get; set; } = 7F;

    public AmountLineControl()
    {
        DoubleBuffered = true;
        SetStyle(
            ControlStyles.UserPaint
            | ControlStyles.AllPaintingInWmPaint
            | ControlStyles.OptimizedDoubleBuffer
            | ControlStyles.ResizeRedraw,
            true);
        _numberTimer.Tick += (_, _) => AnimateNumberFrame();
    }

    internal void AnimateNumber(string prefix, string digits, string suffix)
    {
        if (!System.Numerics.BigInteger.TryParse(digits, out _targetNumber) || AppServices.Settings.ReduceMotion)
        {
            Text = prefix + GroupDigits(digits) + suffix;
            Invalidate();
            return;
        }
        _numberPrefix = prefix;
        _numberSuffix = suffix;
        _numberFrame = 0;
        _numberTimer.Start();
    }

    private void AnimateNumberFrame()
    {
        _numberFrame++;
        const int totalFrames = 28;
        int eased = totalFrames - _numberFrame;
        System.Numerics.BigInteger value = _targetNumber
            - ((_targetNumber * eased * eased) / (totalFrames * totalFrames));
        Text = _numberPrefix + GroupDigits(value.ToString()) + _numberSuffix;
        Invalidate();
        if (_numberFrame >= totalFrames)
        {
            Text = _numberPrefix + GroupDigits(_targetNumber.ToString()) + _numberSuffix;
            _numberTimer.Stop();
        }
    }

    private static string GroupDigits(string digits)
    {
        var result = new System.Text.StringBuilder();
        for (int index = 0; index < digits.Length; index++)
        {
            if (index > 0 && (digits.Length - index) % 3 == 0) result.Append(',');
            result.Append(digits[index]);
        }
        return result.ToString();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        if (string.IsNullOrWhiteSpace(Text) || ClientSize.Width <= 0 || ClientSize.Height <= 0) return;

        float fontSize = MaximumFontSize;
        Font? fittedFont = null;
        while (fontSize >= MinimumFontSize)
        {
            fittedFont?.Dispose();
            fittedFont = new Font("Microsoft YaHei UI", fontSize, FontStyle.Bold, GraphicsUnit.Point);
            Size measured = TextRenderer.MeasureText(
                e.Graphics,
                Text,
                fittedFont,
                new Size(int.MaxValue, ClientSize.Height),
                TextFormatFlags.SingleLine | TextFormatFlags.NoPadding);
            if (measured.Width <= ClientSize.Width - 12) break;
            fontSize -= 0.5F;
        }

        using (fittedFont)
        {
            TextRenderer.DrawText(
                e.Graphics,
                Text,
                fittedFont,
                ClientRectangle,
                ForeColor,
                TextFormatFlags.HorizontalCenter
                    | TextFormatFlags.VerticalCenter
                    | TextFormatFlags.SingleLine
                    | TextFormatFlags.NoPadding
                    | TextFormatFlags.NoPrefix);
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) _numberTimer.Dispose();
        base.Dispose(disposing);
    }
}
