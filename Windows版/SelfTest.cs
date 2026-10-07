namespace 是否认同;

internal static class SelfTest
{
    internal static int Run()
    {
        try
        {
            Assert(DebtTimeline.NForDate(new DateOnly(2023, 6, 18)) == 7, "dates before start must use n=7");
            Assert(DebtTimeline.NForDate(new DateOnly(2023, 6, 19)) == 7, "start date must use n=7");
            Assert(DebtTimeline.NForDate(new DateOnly(2023, 6, 20)) == 8, "second date must use n=8");
            Assert(DebtTimeline.NForDate(new DateOnly(2023, 6, 21)) == 9, "2023-06-21 must use n=9");
            Assert(SafeCalculation.CalculateAmount(7).Digits == "1008", "n=7 calculation changed");
            Assert(SafeCalculation.CalculateAmount(8).Digits == "1058", "n=8 calculation changed");
            AmountDisplay amount1111 = SafeCalculation.CalculateAmount(9);
            Assert(amount1111.Digits == "1111", "n=9 must equal 1111");
            Assert(amount1111.GroupedDigits == "1,111", "thousands grouping failed");
            Assert(amount1111.Chinese == "一千一百一十一元", "1111 Chinese conversion failed");
            Assert(ChineseMoney.ToUppercase("10001") == "一万零一元", "zero bridging failed");
            Assert(BitcoinMath.ConvertCnyToBitcoin("1111", "800000") == "0.00139", "BTC rounding failed");
            Assert(BitcoinMath.ConvertCnyToBitcoin("1000000", "500000") == "2.00000", "BTC exact conversion failed");
            string largeBitcoinValue = BitcoinMath.ConvertCnyToBitcoin("999999999999999999999", "750000.25");
            int decimalPoint = largeBitcoinValue.LastIndexOf('.');
            Assert(decimalPoint > 0 && largeBitcoinValue.Length - decimalPoint - 1 == 5,
                "large BTC conversion must keep five decimals");
            var defaultSettings = new AppSettings { StartDate = new DateOnly(2023, 6, 19), InitialAmount = "1008" };
            Assert(DebtEngine.AmountForDate(new DateOnly(2023, 6, 21), defaultSettings).Digits == "1111",
                "configurable timeline must preserve the 2023 anchor");
            var customSettings = new AppSettings { StartDate = new DateOnly(2026, 1, 1), InitialAmount = "2000" };
            Assert(DebtEngine.AmountForDate(new DateOnly(2026, 1, 2), customSettings).Digits == "2100",
                "custom initial amount growth failed");
            Assert(ArbitraryMoneyMath.Multiply("100", "0.14", 2) == "14.00", "fiat multiplication failed");
            Assert(ArbitraryMoneyMath.Divide("100", "500", 3) == "0.200", "gold division failed");
            Assert(ArbitraryMoneyMath.DivideByIntegerFactor("500000000", "500", 1_000_000, 6) == "1.000000",
                "gold tonne conversion failed");
            VerifyNetworkRegionParsing();
            VerifyChinaMarketParsing();
            AmountDisplay maximum = SafeCalculation.CalculateAmount(int.MaxValue);
            Assert(maximum.IsCapped, "large n must reach the business cap");
            Assert(maximum.Digits.Length == 99 && maximum.Digits.All(c => c == '9'), "cap must be 99 nines");
            Assert(SafeCalculation.CalculateAmount(int.MinValue).Digits == "1008", "small n must clamp safely");
            AgreeStory agreeStory = StoryContent.NextAgree(AppServices.Settings);
            StorySequence strongStory = StoryContent.NextStrongAgree(AppServices.Settings);
            WarningStory warningStory = StoryContent.NextWarning(AppServices.Settings, "测试角色", false);
            Assert(StoryContent.AgreeCombinationCount >= 1000, "agree route must provide at least 1000 combinations");
            Assert(StoryContent.StrongAgreeCombinationCount >= 1000, "strong-agree route must provide at least 1000 combinations");
            Assert(StoryContent.WarningCombinationCount >= 1000, "warning route must provide at least 1000 combinations");
            Assert(StoryContent.EasterEggCombinationCount >= 1000, "easter eggs must provide at least 1000 combinations");
            Assert(!string.IsNullOrWhiteSpace(agreeStory.Prelude)
                && !string.IsNullOrWhiteSpace(agreeStory.FirstButtonText)
                && !string.IsNullOrWhiteSpace(agreeStory.RevealButtonText)
                && !string.IsNullOrWhiteSpace(agreeStory.DetailIntroduction)
                && !string.IsNullOrWhiteSpace(agreeStory.Acknowledgement)
                && !string.IsNullOrWhiteSpace(agreeStory.Epilogue),
                "agree story must contain matching prose and button labels");
            AgreeStory[] allAgreeStories = StoryContent.AllAgreeCombinationsForTest().ToArray();
            Assert(allAgreeStories.Length == StoryContent.AgreeCombinationCount,
                "agree route combination enumeration is incomplete");
            Assert(allAgreeStories.All(story =>
                !string.Join("\n", story.Title, story.Prelude, story.DetailIntroduction, story.Acknowledgement, story.Epilogue)
                    .Contains("原谅", StringComparison.Ordinal)),
                "agree route still contains the removed fixed forgiveness wording");
            Assert(strongStory.Lines.Count >= 3, "strong-agree story must contain at least three stages");
            Assert(warningStory.EscapeResults.Count >= 3, "warning story must contain multiple outcomes");
            VerifySmartDialogSizing();
            VerifyPerStageDialogSizing();
            VerifyDashboardButtonText();
            VerifySettingsCopyright();
            VerifyAmountWindowSizing();
            VerifyHomeDashboardRendering();
            VerifyResponsiveRendering();

            return 0;
        }
        catch (Exception exception)
        {
            try { File.WriteAllText(Path.Combine(Path.GetTempPath(), "是否认同-self-test-error.txt"), exception.ToString()); }
            catch { }
            return 1;
        }
    }

    private static void Assert(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message);
    }

    private static void VerifyNetworkRegionParsing()
    {
        Assert(NetworkRegionService.ParseCloudflareCountry("fl=1\nloc=CN\ntls=TLSv1.3\n") == "CN",
            "Cloudflare China IP parsing failed");
        Assert(NetworkRegionService.ParseCloudflareCountry("loc=US\n") == "US",
            "Cloudflare international IP parsing failed");
        Assert(NetworkRegionService.ParseCountryIsCountry("{\"country\":\"CN\"}") == "CN",
            "Country.is IP parsing failed");
    }

    private static void VerifyChinaMarketParsing()
    {
        const string bankHtml = """
            <table>
              <tr><td>美元</td><td>698</td><td>698</td><td>702</td><td>702</td><td>700</td><td>2026/08/03 09:30:00</td><td>09:30:00</td></tr>
              <tr><td>欧元</td><td>798</td><td>798</td><td>802</td><td>802</td><td>800</td><td>2026/08/03 09:30:00</td><td>09:30:00</td></tr>
              <tr><td>日元</td><td>4.48</td><td>4.48</td><td>4.52</td><td>4.52</td><td>4.5</td><td>2026/08/03 09:30:00</td><td>09:30:00</td></tr>
              <tr><td>港币</td><td>88</td><td>88</td><td>92</td><td>92</td><td>90</td><td>2026/08/03 09:30:00</td><td>09:30:00</td></tr>
            </table>
            """;
        ChinaFiatQuote fiat = ChinaMarketSource.ParseBankOfChinaHtml(bankHtml);
        Assert(fiat.CnyPerUsd == "7", "Bank of China CNY/USD parsing failed");
        Assert(fiat.FiatPerCny.Count == 4, "Bank of China currency count is wrong");
        Assert(fiat.FiatPerCny["JPY"] == "22.222222222222222222", "Bank of China JPY conversion failed");

        const string goldJson = """
            {"times":["09:30","09:31"],"data":[899.1,900.25],"heyue":"Au99.99","delaystr":"2026年08月03日 09:31:00"}
            """;
        ChinaGoldQuote gold = ChinaMarketSource.ParseShanghaiGoldJson(goldJson);
        Assert(gold.CnyPerGram == "900.25", "Shanghai Gold price parsing failed");
        Assert(gold.UpdatedAt.Offset == TimeSpan.FromHours(8), "Shanghai Gold timestamp offset is wrong");
    }

    private static void VerifyResponsiveRendering()
    {
        AppSettings settings = AppServices.Settings;
        decimal originalScale = settings.FontScale;
        bool originalContrast = settings.HighContrast;
        try
        {
            settings.FontScale = 1.35M;
            settings.HighContrast = true;
            AmountDisplay maximum = SafeCalculation.CalculateAmount(int.MaxValue);
            foreach (Size size in new[] { new Size(1180, 800), new Size(1600, 1000) })
            {
                using var dialog = new ConfirmationDialog(maximum) { Size = size };
                dialog.CreateControl();
                dialog.PerformLayout();
                RoundedButton? reveal = Descendants(dialog)
                    .OfType<RoundedButton>()
                    .FirstOrDefault(button => button.Height >= 60 && button.Width >= 200);
                Assert(reveal is not null, "confirmation action button is missing");
                reveal!.PerformClick();
                dialog.PerformLayout();
                using var bitmap = new Bitmap(Math.Max(1, dialog.ClientSize.Width), Math.Max(1, dialog.ClientSize.Height));
                dialog.DrawToBitmap(bitmap, dialog.ClientRectangle);
                Assert(Descendants(dialog).Where(control => control.Visible).All(control => control.Width > 0 && control.Height > 0),
                    $"responsive layout contains an empty control at {size.Width}x{size.Height}");
            }
        }
        finally
        {
            settings.FontScale = originalScale;
            settings.HighContrast = originalContrast;
        }
    }

    private static void VerifyDashboardButtonText()
    {
        using var dashboard = new DataDashboardForm(loadMarkets: false);
        dashboard.CreateControl();
        dashboard.PerformLayout();
        RoundedButton? reset = Descendants(dashboard)
            .OfType<RoundedButton>()
            .FirstOrDefault(button => button.Text == "重新开始剧情");
        Assert(reset is not null, "story reset button is missing");
        int requiredWidth = TextRenderer.MeasureText(reset!.Text, reset.Font).Width + 64;
        Assert(reset.Width >= requiredWidth, "story reset button text is clipped");
    }

    private static void VerifySettingsCopyright()
    {
        using var settings = new SettingsForm();
        settings.CreateControl();
        settings.PerformLayout();
        Label? copyright = Descendants(settings)
            .OfType<Label>()
            .FirstOrDefault(label => label.AccessibleName == "copyright");
        Assert(copyright is not null && copyright.Text.Contains("天国智造", StringComparison.Ordinal),
            "settings copyright information is missing");
        Assert(copyright!.Parent is not null && copyright.Width > 0 && copyright.Height > 0,
            "settings copyright information is not part of the visible layout");
    }

    private static void VerifyAmountWindowSizing()
    {
        using var shortMini = new MiniAmountForm(SafeCalculation.CalculateAmount(9));
        using var maximumMini = new MiniAmountForm(SafeCalculation.CalculateAmount(int.MaxValue));
        shortMini.CreateControl();
        maximumMini.CreateControl();
        shortMini.PerformLayout();
        maximumMini.PerformLayout();
        Assert(maximumMini.ClientSize.Width >= shortMini.ClientSize.Width,
            "mini amount window must grow for longer amounts");
        Assert(maximumMini.Controls.Cast<Control>().All(control => control.Width > 0 && control.Height > 0),
            "mini amount window contains an empty control");

        using var dashboard = new DataDashboardForm(SafeCalculation.CalculateAmount(int.MaxValue), loadMarkets: false);
        dashboard.CreateControl();
        dashboard.PerformLayout();
        Assert(dashboard.ClientSize.Width >= 1180,
            "dashboard must retain or expand its width for a 99-digit amount");
    }

    private static void VerifySmartDialogSizing()
    {
        using var shortDialog = new Form();
        using var longDialog = new Form();
        SmartDialogSizing.Apply(shortDialog, ["短文案"], new Size(760, 520), new Size(900, 620), 14F);
        SmartDialogSizing.Apply(
            longDialog,
            [string.Concat(Enumerable.Repeat("这是一段用于验证智能弹窗尺寸与自动换行能力的超长剧情文案。", 18))],
            new Size(760, 520),
            new Size(900, 620),
            14F);
        Assert(longDialog.ClientSize.Width >= shortDialog.ClientSize.Width,
            "long text must not produce a narrower dialog");
        Assert(longDialog.ClientSize.Height >= shortDialog.ClientSize.Height,
            "long text must not produce a shorter dialog");
        Assert(longDialog.ClientSize != shortDialog.ClientSize,
            "smart dialog sizing must react to text length");
    }

    private static void VerifyPerStageDialogSizing()
    {
        var stagedStory = new AgreeStory(
            "短标题",
            "金额页需要容纳更多内容。",
            "打开",
            "继续",
            "这是一段随剧情变化的金额页引导。",
            "这是一段随剧情变化的完成回应。",
            "短结尾");
        using (var confirmation = new ConfirmationDialog(SafeCalculation.CalculateAmount(int.MaxValue), stagedStory))
        {
            Size initial = confirmation.ClientSize;
            confirmation.RevealForPreview();
            Size details = confirmation.ClientSize;
            confirmation.AdvanceForPreview();
            Size ending = confirmation.ClientSize;
            Assert(details.Width >= initial.Width && details.Height >= initial.Height,
                "confirmation details stage must expand for the amount content");
            Assert(ending.Width <= details.Width && ending.Height <= details.Height,
                "confirmation ending stage must be allowed to shrink");
        }

        string longPage = string.Concat(Enumerable.Repeat("下一页文案很长，因此窗口需要立即重新测量并扩大。", 24));
        using (var message = new MessageDialog("逐页尺寸测试", "继续", ["短页", longPage, "结束"], false))
        {
            Size shortSize = message.ClientSize;
            message.AdvanceForPreview();
            Size longSize = message.ClientSize;
            message.AdvanceForPreview();
            Size finalSize = message.ClientSize;
            Assert(longSize != shortSize && longSize.Width >= shortSize.Width && longSize.Height >= shortSize.Height,
                "message dialog must resize immediately for the next long page");
            Assert(finalSize.Width <= longSize.Width && finalSize.Height <= longSize.Height,
                "message dialog must shrink again for a short page");
        }

        using (var warning = new WarningDialog(new WarningStory("警告", "短提示", [longPage])))
        {
            Size promptSize = warning.ClientSize;
            warning.FinishForPreview(longPage);
            Size resultSize = warning.ClientSize;
            Assert(resultSize != promptSize && resultSize.Width >= promptSize.Width && resultSize.Height >= promptSize.Height,
                "warning dialog must resize for the generated result");
        }
    }

    private static void VerifyHomeDashboardRendering()
    {
        foreach (Size size in new[] { new Size(920, 700), new Size(1320, 900) })
        {
            using var form = new MainForm(previewMode: true) { ClientSize = size };
            form.CreateControl();
            form.PerformLayout();
            using var bitmap = new Bitmap(form.Width, form.Height);
            form.DrawToBitmap(bitmap, new Rectangle(Point.Empty, bitmap.Size));
            RoundedButton[] routeButtons = Descendants(form)
                .OfType<RoundedButton>()
                .Where(button => button.BackColor.ToArgb() is var argb
                    && (argb == Color.FromArgb(10, 132, 255).ToArgb()
                        || argb == Color.FromArgb(48, 209, 88).ToArgb()
                        || argb == Color.FromArgb(255, 69, 58).ToArgb()))
                .ToArray();
            Assert(routeButtons.Length == 3, $"home dashboard must expose three route buttons at {size.Width}x{size.Height}");
            Assert(routeButtons.All(button => button.Width >= 170 && button.Height >= 56),
                "home route buttons must remain readable");
            MiniTrendControl? miniTrend = Descendants(form)
                .OfType<MiniTrendControl>()
                .FirstOrDefault(control => control.AccessibleName == "mini-trend");
            Assert(miniTrend is not null && miniTrend.Height >= 140,
                $"home mini trend must retain a useful height at {size.Width}x{size.Height}");
        }
    }

    private static IEnumerable<Control> Descendants(Control parent)
    {
        foreach (Control child in parent.Controls)
        {
            yield return child;
            foreach (Control nested in Descendants(child)) yield return nested;
        }
    }
}
