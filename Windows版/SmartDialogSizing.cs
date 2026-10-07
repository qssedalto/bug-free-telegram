namespace 是否认同;

internal static class SmartDialogSizing
{
    internal static void Apply(
        Form form,
        IEnumerable<string?> texts,
        Size minimumClientSize,
        Size preferredClientSize,
        float contentFontSize)
    {
        string[] content = texts
            .Where(text => !string.IsNullOrWhiteSpace(text))
            .Select(text => text!)
            .ToArray();
        Rectangle work = Screen.PrimaryScreen?.WorkingArea ?? new Rectangle(0, 0, 1920, 1080);
        int maximumWidth = Math.Max(minimumClientSize.Width, work.Width - 96);
        int maximumHeight = Math.Max(minimumClientSize.Height, work.Height - 96);
        float fontScale = (float)Math.Clamp(AppServices.Settings.FontScale, 0.75M, 1.75M);
        using var measureFont = new Font(
            "Microsoft YaHei UI",
            Math.Clamp(contentFontSize * fontScale, 9F, 28F),
            FontStyle.Bold,
            GraphicsUnit.Point);

        int longestSingleLine = content.Length == 0
            ? 0
            : content.Max(text => TextRenderer.MeasureText(
                text.ReplaceLineEndings(" "),
                measureFont,
                new Size(int.MaxValue, int.MaxValue),
                TextFormatFlags.SingleLine | TextFormatFlags.NoPadding).Width);
        int comfortableWidth = Math.Max(300, preferredClientSize.Width - 190);
        int widthGrowth = Math.Max(0, longestSingleLine - comfortableWidth) / 2;
        int clientWidth = Math.Clamp(preferredClientSize.Width + widthGrowth, minimumClientSize.Width, maximumWidth);

        int textWidth = Math.Max(260, clientWidth - 190);
        int tallestWrappedText = content.Length == 0
            ? measureFont.Height
            : content.Max(text => TextRenderer.MeasureText(
                text,
                measureFont,
                new Size(textWidth, maximumHeight),
                TextFormatFlags.WordBreak | TextFormatFlags.NoPadding).Height);
        int normalTwoLines = measureFont.Height * 2 + 8;
        int heightGrowth = Math.Max(0, tallestWrappedText - normalTwoLines) + Math.Max(0, content.Length - 5) * 4;
        int clientHeight = Math.Clamp(preferredClientSize.Height + heightGrowth, minimumClientSize.Height, maximumHeight);

        form.MinimumSize = new Size(
            Math.Min(minimumClientSize.Width, clientWidth),
            Math.Min(minimumClientSize.Height, clientHeight));
        form.ClientSize = new Size(clientWidth, clientHeight);
    }

    internal static void FitToOwnerScreen(Form form)
    {
        Control reference = form.Owner ?? form;
        Rectangle area = Screen.FromControl(reference).WorkingArea;
        int width = Math.Min(form.Width, Math.Max(1, area.Width - 64));
        int height = Math.Min(form.Height, Math.Max(1, area.Height - 64));
        form.MinimumSize = new Size(
            Math.Min(form.MinimumSize.Width, width),
            Math.Min(form.MinimumSize.Height, height));
        form.Size = new Size(width, height);
        form.Location = new Point(
            area.Left + (area.Width - width) / 2,
            area.Top + (area.Height - height) / 2);
    }
}
