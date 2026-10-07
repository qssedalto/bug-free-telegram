using System.Runtime.InteropServices;
using Microsoft.Win32;

namespace 是否认同;

internal static class Theme
{
    private static readonly Lazy<Icon?> ApplicationIcon = new(LoadApplicationIcon);
    internal static readonly Color DarkBackground = Color.FromArgb(32, 32, 32);
    internal static readonly Color DarkForeground = Color.FromArgb(245, 245, 245);
    internal static readonly Color LightBackground = Color.FromArgb(242, 242, 247);
    internal static readonly Color LightForeground = Color.FromArgb(24, 24, 24);

    internal static bool IsDarkMode
    {
        get
        {
            try
            {
                object? value = Registry.GetValue(
                    @"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
                    "AppsUseLightTheme",
                    1);
                return value is int useLightTheme && useLightTheme == 0;
            }
            catch (Exception ex) when (ex is System.Security.SecurityException or IOException or UnauthorizedAccessException)
            {
                return false;
            }
        }
    }

    internal static void Apply(Form form, bool warning = false)
    {
        AppSettings settings = AppServices.Settings;
        bool dark = settings.Theme switch
        {
            ThemeMode.Light => false,
            ThemeMode.Dark or ThemeMode.PureBlack => true,
            _ => IsDarkMode
        };
        Color background = warning
            ? Color.FromArgb(200, 42, 47)
            : settings.HighContrast || settings.Theme == ThemeMode.PureBlack
                ? Color.Black
                : dark ? DarkBackground : LightBackground;
        Color foreground = warning
            ? Color.White
            : settings.HighContrast ? Color.Yellow : dark ? DarkForeground : LightForeground;
        Color card = warning
            ? Color.FromArgb(255, 59, 64)
            : settings.HighContrast || settings.Theme == ThemeMode.PureBlack
                ? Color.FromArgb(10, 10, 10)
                : dark ? Color.FromArgb(44, 44, 46) : Color.White;
        Color border = warning
            ? Color.FromArgb(255, 125, 128)
            : dark ? Color.FromArgb(75, 75, 78) : Color.FromArgb(215, 215, 220);
        ApplyToControl(form, background, foreground, card, border, Color.FromArgb(settings.AccentArgb));
        if (ApplicationIcon.Value is not null) form.Icon = ApplicationIcon.Value;
        UseDarkTitleBar(form.Handle, dark && !warning);
        UseRoundedCorners(form.Handle);
    }

    private static Icon? LoadApplicationIcon()
    {
        try
        {
            using Stream? stream = typeof(Theme).Assembly.GetManifestResourceStream("是否认同.AppIcon.ico");
            return stream is null ? null : new Icon(stream);
        }
        catch
        {
            return null;
        }
    }

    private static void ApplyToControl(
        Control control,
        Color inheritedBackground,
        Color foreground,
        Color card,
        Color border,
        Color accent)
    {
        string? role = control.Tag as string;
        bool branchCard = role?.StartsWith("branch:", StringComparison.Ordinal) == true;
        Color activeBackground = role is "card" or "warningCard" || branchCard ? card : inheritedBackground;

        if (role == "themeAccent")
        {
            control.BackColor = accent;
            control.ForeColor = Color.White;
        }
        else if (role != "accent")
        {
            control.BackColor = activeBackground;
            control.ForeColor = foreground;
        }

        if (control is RoundedPanel roundedPanel)
        {
            if (branchCard
                && int.TryParse(role!["branch:".Length..], out int branchArgb))
            {
                Color branchColor = Color.FromArgb(branchArgb);
                roundedPanel.BorderColor = Color.FromArgb(175, branchColor);
            }
            else
            {
                roundedPanel.BorderColor = border;
            }
            roundedPanel.Invalidate();
        }

        foreach (Control child in control.Controls)
        {
            ApplyToControl(child, activeBackground, foreground, card, border, accent);
        }
    }

    private static void UseDarkTitleBar(IntPtr handle, bool enabled)
    {
        int value = enabled ? 1 : 0;
        _ = DwmSetWindowAttribute(handle, 20, ref value, sizeof(int));
    }

    private static void UseRoundedCorners(IntPtr handle)
    {
        const int DwmWindowCornerPreference = 33;
        const int Round = 2;
        int value = Round;
        _ = DwmSetWindowAttribute(handle, DwmWindowCornerPreference, ref value, sizeof(int));
    }

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
}
