using System.Drawing.Drawing2D;

namespace 是否认同;

internal sealed class FittedTextControl : Control
{
    internal float MaximumFontSize { get; set; } = 20F;
    internal float MinimumFontSize { get; set; } = 9F;
    internal FontStyle TextStyle { get; set; } = FontStyle.Bold;
    internal ContentAlignment TextAlign { get; set; } = ContentAlignment.MiddleLeft;

    public FittedTextControl()
    {
        DoubleBuffered = true;
        SetStyle(ControlStyles.ResizeRedraw | ControlStyles.OptimizedDoubleBuffer, true);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        if (string.IsNullOrWhiteSpace(Text) || Width <= 0 || Height <= 0) return;
        int safeInset = Math.Max(4, (int)Math.Ceiling(DeviceDpi / 96F * 4F));
        int availableWidth = Math.Max(1, Width - Padding.Horizontal - safeInset * 2);
        int availableHeight = Math.Max(1, Height - Padding.Vertical - safeInset * 2);
        float compactScale = 0.70F + ((float)Math.Clamp(AppServices.Settings.FontScale, 0.75M, 1.75M) * 0.20F);
        float size = MaximumFontSize * compactScale;
        Font? fitted = null;
        while (size >= MinimumFontSize)
        {
            fitted?.Dispose();
            fitted = new Font("Microsoft YaHei UI", size, TextStyle, GraphicsUnit.Point);
            Size measured = TextRenderer.MeasureText(
                e.Graphics,
                Text,
                fitted,
                new Size(int.MaxValue, availableHeight),
                TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix);
            if (measured.Width <= availableWidth && measured.Height <= availableHeight) break;
            size -= 0.5F;
        }

        TextFormatFlags alignment = TextAlign switch
        {
            ContentAlignment.MiddleCenter => TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter,
            ContentAlignment.MiddleRight => TextFormatFlags.Right | TextFormatFlags.VerticalCenter,
            _ => TextFormatFlags.Left | TextFormatFlags.VerticalCenter
        };
        Rectangle bounds = new(
            Padding.Left + safeInset,
            Padding.Top + safeInset,
            availableWidth,
            availableHeight);
        using (fitted)
        {
            TextRenderer.DrawText(
                e.Graphics,
                Text,
                fitted,
                bounds,
                ForeColor,
                alignment | TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix | TextFormatFlags.EndEllipsis);
        }
    }
}

internal sealed class MiniTrendControl : Control
{
    private IReadOnlyList<double> _points = [];
    internal Color LineColor { get; set; } = Color.FromArgb(175, 82, 222);

    public MiniTrendControl()
    {
        DoubleBuffered = true;
        Cursor = Cursors.Hand;
        SetStyle(ControlStyles.ResizeRedraw | ControlStyles.OptimizedDoubleBuffer, true);
    }

    internal void SetPoints(IReadOnlyList<double> points)
    {
        _points = points;
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        int horizontalInset = Math.Max(28, (int)Math.Ceiling(DeviceDpi / 96F * 28F));
        int rightInset = Math.Max(44, (int)Math.Ceiling(DeviceDpi / 96F * 44F));
        // Width/Height are already DPI-scaled by WinForms. Derive the vertical
        // reserves from the real control height to avoid applying DPI twice.
        int topInset = Math.Clamp(Height / 5, 14, 22);
        int labelReserve = Math.Clamp(Height / 3, 28, 34);
        Rectangle area = new(
            horizontalInset,
            topInset,
            Math.Max(1, Width - horizontalInset - rightInset),
            Math.Max(1, Height - topInset - labelReserve));
        if (_points.Count < 2 || area.Width < 2 || area.Height < 2) return;
        double min = _points.Min();
        double max = _points.Max();
        if (Math.Abs(max - min) < 0.0001) max = min + 1;
        PointF[] points = _points.Select((value, index) => new PointF(
            area.Left + area.Width * index / (float)(_points.Count - 1),
            area.Bottom - (float)((value - min) / (max - min) * area.Height))).ToArray();

        using var fillPath = new GraphicsPath();
        fillPath.AddLines(points);
        fillPath.AddLine(points[^1].X, area.Bottom, points[0].X, area.Bottom);
        fillPath.CloseFigure();
        using var fill = new LinearGradientBrush(area, Color.FromArgb(80, LineColor), Color.FromArgb(3, LineColor), 90F);
        using var pen = new Pen(LineColor, 3F) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round };
        e.Graphics.FillPath(fill, fillPath);
        e.Graphics.DrawLines(pen, points);
        using var dot = new SolidBrush(LineColor);
        e.Graphics.FillEllipse(dot, points[^1].X - 4, points[^1].Y - 4, 8, 8);

        var labelArea = new Rectangle(area.Left, Math.Max(0, Height - 29), area.Width, 25);
        TextRenderer.DrawText(
            e.Graphics,
            "7 日前",
            Font,
            labelArea,
            ForeColor,
            TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
        TextRenderer.DrawText(
            e.Graphics,
            "今天  ↗",
            Font,
            labelArea,
            ForeColor,
            TextFormatFlags.Right | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
    }
}

internal sealed class RouteProgressControl : Control
{
    private readonly string[] _names = ["蓝色档案", "绿色共振", "红色逃离"];
    private readonly Color[] _colors =
    [
        Color.FromArgb(10, 132, 255),
        Color.FromArgb(48, 209, 88),
        Color.FromArgb(255, 69, 58)
    ];
    private readonly int[] _counts = new int[3];
    private readonly int[] _totals = [1000, 1000, 2000];

    public RouteProgressControl()
    {
        DoubleBuffered = true;
        SetStyle(ControlStyles.ResizeRedraw | ControlStyles.OptimizedDoubleBuffer, true);
    }

    internal void SetCounts(int agree, int strongAgree, int disagree, int agreeTotal, int strongAgreeTotal, int disagreeTotal)
    {
        _counts[0] = Math.Max(0, agree);
        _counts[1] = Math.Max(0, strongAgree);
        _counts[2] = Math.Max(0, disagree);
        _totals[0] = Math.Max(1, agreeTotal);
        _totals[1] = Math.Max(1, strongAgreeTotal);
        _totals[2] = Math.Max(1, disagreeTotal);
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        int rowHeight = Math.Max(1, Height / 3);
        for (int index = 0; index < 3; index++)
        {
            int top = index * rowHeight;
            string count = $"{Math.Min(_counts[index], _totals[index]):N0} / {_totals[index]:N0}";
            TextRenderer.DrawText(e.Graphics, _names[index], Font, new Point(4, top), ForeColor);
            Size countSize = TextRenderer.MeasureText(count, Font);
            TextRenderer.DrawText(e.Graphics, count, Font, new Point(Math.Max(4, Width - countSize.Width - 4), top), ForeColor);
            int trackTop = Math.Min(top + rowHeight - 7, top + 23);
            var track = new Rectangle(4, Math.Max(top + 17, trackTop), Math.Max(10, Width - 8), 6);
            using var trackPath = RoundedGeometry.CreatePath(track, 4);
            using var trackBrush = new SolidBrush(Color.FromArgb(45, ForeColor));
            e.Graphics.FillPath(trackBrush, trackPath);
            float progress = Math.Min(1F, _counts[index] / (float)_totals[index]);
            var value = new Rectangle(track.X, track.Y, Math.Max(progress > 0 ? 8 : 0, (int)(track.Width * progress)), track.Height);
            if (value.Width > 0)
            {
                using var valuePath = RoundedGeometry.CreatePath(value, 4);
                using var valueBrush = new SolidBrush(_colors[index]);
                e.Graphics.FillPath(valueBrush, valuePath);
            }
        }
    }
}
