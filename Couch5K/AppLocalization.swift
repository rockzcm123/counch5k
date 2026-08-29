import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh"
    case english = "en"

    static let storageKey = "appLanguage"

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: self == .simplifiedChinese ? "zh-Hans" : "en")
    }

    var displayName: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .english: "English"
        }
    }

    static var current: AppLanguage {
        guard let value = UserDefaults.standard.string(forKey: storageKey) else {
            return .english
        }
        return AppLanguage(rawValue: value) ?? .english
    }

    func text(_ chinese: String, _ english: String) -> String {
        self == .simplifiedChinese ? chinese : english
    }
}

enum L10n {
    private static func text(_ chinese: String, _ english: String) -> String {
        AppLanguage.current.text(chinese, english)
    }

    static let appName = "Couch 5K"

    static var pullFromIphone: String { text("从 iPhone 同步", "Sync from iPhone") }
    static var pushToIphone: String { text("同步到 iPhone", "Sync to iPhone") }
    static var watchConnectivityUnavailable: String { text("暂时无法连接 iPhone", "Can't connect to iPhone right now") }
    static var iphoneNotReachable: String {
        text("请先在 iPhone 上打开 Couch 5K，再试一次。", "Open Couch 5K on your iPhone first, then try again.")
    }

    static var continueAction: String { text("继续", "Continue") }
    static var done: String { text("完成", "Done") }
    static var cancel: String { text("取消", "Cancel") }
    static var save: String { text("保存", "Save") }
    static var gotIt: String { text("知道了", "OK") }
    static var settings: String { text("设置", "Settings") }

    static var planTab: String { text("计划", "Plan") }
    static var historyTab: String { text("历史", "History") }
    static var customTab: String { text("自定义", "Custom") }
    static var healthApp: String { text("健康 App", "Health") }
    static var unfinishedWorkout: String { text("未完成的训练", "Unfinished workout") }
    static var planComplete: String { text("计划已完成", "Plan complete") }
    static var nextWorkout: String { text("下一次训练", "Next workout") }
    static var resumeWorkout: String { text("继续训练", "Resume workout") }
    static var repeatWorkout: String { text("再次训练", "Repeat workout") }
    static var startWorkout: String { text("开始训练", "Start workout") }
    static var discardWorkout: String { text("放弃未完成训练", "Discard unfinished workout") }
    static var discardWorkoutHint: String {
        text("清除上次崩溃或中断后保存的训练进度", "Clear workout progress saved after an interruption")
    }
    static var dailyHabitTip: String { text("今日跑步习惯", "Today's Running Habit") }
    static var tapForAnotherTip: String { text("轻触查看下一条", "Tap for another tip") }

    static func dailyHabitPrompt(for date: Date, offset: Int = 0) -> (principle: String, message: String) {
        let prompts = [
            (
                text("身份认同", "Identity"),
                text(
                    "完成今天的跑走训练，不是为了证明速度，而是在强化一个身份：我是会规律跑步的人。",
                    "Completing today's run-walk session isn't about proving your speed. It reinforces an identity: I am someone who runs consistently."
                )
            ),
            (
                text("微小进步", "Small Wins"),
                text(
                    "从 1 分钟跑步到连续 30 分钟，靠的不是一次突破，而是九周里每次微小、可重复的进步。",
                    "Going from a one-minute run to 30 continuous minutes doesn't take one breakthrough. It takes nine weeks of small, repeatable gains."
                )
            ),
            (
                text("降低阻力", "Make It Easy"),
                text(
                    "今天只要求自己穿上跑鞋并开始热身步行。先让启动变容易，再跟着提示完成下一段。",
                    "Only ask yourself to put on your shoes and begin the warm-up walk. Make starting easy, then follow the cue into the next interval."
                )
            ),
            (
                text("明确提示", "Make It Obvious"),
                text(
                    "把本周三次训练写成明确计划：哪一天、几点、从哪里开始跑。清晰安排比等待动力更可靠。",
                    "Plan all three workouts this week: which day, what time, and where you'll start. A clear plan is more reliable than waiting for motivation."
                )
            ),
            (
                text("习惯叠加", "Habit Stacking"),
                text(
                    "把训练接在稳定的日常之后：下班回家或晨间喝水后，立刻换鞋开始 5 分钟热身。",
                    "Attach training to a routine you already have: after getting home or drinking water in the morning, change shoes and start the five-minute warm-up."
                )
            ),
            (
                text("两分钟开始", "Two-Minute Start"),
                text(
                    "不想跑时，先承诺打开训练并走两分钟。你可以慢下来，但不要放弃建立“按时开始”的习惯。",
                    "When you don't feel like running, open the workout and walk for two minutes. You can slow down, but protect the habit of starting on time."
                )
            ),
            (
                text("合适难度", "Right-Sized Challenge"),
                text(
                    "保持能说短句的轻松配速。Couch 5K 的挑战应该略有难度，但不会难到让你害怕下一次训练。",
                    "Keep a conversational pace. Couch 5K should feel challenging enough to engage you, but not so hard that you dread the next workout."
                )
            ),
            (
                text("不要连续错过", "Never Miss Twice"),
                text(
                    "错过一次训练不代表失败。不要用加练惩罚自己，只要回到下一次计划，重新接上每周三练的节奏。",
                    "Missing one workout isn't failure. Don't punish yourself with extra work—return to the next session and restore your three-a-week rhythm."
                )
            ),
            (
                text("即时反馈", "Make It Satisfying"),
                text(
                    "训练结束后查看日历打卡和新勋章。让每一次完成都留下可见证据，大脑会更愿意重复这个习惯。",
                    "After training, check your calendar mark and badge progress. Visible evidence of completion makes your brain more likely to repeat the habit."
                )
            ),
            (
                text("专注系统", "Trust the System"),
                text(
                    "连续跑 5K 是方向；跑走提示、每周三练和恢复日才是系统。今天只需把系统执行一次。",
                    "Running a continuous 5K is the direction. Run-walk cues, three weekly sessions, and recovery days are the system. Today, simply run the system once."
                )
            ),
            (
                text("恢复也是系统", "Recovery Is Part of It"),
                text(
                    "休息日不是中断习惯，而是在为下一次训练降低难度。轻松走路、睡好觉，然后按计划回来。",
                    "A rest day doesn't break the habit; it makes the next workout easier. Walk gently, sleep well, and return as planned."
                )
            ),
            (
                text("跨过缓慢期", "Trust Slow Progress"),
                text(
                    "前几周的变化可能不明显，但每次跑走间歇都在积累心肺能力。不要用一天的感觉判断九周的成长。",
                    "Early changes may be hard to see, but every run-walk interval builds fitness. Don't judge nine weeks of growth by how one day feels."
                )
            )
        ]
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        let index = ((day + offset) % prompts.count + prompts.count) % prompts.count
        return prompts[index]
    }

    static var trainingPrompts: String { text("训练提示", "Workout prompts") }
    static var voiceCoaching: String { text("语音陪跑与鼓励", "Voice coaching and encouragement") }
    static var trainingReminders: String { text("训练提醒", "Workout reminders") }
    static var reminderTime: String { text("提醒时间", "Reminder time") }
    static var time: String { text("时间", "Time") }
    static var trainingDays: String { text("训练日", "Workout days") }
    static var recoveryDayAdvice: String {
        text("建议训练之间至少间隔一天。", "Try to leave at least one rest day between workouts.")
    }
    static var distanceUnit: String { text("距离单位", "Distance unit") }
    static var kilometers: String { text("公里", "Kilometers") }
    static var miles: String { text("英里", "Miles") }
    static var kilometerAbbreviation: String { text("公里", "km") }
    static var mileAbbreviation: String { text("英里", "mi") }
    static var safetyNotice: String {
        text(
            "如出现胸痛、头晕或异常呼吸困难，请立即停止。有健康疑虑时，开始前先咨询专业人士。",
            "Stop immediately if you experience chest pain, dizziness, or unusual shortness of breath. Consult a healthcare professional before starting if you have health concerns."
        )
    }
    static var appLanguage: String { text("App 语言", "App Language") }
    static var appearance: String { text("外观", "Appearance") }
    static var colorTheme: String { text("配色主题", "Color Theme") }
    static var themePink: String { text("粉色", "Pink") }
    static var themeBlue: String { text("蓝色", "Blue") }
    static var themeGreen: String { text("绿色", "Green") }
    static var themeOrange: String { text("橙色", "Orange") }
    static var themePurple: String { text("紫色", "Purple") }
    static var themeTeal: String { text("青色", "Teal") }
    static var reminderSetupFailed: String { text("无法设置提醒", "Unable to Set Reminder") }

    static var profile: String { text("个人资料", "Profile") }
    static var aboutMe: String { text("关于我", "About Me") }
    static var personalDetails: String { text("个人信息", "Personal Details") }
    static var yourName: String { text("姓名", "Name") }
    static var namePlaceholder: String { text("输入姓名", "Enter your name") }
    static var birthdate: String { text("出生日期", "Birthdate") }
    static var age: String { text("年龄", "Age") }
    static var notSet: String { text("未设置", "Not set") }
    static var bodyMeasurements: String { text("身体数据", "Body Measurements") }
    static var height: String { text("身高", "Height") }
    static var weight: String { text("体重", "Weight") }
    static var centimeters: String { text("厘米", "cm") }
    static var inches: String { text("英寸", "in") }
    static var kilograms: String { text("公斤", "kg") }
    static var pounds: String { text("磅", "lb") }
    static var choosePhoto: String { text("选择照片", "Choose Photo") }
    static var changePhoto: String { text("更换照片", "Change Photo") }
    static var removePhoto: String { text("移除照片", "Remove photo") }

    static var greetingMorning: String { text("早上好", "Good morning") }
    static var greetingAfternoon: String { text("下午好", "Good afternoon") }
    static var greetingEvening: String { text("晚上好", "Good evening") }

    static func personalGreeting(_ name: String) -> String {
        text("你好，\(name)", "Hi, \(name)")
    }

    static var welcomeProfileTitle: String { text("认识一下你", "Tell Us About You") }
    static var welcomeProfileMessage: String {
        text(
            "这些信息帮助我们个性化你的训练体验，之后也可以在设置中修改。",
            "This helps personalize your experience — you can always change it later in Settings."
        )
    }

    static func ageYears(_ years: Int) -> String {
        text("\(years) 岁", years == 1 ? "1 year old" : "\(years) years old")
    }

    static var onboardingStartWalkingTitle: String { text("从走路开始", "Start with Walking") }
    static var onboardingStartWalkingMessage: String {
        text(
            "九周内逐渐用跑步替代步行。目标是轻松连续跑 30 分钟，而不是追求速度。",
            "Over nine weeks, gradually replace walking with running. The goal is an easy 30-minute continuous run—not speed."
        )
    }
    static var onboardingThreeTimesTitle: String { text("每周训练三次", "Train Three Times a Week") }
    static var onboardingThreeTimesMessage: String {
        text(
            "训练之间至少留一天恢复。如果某周感觉困难，可以安心重复，不必赶进度。",
            "Leave at least one recovery day between workouts. If a week feels difficult, repeat it without rushing."
        )
    }
    static var onboardingTalkPaceTitle: String { text("保持对话节奏", "Keep a Conversational Pace") }
    static var onboardingTalkPaceMessage: String {
        text(
            "跑步时应该还能说出完整短句。太喘就放慢速度，必要时改为步行。",
            "You should still be able to speak in short sentences. Slow down or walk if you become too breathless."
        )
    }
    static var startNineWeekPlan: String { text("开始九周计划", "Start the Nine-Week Plan") }
    static var setUpPlan: String { text("设置你的计划", "Set Up Your Plan") }
    static var preferencesCanChange: String { text("这些偏好之后都可以更改。", "You can change these preferences later.") }

    static var noCustomWorkouts: String { text("还没有自定义训练", "No Custom Workouts Yet") }
    static var noCustomWorkoutsDescription: String {
        text("创建适合当天状态的跑走间歇组合。", "Create run-walk intervals that suit how you feel today.")
    }
    static var createWorkout: String { text("创建训练", "Create Workout") }
    static var customWorkouts: String { text("自定义训练", "Custom Workouts") }
    static var createCustomWorkout: String { text("创建自定义训练", "Create a custom workout") }
    static var defaultCustomWorkoutName: String { text("我的间歇训练", "My Interval Workout") }
    static var name: String { text("名称", "Name") }
    static var workoutName: String { text("训练名称", "Workout name") }
    static var intervals: String { text("间歇", "Intervals") }
    static var running: String { text("跑步", "Run") }
    static var walking: String { text("步行", "Walk") }
    static var warmup: String { text("热身", "Warm-up") }
    static var cooldown: String { text("放松", "Cool-down") }
    static var warmupAndCooldown: String { text("热身与放松", "Warm-up & Cool-down") }
    static var newWorkout: String { text("新建训练", "New Workout") }

    static var end: String { text("结束", "End") }
    static var confirmEndWorkout: String { text("确定结束本次训练？", "End this workout?") }
    static var endWorkout: String { text("结束训练", "End Workout") }
    static var workoutComplete: String { text("训练完成", "Workout Complete") }
    static var workoutCompleteMessage: String {
        text(
            "做得很好！慢走几分钟，让呼吸和心率逐渐恢复。",
            "Great work! Walk slowly for a few minutes while your breathing and heart rate recover."
        )
    }
    static var locationNotice: String { text("定位提示", "Location Notice") }
    static var totalProgress: String { text("总进度", "Total progress") }
    static var completed: String { text("已完成", "Complete") }
    static var next: String { text("接下来", "Up next") }
    static var distance: String { text("距离", "Distance") }
    static var averagePace: String { text("平均配速", "Average pace") }
    static var skipSegment: String { text("跳到下一段", "Skip to the next interval") }
    static var resume: String { text("继续", "Resume") }
    static var pause: String { text("暂停", "Pause") }
    static var encourageMe: String { text("我有点累，鼓励我", "I'm getting tired—encourage me") }
    static var readyStatus: String { text("准备好后开始", "Start when you're ready") }
    static var runningStatus: String { text("保持自己的舒适节奏", "Keep a comfortable pace") }
    static var pausedStatus: String { text("训练已暂停", "Workout paused") }
    static var finishWorkout: String { text("完成训练", "Finish workout") }

    static var reminderPermissionDenied: String {
        text(
            "通知权限未开启。请在系统设置中允许通知，才能收到训练提醒。",
            "Notifications are disabled. Allow notifications in Settings to receive workout reminders."
        )
    }
    static var reminderTitle: String { text("今天跑一跑", "Ready for a Run?") }
    static var reminderBody: String {
        text(
            "你的 Couch 5K 训练已经准备好，按自己的节奏完成即可。",
            "Your Couch 5K workout is ready. Complete it at your own pace."
        )
    }
    static var healthUnavailable: String {
        text("此设备不支持健康数据。训练仍会保存在应用内。", "Health data isn't available on this device. Your workout will still be saved in the app.")
    }
    static var healthAuthorizationDenied: String {
        text(
            "未获得健康 App 写入权限，训练仍会保存在应用内。可在「设置 > 健康 > 数据访问与设备 > Couch 5K」中开启。",
            "Permission to write to Health hasn't been granted. Your workout is still saved in the app. You can enable it in Settings > Health > Data Access & Devices > Couch 5K."
        )
    }
    static var locationPermissionDenied: String {
        text("定位权限未开启，本次训练不会记录距离和路线。", "Location access is disabled. Distance and route won't be recorded for this workout.")
    }
    static var locationUnknown: String {
        text("无法确认定位权限，本次训练不会记录路线。", "Location access couldn't be determined. The route won't be recorded for this workout.")
    }

    static func locationUnavailable(_ detail: String) -> String {
        text("定位暂时不可用：\(detail)", "Location is temporarily unavailable: \(detail)")
    }

    static func weekTitle(_ week: Int) -> String {
        text("第 \(week) 周", "Week \(week)")
    }

    static func sessionTitle(_ day: Int) -> String {
        text("第 \(day) 次训练", "Workout \(day)")
    }

    static func plannedWorkoutTitle(week: Int, day: Int) -> String {
        text("第 \(week) 周 · 第 \(day) 次", "Week \(week) · Workout \(day)")
    }

    static func segmentProgress(current: Int, total: Int) -> String {
        text("已进行 \(current) / \(total) 段", "Interval \(current) of \(total)")
    }

    static func remaining(_ clock: String) -> String {
        text("剩余 \(clock)", "\(clock) remaining")
    }

    static func remainingAccessibility(_ clock: String, status: String) -> String {
        text("剩余 \(clock)，\(status)", "\(clock) remaining, \(status)")
    }

    static func repeatCount(_ count: Int) -> String {
        text("\(count) 组", "\(count) rounds")
    }

    static func repeatRounds(_ count: Int) -> String {
        text("重复 \(count) 组", "Repeat \(count) rounds")
    }

    static func startNamedWorkout(_ name: String) -> String {
        text("开始\(name)", "Start \(name)")
    }

    static func weekday(_ value: Int, short: Bool = false) -> String {
        let chinese = short
            ? [1: "日", 2: "一", 3: "二", 4: "三", 5: "四", 6: "五", 7: "六"][value]!
            : [1: "星期日", 2: "星期一", 3: "星期二", 4: "星期三", 5: "星期四", 6: "星期五", 7: "星期六"][value]!
        let english = short
            ? [1: "S", 2: "M", 3: "T", 4: "W", 5: "T", 6: "F", 7: "S"][value]!
            : [1: "Sunday", 2: "Monday", 3: "Tuesday", 4: "Wednesday", 5: "Thursday", 6: "Friday", 7: "Saturday"][value]!
        return text(chinese, english)
    }

    static func weekdayAccessibility(_ value: Int) -> String {
        weekday(value)
    }

    static func duration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if remainingSeconds == 0 {
            return text("\(minutes) 分钟", minutes == 1 ? "1 minute" : "\(minutes) minutes")
        }
        let englishMinutes = minutes == 1 ? "1 minute" : "\(minutes) minutes"
        let englishSeconds = remainingSeconds == 1 ? "1 second" : "\(remainingSeconds) seconds"
        return text("\(minutes) 分 \(remainingSeconds) 秒", "\(englishMinutes) \(englishSeconds)")
    }

    static func customWorkoutSummary(runSeconds: Int, walkSeconds: Int, cycles: Int) -> String {
        text(
            "跑 \(duration(runSeconds)) / 走 \(duration(walkSeconds))，共 \(cycles) 组",
            "Run \(duration(runSeconds)) / walk \(duration(walkSeconds)) for \(cycles) rounds"
        )
    }

    static var planTitle: String { text("从沙发到 5K", "Couch to 5K") }

    static func weekFocus(_ week: Int) -> String {
        switch week {
        case 1: text("建立跑走节奏", "Build a run-walk rhythm")
        case 2: text("延长跑步时间", "Extend your running time")
        case 3: text("首次完成 3 分钟跑", "Run for three minutes")
        case 4: text("提升持续耐力", "Build lasting endurance")
        case 5: text("迈向连续跑", "Move toward continuous running")
        case 6: text("稳定连续跑能力", "Strengthen continuous running")
        case 7: text("巩固 25 分钟连续跑", "Consolidate a 25-minute run")
        case 8: text("接近最终目标", "Approach the final goal")
        default: text("完成 30 分钟连续跑", "Complete a 30-minute run")
        }
    }

    static func planSessionSummary(week: Int, day: Int) -> String {
        switch (week, day) {
        case (1, _): text("跑 1 分钟 / 走 90 秒，共 8 组", "Run 1 minute / walk 90 seconds for 8 rounds")
        case (2, _): text("跑 90 秒 / 走 2 分钟，共 6 组", "Run 90 seconds / walk 2 minutes for 6 rounds")
        case (3, _): text("90 秒跑走 + 3 分钟跑走，重复 2 次", "90-second and 3-minute run-walk intervals, repeated twice")
        case (4, _): text("3 分跑、5 分跑交替，共 21.5 分钟", "Alternate 3- and 5-minute runs for 21.5 minutes")
        case (5, 1): text("跑 5 分钟 × 3，中间步行 3 分钟", "Run 5 minutes × 3 with 3-minute walks")
        case (5, 2): text("跑 8 分钟 × 2，中间步行 5 分钟", "Run 8 minutes × 2 with a 5-minute walk")
        case (5, _): text("连续跑 20 分钟", "Run continuously for 20 minutes")
        case (6, 1): text("跑 5、8、5 分钟，中间步行 3 分钟", "Run 5, 8, and 5 minutes with 3-minute walks")
        case (6, 2): text("跑 10 分钟 × 2，中间步行 3 分钟", "Run 10 minutes × 2 with a 3-minute walk")
        case (6, _), (7, _): text("连续跑 25 分钟", "Run continuously for 25 minutes")
        case (8, _): text("连续跑 28 分钟", "Run continuously for 28 minutes")
        default: text("连续跑 30 分钟", "Run continuously for 30 minutes")
        }
    }

    static func segmentTitle(_ kind: SegmentKind) -> String {
        switch kind {
        case .warmup: text("热身步行", "Warm-up Walk")
        case .run: text("跑步", "Run")
        case .walk: text("步行恢复", "Recovery Walk")
        case .cooldown: text("放松步行", "Cool-down Walk")
        }
    }

    static func cueAnnouncement(_ kind: SegmentKind) -> String {
        switch kind {
        case .warmup: text("开始热身走。", "Easy warm-up walk.")
        case .run: text("开始跑，稳住节奏。", "Let's run. Find your rhythm.")
        case .walk: text("做得好，走路恢复。", "Nice work. Recovery walk.")
        case .cooldown: text("做得好，开始放松。", "Great work. Cool down.")
        }
    }

    static var completionCue: String { text("完成了，做得很好。", "You did it. Great work.") }
    static var completionNotificationBody: String {
        text("做得很好，记得慢走放松。", "Great work. Remember to walk slowly and cool down.")
    }

    static var encouragements: [String] {
        AppLanguage.current == .simplifiedChinese
            ? ["加油。", "继续坚持。", "稳住节奏。", "你做得很好。", "一步一步来。"]
            : ["You've got this.", "Keep going.", "Stay with it.", "Strong and steady.", "One step at a time."]
    }

    static var finishLineEncouragements: [String] {
        AppLanguage.current == .simplifiedChinese
            ? ["快到了。", "就差一点。", "再坚持一下。", "最后加把劲。"]
            : ["Almost there.", "You're so close.", "Just a little longer.", "One final push."]
    }

    static var showAllWorkouts: String { text("显示全部", "Show All") }
    static var noWorkoutsThisDay: String { text("这一天没有训练记录", "No workouts on this day") }
    static var loadMore: String { text("加载更多", "Load More") }

    static func workoutsOnDate(_ date: Date) -> String {
        let dateText = date.formatted(
            .dateTime
                .month(.wide)
                .day()
                .locale(AppLanguage.current.locale)
        )
        return text("\(dateText)的训练", "Workouts on \(dateText)")
    }

    static var noHistory: String { text("还没有训练记录", "No Workouts Yet") }
    static var noHistoryDescription: String {
        text("完成第一次训练后，记录会显示在这里。", "Your workouts will appear here after you complete your first one.")
    }
    static var allWorkouts: String { text("所有训练", "All Workouts") }
    static var workoutHistory: String { text("训练历史", "Workout History") }
    static var myBadges: String { text("我的勋章", "My Badges") }
    static var badgesMessage: String {
        text("每次完成，都在强化“我是跑者”这个身份。", "Every completion reinforces your identity as a runner.")
    }
    static var earned: String { text("已获得", "Earned") }
    static var workoutOverview: String { text("训练概览", "Workout Overview") }
    static var completions: String { text("完成次数", "Completed") }
    static var totalTraining: String { text("累计训练", "Total Training") }
    static var totalDistance: String { text("累计距离", "Total Distance") }
    static var thisWeek: String { text("本周训练", "This Week") }
    static var workoutTrends: String { text("训练趋势", "Workout Trends") }
    static var recentDuration: String { text("近期训练时长", "Recent Workout Duration") }
    static var eightWeekFrequency: String { text("八周训练频率", "Eight-Week Frequency") }
    static var weeklyCompletions: String { text("每周完成次数", "Workouts per Week") }
    static var distanceTrend: String { text("距离趋势", "Distance Trend") }
    static var date: String { text("日期", "Date") }
    static var minutes: String { text("分钟", "Minutes") }
    static var minuteAbbreviation: String { text("分", "min") }
    static var pastTwelveWeeks: String { text("过去 12 周", "Past 12 weeks") }
    static var activityCalendar: String { text("运动日历", "Activity Calendar") }
    static var previousMonth: String { text("上个月", "Previous month") }
    static var nextMonth: String { text("下个月", "Next month") }
    static var week: String { text("周", "Week") }
    static var trainingWeeks: String { text("训练周", "Weeks") }
    static var viewFullPlan: String { text("查看完整计划", "View full plan") }
    static var nineWeekPlan: String { text("九周计划", "9-Week Plan") }
    static var count: String { text("次数", "Count") }
    static var hasNotes: String { text("有笔记", "Has notes") }
    static var workout: String { text("训练", "Workout") }
    static var plan: String { text("计划", "Plan") }
    static var content: String { text("内容", "Details") }
    static var duration: String { text("时长", "Duration") }
    static var completedAt: String { text("完成时间", "Completed") }
    static var route: String { text("路线", "Route") }
    static var routeMapAccessibility: String { text("本次训练路线地图", "Map of this workout's route") }
    static var workoutNotes: String { text("训练笔记", "Workout Notes") }
    static var workoutNotesPlaceholder: String {
        text("记录身体感受、路线或下次想调整的内容…", "Record how you felt, your route, or what you'd change next time…")
    }

    static func recentWorkoutCount(_ count: Int) -> String {
        text("最近 \(count) 次训练", "Last \(count) workouts")
    }

    static func workoutsWithRoutes(_ unit: String) -> String {
        text("有路线记录的训练 · \(unit)", "Workouts with routes · \(unit)")
    }

    static func workoutProgress(current: Int, target: Int) -> String {
        text("\(current) / \(target) 次", "\(current) / \(target) workouts")
    }

    static func weekProgress(current: Int, target: Int) -> String {
        text("\(current) / \(target) 周", "\(current) / \(target) weeks")
    }

    static func monthWorkoutCount(_ count: Int) -> String {
        text("本月完成 \(count) 次训练", count == 1 ? "1 workout this month" : "\(count) workouts this month")
    }

    static func calendarDayAccessibility(date: Date, workoutCount: Int) -> String {
        let dateText = date.formatted(
            .dateTime
                .year()
                .month(.wide)
                .day()
                .locale(AppLanguage.current.locale)
        )
        guard workoutCount > 0 else {
            return text("\(dateText)，没有训练", "\(dateText), no workout")
        }
        return text(
            "\(dateText)，完成 \(workoutCount) 次训练",
            workoutCount == 1
                ? "\(dateText), 1 workout"
                : "\(dateText), \(workoutCount) workouts"
        )
    }

    static func badge(id: String) -> (title: String, detail: String) {
        switch id {
        case "first-step":
            (text("第一步", "First Step"), text("完成第一次训练", "Complete your first workout"))
        case "habit-started":
            (text("习惯启动", "Habit Started"), text("累计完成 3 次训练", "Complete 3 workouts"))
        case "showing-up":
            (text("持续出现", "Showing Up"), text("连续 2 周保持训练", "Stay active for 2 consecutive weeks"))
        case "ten-strong":
            (text("渐入佳境", "Ten Strong"), text("累计完成 10 次训练", "Complete 10 workouts"))
        case "five-kilometers":
            (text("五公里积累", "Five Kilometers"), text("累计记录 5 公里", "Record 5 total kilometers"))
        case "consistent-month":
            (text("稳定一个月", "Consistent Month"), text("连续 4 周保持训练", "Stay active for 4 consecutive weeks"))
        case "distance-builder":
            (text("脚下有路", "Distance Builder"), text("累计记录 25 公里", "Record 25 total kilometers"))
        default:
            ("Couch 5K", text("完成九周全部 27 次训练", "Complete all 27 workouts in the nine-week plan"))
        }
    }
}
