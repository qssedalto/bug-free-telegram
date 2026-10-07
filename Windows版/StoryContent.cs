namespace 是否认同;

internal sealed record AgreeStory(
    string Title,
    string Prelude,
    string FirstButtonText,
    string RevealButtonText,
    string DetailIntroduction,
    string Acknowledgement,
    string Epilogue);
internal sealed record StorySequence(string Title, string ButtonText, IReadOnlyList<string> Lines, string Result);
internal sealed record WarningStory(string Title, string Prompt, IReadOnlyList<string> EscapeResults);

internal static class StoryContent
{
    private static readonly string[] AgreeTitles =
    [
        "档案室的灯亮了", "账本翻到了新的一页", "时间线已重新对齐", "一封迟到的回信",
        "数字不会忘记", "午夜账簿", "第七码头的收据", "被折叠的合同", "审计员的便签", "金额观测站"
    ];

    private static readonly string[] AgreePreludes =
    [
        "你点头之后，屏幕里的旧账本自动翻开，缺失的那一页正好停在今天。",
        "系统把你的选择记进档案，并从一串微弱的数字里恢复了完整金额。",
        "远处传来打印机启动的声音，一张没有签名的合同缓缓吐了出来。",
        "你同意继续调查。窗口边缘闪过一道紫光，账款记录重新变得清晰。",
        "这不是结局，而是一把钥匙。它打开了通往金额档案室的第一扇门。",
        "一个匿名审计员留下提示：不要只看总额，也要留意它每天如何增长。",
        "你在旧硬盘里找到一份快照，日期、公式和金额全部与当前记录吻合。",
        "确认声落下后，时间线安静了几秒，随后把被隐藏的数据送回屏幕。",
        "合同右下角出现一行新字：愿意面对数字的人，才能看到下一页。",
        "金额观测站接受了你的访问请求，并为这次选择生成了永久记录。"
    ];

    private static readonly string[] AgreeEpilogues =
    [
        "档案已归位。下一次进入时，也许会出现另一段记录。",
        "你保存了这一页，但账本深处似乎还有更多没有读完的批注。",
        "门在身后合上。紫色指示灯闪了三次，像是在说：还会再见。",
        "这次核对结束了。数据面板里已经留下你来过的痕迹。",
        "金额没有停止增长，不过你至少让它不再藏在黑暗里。",
        "审计员发来最后一句话：连续作出选择，会解锁新的档案。",
        "屏幕恢复平静，只有复制到剪贴板里的数字证明刚才并非幻觉。",
        "合同被重新封存，上面多了一枚写着“已阅”的紫色印章。",
        "你听见远处有人翻动下一本账簿，也许那是另一个分支的开端。",
        "系统提示：温和的回答也能改变故事，只是改变得比较安静。"
    ];

    private static readonly string[] AgreeFirstButtons =
    [
        "查看档案", "翻开账本", "校准时间", "拆开回信", "查看数字",
        "打开账簿", "核对收据", "展开合同", "阅读便签", "进入观测站"
    ];

    private static readonly string[] AgreeRevealButtons =
    [
        "收下记录", "继续核对", "确认锚点", "读完了", "记住了",
        "合上账簿", "收好收据", "重新封存", "彳亍", "完成观测"
    ];

    private static readonly string[] AgreeDetailIntroductions =
    [
        "档案灯已经稳定，缺失页、日期锚点与当前金额正在同一张记录上展开。",
        "账本自动停在核对页，纸面上的数字将与今天的时间线逐项对照。",
        "校准器锁定了正确日期，接下来显示的是这条时间线恢复出的金额记录。",
        "回信的封口缓缓松开，夹在信纸之间的金额档案终于可以完整阅读。",
        "数字观测程序已完成去噪，隐藏在增长曲线后的真实数值即将显现。",
        "午夜账簿翻到带紫色书签的一页，金额、换算结果和中文写法都在这里。",
        "收据上的模糊墨迹正在复原，系统准备展示它对应的完整账款记录。",
        "折叠合同被平铺在审阅台上，关键数字已按照每三位一组重新整理。",
        "便签背面的校验码已经通过，下面这组数字可以作为本次档案的核对依据。",
        "观测站完成了本轮采样，当前金额与实时换算结果已同步到屏幕。"
    ];

    private static readonly string[] AgreeAcknowledgements =
    [
        "档案室收下了这次核对，紫色印章已经落在页角。",
        "账本把你的选择记在页脚，并为下一次翻阅保留了书签。",
        "时间线确认本轮校准有效，新的锚点记录已经写入本地。",
        "回信末尾浮现一行小字：这次阅读让缺失的上下文重新完整。",
        "数字观测程序保存了本次结果，并把异常波动标成了可追踪记录。",
        "午夜账簿轻轻合上，但书脊里的紫光仍在提示下一页尚未结束。",
        "收据核验完成，档案柜为这次访问生成了一枚临时索引。",
        "合同重新封存前多出一条批注：本轮审阅已经进入历史记录。",
        "审计便签被贴回原位，上面新增了一个代表完成的小圆点。",
        "观测站结束本轮广播，并将你的选择标记为一次有效采样。"
    ];

    private static readonly StorySequence[] StrongAgreeStories =
    [
        new("观点共振", "接收信号", ["你的选择与系统产生了罕见的完全共振。", "三盏绿色指示灯依次亮起，档案权限提升一级。", "终端建议你尝试另一个答案，看看时间线是否仍然稳定。"], "完成观点共振"),
        new("绿色通行证", "继续", ["你获得了一张只在今天有效的绿色通行证。", "它可以进入档案室，却不能让金额停止增长。", "通行证背面写着：真正的答案可能藏在反对意见里。"], "获得绿色通行证"),
        new("过度肯定测试", "开始测试", ["系统检测到你的肯定强度超过普通范围。", "正在检查这是真诚信念，还是手速造成的误判……", "检查完成：态度坚定，但建议保留一点好奇心。"], "通过过度肯定测试"),
        new("同盟协议", "签署", ["一份临时同盟协议出现在桌面。", "条款一：共同观察金额。条款二：不要在倒计时里发呆。", "你签下名字后，协议自动变成了一枚成就徽章。"], "签署同盟协议"),
        new("平行时间线", "打开裂缝", ["另一个时间线里的你也按下了“非常认同”。", "两个选择短暂重叠，导致今日台词发生偏移。", "裂缝关闭前，你看见了红色按钮后面的一条秘密路线。"], "窥见平行时间线"),
        new("赞同能量过载", "释放能量", ["绿色按钮积累了太多赞同能量。", "系统正在把多余能量转换成窗口圆角……", "转换完成。世界没有改变，但弹窗似乎更顺眼了一点。"], "释放赞同能量"),
        new("审计员来信", "拆开信封", ["匿名审计员寄来一封只有三行字的信。", "第一行：数字是真的。第二行：故事是虚构的。", "第三行：连续点击标题的人，会找到鸡蛋。"], "读完审计员来信"),
        new("选择回声", "倾听", ["你以前作出的选择从历史数据库里传来回声。", "每一次肯定都略有不同，因此通往的页面也不完全相同。", "回声最后重复了一句：不要忘记查看成就。"], "听见选择回声"),
        new("许可升级", "验证身份", ["系统准备把你的访问级别从“访客”提升为“观察者”。", "验证问题：你是否愿意承担查看巨大数字的风险？", "验证已自动通过，因为你刚才选择了“非常认同”。"], "升级为观察者"),
        new("第四面墙", "轻敲屏幕", ["故事里的角色忽然停下动作，看向窗口外面的你。", "他说：我知道这些台词是随机抽取的。", "随后他关闭了第四面墙，并假装什么都没有发生。"], "短暂打破第四面墙")
    ];

    private static readonly string[] StrongAgreeInterludes =
    [
        "就在这时，窗口右上角出现一颗只闪烁一次的绿色星星。",
        "系统把你的肯定转换成一枚临时密钥，密钥上刻着今天的日期。",
        "一段来自未来七天后的回声插入对话，提醒你留意数据面板。",
        "桌面边缘滑出一张透明卡片，上面记录着你刚才按按钮的力度。",
        "三秒钟内，所有圆角同时增大了一像素，然后若无其事地恢复。",
        "隐藏观察员发来加密批注：坚定不等于停止提问。",
        "绿色路线与蓝色路线短暂交叉，生成了一份从未见过的联合档案。",
        "金额观测站把这次选择标记为高能事件，并保存了一份额外快照。",
        "背景中响起一声很轻的确认音，像有人在另一个房间按下回车。",
        "终端突然使用诗歌格式输出日志，随后又切回严肃的审计口吻。"
    ];

    private static readonly string[] StrongAgreeEndings =
    [
        "剧情结束时，你获得了“保持好奇”的无形徽章。",
        "最后一盏绿灯没有熄灭，它决定为下一次访问保留位置。",
        "协议自动归档，但在页脚留下了一条尚未解释的紫色横线。",
        "系统感谢你的配合，并建议下次尝试完全相反的路线。",
        "回声渐渐消失，只剩一行小字：同一个答案也有一千种理由。",
        "你关闭页面后，历史记录里多出了一枚绿色指纹。",
        "观察员身份验证完成，新的剧情编号被写入本地数据库。",
        "时间线重新稳定，不过今天的每日台词似乎悄悄换了一个标点。",
        "故事没有给出标准答案，只把下一把钥匙交到了你手里。",
        "屏幕郑重宣布测试通过，然后用很小的字补充：暂时的。"
    ];

    private static readonly string[] WarningTitles =
    [
        "红色协议已启动", "档案室封锁", "追踪信号出现", "时间线发生偏移", "未知访客接近",
        "合同防御系统", "第九号警报", "倒计时异常", "审计程序失控", "紧急撤离演练"
    ];

    private static readonly string[] WarningPrompts =
    [
        "你触发了红色分支。请在倒计时结束前选择逃离路线。",
        "门锁已经落下，但通风管、楼梯和一扇没有标记的门仍然可用。",
        "追踪者读取到了你的选择，系统正在生成一条随机撤离路径。",
        "这次反对让时间线偏离了原轨道，剩余十秒可以进行修正。",
        "警报并不代表失败，它只是故事邀请你跑得快一点。",
        "合同上的红色印章开始发光，附近所有出口的位置都变了。",
        "监控画面里没有人，但走廊的感应灯正在一盏接一盏亮起。",
        "系统无法判断你是勇敢还是好奇，于是决定启动一次撤离测试。",
        "一张写着“不要回头”的纸条从打印机里掉了出来。",
        "倒计时开始。友情提示：这是虚构剧情，真正危险的是犹豫。"
    ];

    private static readonly string[] EscapeResults =
    [
        "你钻进维修通道，从另一栋楼的自动售货机后面安全出现。",
        "电梯拒绝工作，你改走楼梯，意外发现一间隐藏档案室。",
        "追踪信号锁定了一个空纸箱，而你已经从侧门离开。",
        "你按下错误楼层，却因此完美避开了所有监控。",
        "门外站着的只是送错地址的快递员，警报随即解除。",
        "你用一张过期门票骗过识别器，系统对此表示困惑。",
        "走廊尽头的墙其实是一扇门，你穿过去后回到了主界面。",
        "警报声突然变成提示音：本次紧急撤离演练合格。",
        "你藏进服务器机房，风扇噪声掩盖了所有脚步。",
        "随机路线把你带到屋顶，一架纸飞机为你指出了出口。",
        "你没有逃跑，只是关掉灯。追踪者从门口经过却没有发现你。",
        "系统将你的身份误判为审计员，并主动为你打开了出口。",
        "一只橘猫踩到了门禁按钮，你趁机离开并欠它一根猫条。",
        "你沿着紫色指示灯前进，最后发现它们组成了一个彩蛋图案。",
        "倒计时还剩一秒时，追踪程序因整数过大而主动放弃——金额本身没有溢出。",
        "你进入迷你窗口模式，追踪者面对这么小的目标无从下手。",
        "窗外下起像素雨，所有足迹都被刷新掉了。",
        "你提交了一份措辞严谨的异议，警报系统决定尊重不同意见。",
        "逃离路线绕了一大圈，最后把你送回原地，但危险已经离开。",
        "屏幕显示：随机结局编号 404——追踪者未找到。"
    ];

    private static readonly string[] EasterEggArtifacts =
    [
        "🥚 一枚带紫色裂纹的数字蛋", "📼 一盘标着 2023-06-21 的旧录像带",
        "🪙 一枚只存在于内存里的虚拟硬币", "🧾 一张金额为 ￥0 的隐藏收据",
        "🛰️ 一段来自金额观测站的窄带信号", "🟣 一颗从强调色里掉出来的像素",
        "🧮 一台害怕溢出的老式计算器", "🗝️ 一把刻着 1111 的微型钥匙",
        "📘 一本页码从第七页开始的账簿", "🕰️ 一只每天快百分之五的档案时钟"
    ];

    private static readonly string[] EasterEggBehaviors =
    [
        "正在记录你点击标题的节奏", "悄悄把三个按钮的位置记进另一条时间线",
        "坚持认为自己才是这个窗口真正的开发者", "把刚才的选择翻译成了一串没有人教过它的摩斯电码",
        "在深色模式和浅色模式之间留下了一道看不见的门", "尝试用逗号把所有秘密每三位分成一组",
        "向本地历史数据库提交了一条匿名批注", "把倒计时偷走一秒，又因为良心不安还了两秒",
        "在迷你窗口里建立了一间更迷你的档案室", "声称第十二次选择之后会有观察员前来验收"
    ];

    private static readonly string[] EasterEggEndings =
    [
        "系统建议你假装没有看见。", "它完成工作后礼貌地滚回屏幕边缘。",
        "这条记录将在关闭窗口后继续装作普通文本。", "档案编号已经保存，但最后一位被故意涂成了紫色。",
        "你获得了一枚没有图标、只有名字的隐藏成就。", "远处传来一声确认音，随后一切恢复正常。",
        "它留下提示：同一处彩蛋也可能说出完全不同的话。", "这次发现不会增加欠款，只会增加一点好奇心。",
        "下一次出现时，它可能会换一个身份和结尾。", "观察站确认：你刚刚遇到了千分之一的组合。"
    ];

    internal static int AgreeCombinationCount => AgreeTitles.Length * AgreePreludes.Length * AgreeEpilogues.Length;
    internal static int StrongAgreeCombinationCount => StrongAgreeStories.Length * StrongAgreeInterludes.Length * StrongAgreeEndings.Length;
    internal static int WarningCombinationCount => WarningTitles.Length * WarningPrompts.Length * EscapeResults.Length;
    internal static int EasterEggCombinationCount => EasterEggArtifacts.Length * EasterEggBehaviors.Length * EasterEggEndings.Length;

    internal static AgreeStory NextAgree(AppSettings settings)
    {
        if (settings.English)
            return new AgreeStory(
                "The ledger opens",
                "Your choice restores a missing page from the archive.",
                "Open ledger",
                "Finish review",
                "The archive aligns the recovered date, amount, and conversion data for review.",
                "This review is stored as a verified archive entry.",
                "The page is sealed again, but another entry may appear next time.");
        int themeIndex = Random.Shared.Next(AgreeTitles.Length);
        int preludeIndex = Random.Shared.Next(AgreePreludes.Length);
        int endingIndex = Random.Shared.Next(AgreeEpilogues.Length);
        return CreateAgreeStory(themeIndex, preludeIndex, endingIndex);
    }

    private static AgreeStory CreateAgreeStory(int themeIndex, int preludeIndex, int endingIndex) =>
        new(
            AgreeTitles[themeIndex],
            AgreePreludes[preludeIndex],
            AgreeFirstButtons[themeIndex],
            AgreeRevealButtons[themeIndex],
            AgreeDetailIntroductions[themeIndex],
            AgreeAcknowledgements[endingIndex],
            AgreeEpilogues[endingIndex]);

    internal static IEnumerable<AgreeStory> AllAgreeCombinationsForTest()
    {
        for (int themeIndex = 0; themeIndex < AgreeTitles.Length; themeIndex++)
        for (int preludeIndex = 0; preludeIndex < AgreePreludes.Length; preludeIndex++)
        for (int endingIndex = 0; endingIndex < AgreeEpilogues.Length; endingIndex++)
            yield return CreateAgreeStory(themeIndex, preludeIndex, endingIndex);
    }

    internal static StorySequence NextStrongAgree(AppSettings settings)
    {
        if (settings.English)
            return new StorySequence("Opinion resonance", "Continue", ["Your answer resonates with the archive.", "Three green indicators turn on.", "The terminal suggests trying another branch next time."], "Completed opinion resonance");
        StorySequence core = StrongAgreeStories[Random.Shared.Next(StrongAgreeStories.Length)];
        string interlude = StrongAgreeInterludes[Random.Shared.Next(StrongAgreeInterludes.Length)];
        string ending = StrongAgreeEndings[Random.Shared.Next(StrongAgreeEndings.Length)];
        return new StorySequence(
            core.Title,
            core.ButtonText,
            core.Lines.Concat([interlude, ending]).ToArray(),
            core.Result + " · " + ending);
    }

    internal static WarningStory NextWarning(AppSettings settings, string person, bool secret)
    {
        if (settings.English)
            return new WarningStory("Red protocol activated", "A fictional pursuit has begun. Choose an escape route before the countdown ends.", ["You escaped through a maintenance corridor.", "The alarm was only a drill.", "The tracker returned 404: target not found."]);
        if (secret)
            return new WarningStory("隐藏路线：第零号出口", "连续触发红色分支后，第零号出口终于出现在地图上。", EscapeResults.Concat(["第零号出口通往开发者模式，你在那里找到了一枚红色成就徽章。", "你从不存在的楼层离开，监控系统因此无法填写报告。"]).ToArray());
        string title = $"{WarningTitles[Random.Shared.Next(WarningTitles.Length)]}：{person}";
        return new WarningStory(title, WarningPrompts[Random.Shared.Next(WarningPrompts.Length)], EscapeResults);
    }

    internal static string RandomEasterEgg()
    {
        string artifact = EasterEggArtifacts[Random.Shared.Next(EasterEggArtifacts.Length)];
        string behavior = EasterEggBehaviors[Random.Shared.Next(EasterEggBehaviors.Length)];
        string ending = EasterEggEndings[Random.Shared.Next(EasterEggEndings.Length)];
        return $"{artifact}{behavior}。{ending}";
    }
}
