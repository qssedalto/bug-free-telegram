namespace 是否认同;

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        if (args.Length == 1 && args[0].Equals("--self-test", StringComparison.OrdinalIgnoreCase))
        {
            ApplicationConfiguration.Initialize();
            return SelfTest.Run();
        }

        if (args.Length >= 1 && args[0].Equals("--render-preview", StringComparison.OrdinalIgnoreCase))
        {
            ApplicationConfiguration.Initialize();
            string outputPath = args.Length >= 2
                ? args[1]
                : Path.Combine(AppContext.BaseDirectory, "confirmation-preview.png");
            return PreviewRenderer.RenderConfirmation(outputPath);
        }

        if (args.Length >= 1 && args[0].Equals("--render-main", StringComparison.OrdinalIgnoreCase))
        {
            ApplicationConfiguration.Initialize();
            string outputPath = args.Length >= 2
                ? args[1]
                : Path.Combine(AppContext.BaseDirectory, "main-preview.png");
            int width = args.Length >= 3 && int.TryParse(args[2], out int parsedWidth) ? Math.Clamp(parsedWidth, 920, 3000) : 1320;
            int height = args.Length >= 4 && int.TryParse(args[3], out int parsedHeight) ? Math.Clamp(parsedHeight, 700, 2000) : 900;
            return PreviewRenderer.RenderMain(outputPath, new Size(width, height));
        }

        if (args.Length >= 1 && args[0].Equals("--render-mini", StringComparison.OrdinalIgnoreCase))
        {
            ApplicationConfiguration.Initialize();
            string outputPath = args.Length >= 2
                ? args[1]
                : Path.Combine(AppContext.BaseDirectory, "mini-preview.png");
            bool maximumAmount = args.Length >= 3 && args[2].Equals("maximum", StringComparison.OrdinalIgnoreCase);
            return PreviewRenderer.RenderMiniAmount(outputPath, maximumAmount);
        }

        if (args.Length >= 1 && args[0].Equals("--render-dashboard", StringComparison.OrdinalIgnoreCase))
        {
            ApplicationConfiguration.Initialize();
            string outputPath = args.Length >= 2
                ? args[1]
                : Path.Combine(AppContext.BaseDirectory, "dashboard-preview.png");
            bool maximumAmount = args.Length >= 3 && args[2].Equals("maximum", StringComparison.OrdinalIgnoreCase);
            return PreviewRenderer.RenderDashboard(outputPath, maximumAmount);
        }

        if (args.Length >= 1 && args[0].Equals("--render-settings", StringComparison.OrdinalIgnoreCase))
        {
            ApplicationConfiguration.Initialize();
            string outputPath = args.Length >= 2
                ? args[1]
                : Path.Combine(AppContext.BaseDirectory, "settings-preview.png");
            return PreviewRenderer.RenderSettings(outputPath);
        }

        ApplicationConfiguration.Initialize();
        AppServices.InitializeDailyData();
        Application.Run(new MainForm());
        return 0;
    }
}
