using System.Drawing.Imaging;

namespace 是否认同;

internal static class PreviewRenderer
{
    internal static int RenderMain(string outputPath, Size clientSize)
    {
        try
        {
            using var form = new MainForm(previewMode: true)
            {
                StartPosition = FormStartPosition.Manual,
                Location = new Point(-20_000, -20_000),
                ClientSize = clientSize
            };
            form.Show();
            Application.DoEvents();
            Thread.Sleep(120);
            Application.DoEvents();
            string? directory = Path.GetDirectoryName(Path.GetFullPath(outputPath));
            if (!string.IsNullOrWhiteSpace(directory)) Directory.CreateDirectory(directory);
            using var bitmap = new Bitmap(form.Width, form.Height);
            form.DrawToBitmap(bitmap, new Rectangle(Point.Empty, bitmap.Size));
            bitmap.Save(outputPath, ImageFormat.Png);
            form.Close();
            return 0;
        }
        catch (Exception exception)
        {
            try { File.WriteAllText(outputPath + ".error.txt", exception.ToString()); }
            catch { }
            return 1;
        }
    }

    internal static int RenderConfirmation(string outputPath)
    {
        try
        {
            AmountDisplay amount = DebtEngine.AmountForDate(
                DateOnly.FromDateTime(DateTime.Today),
                AppServices.Settings);
            using var dialog = new ConfirmationDialog(amount)
            {
                StartPosition = FormStartPosition.Manual,
                Location = new Point(-20_000, -20_000)
            };
            dialog.Show();
            dialog.RevealForPreview();
            var timeout = System.Diagnostics.Stopwatch.StartNew();
            while (!dialog.QuoteFinishedForPreview && timeout.Elapsed < TimeSpan.FromSeconds(9))
            {
                Application.DoEvents();
                Thread.Sleep(50);
            }
            Application.DoEvents();

            string? directory = Path.GetDirectoryName(Path.GetFullPath(outputPath));
            if (!string.IsNullOrWhiteSpace(directory)) Directory.CreateDirectory(directory);

            using var bitmap = new Bitmap(dialog.Width, dialog.Height);
            dialog.DrawToBitmap(bitmap, new Rectangle(Point.Empty, bitmap.Size));
            bitmap.Save(outputPath, ImageFormat.Png);
            dialog.Close();
            return 0;
        }
        catch (Exception exception)
        {
            try { File.WriteAllText(outputPath + ".error.txt", exception.ToString()); }
            catch { }
            return 1;
        }
    }

    internal static int RenderMiniAmount(string outputPath, bool maximumAmount)
    {
        AmountDisplay amount = maximumAmount
            ? SafeCalculation.CalculateAmount(int.MaxValue)
            : DebtEngine.AmountForDate(DateOnly.FromDateTime(DateTime.Today), AppServices.Settings);
        return RenderForm(outputPath, new MiniAmountForm(amount));
    }

    internal static int RenderDashboard(string outputPath, bool maximumAmount)
    {
        AmountDisplay? amount = maximumAmount ? SafeCalculation.CalculateAmount(int.MaxValue) : null;
        return RenderForm(outputPath, new DataDashboardForm(amount, loadMarkets: false));
    }

    internal static int RenderSettings(string outputPath) => RenderForm(outputPath, new SettingsForm());

    private static int RenderForm(string outputPath, Form form)
    {
        try
        {
            using (form)
            {
                form.StartPosition = FormStartPosition.Manual;
                form.Location = new Point(-20_000, -20_000);
                form.Show();
                Application.DoEvents();
                Thread.Sleep(120);
                Application.DoEvents();
                string? directory = Path.GetDirectoryName(Path.GetFullPath(outputPath));
                if (!string.IsNullOrWhiteSpace(directory)) Directory.CreateDirectory(directory);
                using var bitmap = new Bitmap(form.Width, form.Height);
                form.DrawToBitmap(bitmap, new Rectangle(Point.Empty, bitmap.Size));
                bitmap.Save(outputPath, ImageFormat.Png);
                form.Close();
            }
            return 0;
        }
        catch (Exception exception)
        {
            try { File.WriteAllText(outputPath + ".error.txt", exception.ToString()); }
            catch { }
            return 1;
        }
    }
}
