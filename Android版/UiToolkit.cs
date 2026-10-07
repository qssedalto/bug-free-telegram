using Android.Content;
using Android.Content.Res;
using Android.Graphics;
using Android.Graphics.Drawables;
using Android.Util;
using Android.Views;

namespace 是否认同;

internal sealed record AppPalette(
    Color Background,
    Color Card,
    Color Foreground,
    Color Secondary,
    Color Border,
    Color Accent,
    bool Dark)
{
    internal static AppPalette Create(Context context, AppSettings settings)
    {
        bool systemDark = (context.Resources?.Configuration?.UiMode & UiMode.NightMask) == UiMode.NightYes;
        bool dark = settings.Theme switch
        {
            ThemeMode.Light => false,
            ThemeMode.Dark or ThemeMode.PureBlack => true,
            _ => systemDark
        };
        Color accent = new(settings.AccentArgb);
        if (settings.HighContrast)
            return new(Color.Black, Color.Rgb(8, 8, 8), Color.Yellow, Color.White,
                Color.Yellow, accent, true);
        if (settings.Theme == ThemeMode.PureBlack)
            return new(Color.Black, Color.Rgb(10, 10, 10), Color.White,
                Color.Rgb(190, 190, 195), Color.Rgb(70, 70, 74), accent, true);
        return dark
            ? new(Color.Rgb(32, 32, 32), Color.Rgb(44, 44, 46), Color.Rgb(245, 245, 245),
                Color.Rgb(190, 190, 195), Color.Rgb(75, 75, 78), accent, true)
            : new(Color.Rgb(242, 242, 247), Color.White, Color.Rgb(24, 24, 24),
                Color.Rgb(95, 95, 100), Color.Rgb(215, 215, 220), accent, false);
    }
}

internal static class Ui
{
    internal static int Dp(Context context, int value) =>
        (int)TypedValue.ApplyDimension(ComplexUnitType.Dip, value, context.Resources?.DisplayMetrics);

    internal static GradientDrawable Rounded(Color color, float radiusDp, Context context, Color? stroke = null, int strokeDp = 1)
    {
        var drawable = new GradientDrawable();
        drawable.SetColor(color);
        drawable.SetCornerRadius(Dp(context, (int)radiusDp));
        if (stroke is Color border) drawable.SetStroke(Dp(context, strokeDp), border);
        return drawable;
    }

    internal static LinearLayout VBox(Context context, int spacingDp = 0)
    {
        var layout = new LinearLayout(context) { Orientation = Android.Widget.Orientation.Vertical };
        if (spacingDp > 0) layout.SetPadding(0, 0, 0, Dp(context, spacingDp));
        return layout;
    }

    internal static LinearLayout HBox(Context context)
    {
        var layout = new LinearLayout(context) { Orientation = Android.Widget.Orientation.Horizontal };
        layout.SetGravity(GravityFlags.CenterVertical);
        return layout;
    }

    internal static TextView Text(Context context, AppPalette palette, string text, float sp, bool bold = false, GravityFlags gravity = GravityFlags.Left)
    {
        var view = new TextView(context)
        {
            Text = text,
            Gravity = gravity,
            Typeface = bold ? Typeface.DefaultBold : Typeface.Default
        };
        view.SetTextColor(palette.Foreground);
        view.SetTextSize(ComplexUnitType.Sp, sp * AppState.Settings.FontScale);
        view.SetLineSpacing(0, 1.14F);
        return view;
    }

    internal static Button Button(Context context, AppPalette palette, string text, Color? color = null)
    {
        var button = new Button(context) { Text = text };
        button.SetAllCaps(false);
        button.SetTextColor(Color.White);
        button.SetTextSize(ComplexUnitType.Sp, 14F * AppState.Settings.FontScale);
        button.Typeface = Typeface.DefaultBold;
        button.Background = Rounded(color ?? palette.Accent, 16, context);
        button.SetPadding(Dp(context, 12), Dp(context, 7), Dp(context, 12), Dp(context, 7));
        return button;
    }

    internal static LinearLayout Card(Context context, AppPalette palette, int paddingDp = 18)
    {
        var card = VBox(context);
        int padding = Dp(context, paddingDp);
        card.SetPadding(padding, padding, padding, padding);
        card.Background = Rounded(palette.Card, 22, context, palette.Border);
        return card;
    }

    internal static void AddWithMargin(LinearLayout parent, View child, int topDp = 10, int bottomDp = 0)
    {
        var parameters = new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MatchParent, ViewGroup.LayoutParams.WrapContent)
        {
            TopMargin = Dp(parent.Context!, topDp),
            BottomMargin = Dp(parent.Context!, bottomDp)
        };
        parent.AddView(child, parameters);
    }
}

internal sealed class TrendView : View
{
    private IReadOnlyList<double> _points = [];
    private Color _lineColor = Color.Rgb(175, 82, 222);
    private string _leftLabel = "7 日前";
    private string _rightLabel = "今天";
    private readonly Paint _paint = new(PaintFlags.AntiAlias);

    internal TrendView(Context context) : base(context)
    {
        SetLayerType(LayerType.Software, null);
    }

    internal void SetPoints(IReadOnlyList<double> points, Color lineColor, string leftLabel, string rightLabel)
    {
        _points = points;
        _lineColor = lineColor;
        _leftLabel = leftLabel;
        _rightLabel = rightLabel;
        Invalidate();
    }

    protected override void OnDraw(Canvas canvas)
    {
        base.OnDraw(canvas);
        if (_points.Count < 2 || Width <= 0 || Height <= 0) return;
        float density = Resources?.DisplayMetrics?.Density ?? 1F;
        float left = 14 * density;
        float right = Width - (14 * density);
        float top = 14 * density;
        float bottom = Height - (34 * density);
        double min = _points.Min();
        double max = _points.Max();
        if (Math.Abs(max - min) < 0.000001) max = min + 1;

        _paint.Color = Color.Argb(42, _lineColor.R, _lineColor.G, _lineColor.B);
        _paint.SetStyle(Paint.Style.Fill);
        var fill = new Android.Graphics.Path();
        for (int index = 0; index < _points.Count; index++)
        {
            float x = left + ((right - left) * index / (_points.Count - 1F));
            float y = bottom - (float)((_points[index] - min) / (max - min) * (bottom - top));
            if (index == 0) fill.MoveTo(x, bottom);
            fill.LineTo(x, y);
        }
        fill.LineTo(right, bottom);
        fill.Close();
        canvas.DrawPath(fill, _paint);

        _paint.Color = _lineColor;
        _paint.SetStyle(Paint.Style.Stroke);
        _paint.StrokeWidth = 3.2F * density;
        _paint.StrokeCap = Paint.Cap.Round;
        _paint.StrokeJoin = Paint.Join.Round;
        var line = new Android.Graphics.Path();
        for (int index = 0; index < _points.Count; index++)
        {
            float x = left + ((right - left) * index / (_points.Count - 1F));
            float y = bottom - (float)((_points[index] - min) / (max - min) * (bottom - top));
            if (index == 0) line.MoveTo(x, y); else line.LineTo(x, y);
        }
        canvas.DrawPath(line, _paint);

        _paint.SetStyle(Paint.Style.Fill);
        _paint.TextSize = 12 * density;
        _paint.Color = AppPalette.Create(Context!, AppState.Settings).Secondary;
        canvas.DrawText(_leftLabel, left, Height - (8 * density), _paint);
        float width = _paint.MeasureText(_rightLabel);
        canvas.DrawText(_rightLabel, right - width, Height - (8 * density), _paint);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) _paint.Dispose();
        base.Dispose(disposing);
    }
}
