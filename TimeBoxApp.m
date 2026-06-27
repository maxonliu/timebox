#import <Cocoa/Cocoa.h>

// ─── Warm light theme — human-eye friendly ──────────────
#define C_BG        [NSColor colorWithRed:0.94 green:0.91 blue:0.86 alpha:1]   // warm cream
#define C_TEXT      [NSColor colorWithRed:0.18 green:0.15 blue:0.12 alpha:1]   // dark brown
#define C_DIM       [NSColor colorWithRed:0.45 green:0.40 blue:0.35 alpha:1]   // muted brown
#define C_ACCENT    [NSColor colorWithRed:0.65 green:0.45 blue:0.25 alpha:1]   // warm gold-brown
#define C_WARN      [NSColor colorWithRed:0.82 green:0.35 blue:0.25 alpha:1]   // warm red
#define C_GREEN     [NSColor colorWithRed:0.30 green:0.55 blue:0.35 alpha:1]   // forest green
#define C_CARD      [NSColor whiteColor]
#define C_BORDER    [NSColor colorWithRed:0.80 green:0.76 blue:0.70 alpha:1]
#define C_PROGRESS  [NSColor colorWithRed:0.85 green:0.78 blue:0.65 alpha:1]
#define BASE_W      340.0
#define BASE_H      380.0
#define SCALE_MIN   0.75
#define SCALE_MAX   1.25
#define SCALE_STEP  0.05

static CGFloat TimeBoxScale(void) {
    CGFloat scale = [[NSUserDefaults standardUserDefaults] doubleForKey:@"timebox_window_scale"];
    if (scale < SCALE_MIN || scale > SCALE_MAX) scale = 1.0;
    return scale;
}

static void ApplyTitlebarScale(NSWindow *window, CGFloat scale) {
    NSButton *close = [window standardWindowButton:NSWindowCloseButton];
    NSButton *mini = [window standardWindowButton:NSWindowMiniaturizeButton];
    NSButton *zoom = [window standardWindowButton:NSWindowZoomButton];
    if (!close || !mini || !zoom) return;

    NSView *titlebar = close.superview;
    CGFloat size = 14.0 * scale;
    CGFloat y = MAX(2.0, close.frame.origin.y + (close.frame.size.height - size) / 2.0 - 3.0 * scale);
    close.frame = NSMakeRect(18.0 * scale, y, size, size);
    mini.frame = NSMakeRect(48.0 * scale, y, size, size);
    zoom.frame = NSMakeRect(78.0 * scale, y, size, size);

    NSTextField *title = [titlebar viewWithTag:9001];
    if (!title) {
        title = [[NSTextField alloc] initWithFrame:NSZeroRect];
        title.tag = 9001;
        title.stringValue = @"TimeBox";
        title.bezeled = NO;
        title.editable = NO;
        title.selectable = NO;
        title.drawsBackground = NO;
        title.textColor = [NSColor colorWithRed:0.33 green:0.32 blue:0.32 alpha:1];
        title.alignment = NSTextAlignmentCenter;
        [titlebar addSubview:title];
    }
    title.font = [NSFont systemFontOfSize:15.0 * scale weight:NSFontWeightBold];
    CGFloat titleW = MIN(150.0 * scale, MAX(90.0 * scale, titlebar.bounds.size.width - 180.0 * scale));
    CGFloat titleH = 24.0 * scale;
    CGFloat titleX = (titlebar.bounds.size.width - titleW) / 2.0;
    CGFloat titleY = y + (size - titleH) / 2.0;
    title.frame = NSMakeRect(titleX, titleY, titleW, titleH);
    window.titleVisibility = NSWindowTitleHidden;
}

// ─── Daily note path — helper ────────────────────────────
// Priority: NOTE_DIR env var > NSUserDefaults (config button) > ~/Documents/Notes/Today/
static NSString *NotePath(void) {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSInteger y = [cal component:NSCalendarUnitYear fromDate:[NSDate date]];
    NSInteger m = [cal component:NSCalendarUnitMonth fromDate:[NSDate date]];

    char *env = getenv("NOTE_DIR");
    NSString *dir;
    if (env && strlen(env) > 0) {
        dir = [NSString stringWithUTF8String:env];
    } else {
        dir = [[NSUserDefaults standardUserDefaults] stringForKey:@"timebox_note_dir"];
        if (!dir) {
            dir = [@"~/Documents/Notes/Today/" stringByExpandingTildeInPath];
        }
    }
    return [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%04ld-%02ld.md", (long)y, (long)m]];
}

@interface LogEntry : NSObject
@property (strong) NSString *task;
@property (strong) NSString *time;
@property int blockIdx;
@end
@implementation LogEntry
@end

@interface TimeBoxView : NSView <NSTextFieldDelegate, NSTableViewDelegate, NSTableViewDataSource, NSTextViewDelegate>
@property (strong) NSTextField *timerField;
@property (strong) NSTextField *blockField;
@property (strong) NSTextField *intentField;
@property (strong) NSTextField *taskField;
@property (strong) NSButton *punchBtn;
@property (strong) NSButton *pauseBtn;
@property (strong) NSTableView *logTable;
@property (strong) NSMutableArray<LogEntry*> *logs;
@property int remaining;
@property int blockIdx;
@property int round;
@property BOOL running;
@property NSTimer *tickTimer;
// 📋 Todo
@property (strong) NSButton *todoBtn;
@property BOOL todoOpen;
@property (strong) NSView *todoPanel;
@property (strong) NSTextView *todoTextView;
@property (strong) NSView *flashView;
@property BOOL fiveMinuteAlerted;
@property BOOL oneMinuteAlerted;
@end

@implementation TimeBoxView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.logs = [NSMutableArray new];
        self.blockIdx = [self currentBlockIdx];
        self.remaining = 600;
        self.running = YES;
        self.round = 0;
        [self buildUI];
        [self updateDisplay];
        [self loadLogs];
        self.tickTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    }
    return self;
}

- (int)currentBlockIdx {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSInteger h = [cal component:NSCalendarUnitHour fromDate:[NSDate date]];
    NSInteger m = [cal component:NSCalendarUnitMinute fromDate:[NSDate date]];
    return (int)((h*60 + m) / 10);
}

- (NSString *)todaySection {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSInteger month = [cal component:NSCalendarUnitMonth fromDate:[NSDate date]];
    NSInteger day = [cal component:NSCalendarUnitDay fromDate:[NSDate date]];
    return [NSString stringWithFormat:@"## %ld.%ld", (long)month, (long)day];
}

- (CGFloat)layoutScale {
    CGFloat sx = self.bounds.size.width / BASE_W;
    CGFloat sy = self.bounds.size.height / BASE_H;
    CGFloat scale = MIN(sx, sy);
    return MAX(SCALE_MIN, MIN(SCALE_MAX, scale));
}

- (CGFloat)L:(CGFloat)value {
    return value * [self layoutScale];
}

- (void)buildUI {
    CGFloat W = self.bounds.size.width;
    CGFloat Y = self.bounds.size.height;

    // ── Timer display ──
    self.timerField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, Y-[self L:104], W, [self L:92])];
    [self.timerField setFont:[NSFont monospacedDigitSystemFontOfSize:[self L:72] weight:NSFontWeightThin]];
    [self.timerField setTextColor:C_ACCENT];
    [self.timerField setAlignment:NSTextAlignmentCenter];
    [self.timerField setStringValue:@"10:00"];
    [self.timerField setBezeled:NO];
    [self.timerField setEditable:NO];
    [self.timerField setBackgroundColor:[NSColor clearColor]];
    [self addSubview:self.timerField];

    // ── Block info ──
    self.blockField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, Y-[self L:128], W, [self L:24])];
    [self.blockField setFont:[NSFont systemFontOfSize:[self L:12] weight:NSFontWeightMedium]];
    [self.blockField setTextColor:C_DIM];
    [self.blockField setAlignment:NSTextAlignmentCenter];
    [self.blockField setStringValue:@"—"];
    [self.blockField setBezeled:NO];
    [self.blockField setEditable:NO];
    [self.blockField setBackgroundColor:[NSColor clearColor]];
    [self addSubview:self.blockField];
    [self updateBlockText];

    // ── Intention ──
    self.intentField = [[NSTextField alloc] initWithFrame:NSMakeRect([self L:16], Y-[self L:178], W-[self L:32], [self L:24])];
    [self.intentField setFont:[NSFont systemFontOfSize:[self L:13] weight:NSFontWeightMedium]];
    [self.intentField setTextColor:C_DIM];
    [self.intentField setStringValue:@"✏️ 写下这个10分钟的任务"];
    [self.intentField setAlignment:NSTextAlignmentCenter];
    [self.intentField setBezeled:NO];
    [self.intentField setEditable:NO];
    [self.intentField setBackgroundColor:[NSColor clearColor]];
    [self addSubview:self.intentField];

    // ── Task input ──
    self.taskField = [[NSTextField alloc] initWithFrame:NSMakeRect([self L:16], Y-[self L:214], [self L:200], [self L:34])];
    [self.taskField setPlaceholderString:@"要做什么？"];
    [self.taskField setFont:[NSFont systemFontOfSize:[self L:14]]];
    [self.taskField setTextColor:C_TEXT];
    [self.taskField setBackgroundColor:C_CARD];
    [self.taskField setBezeled:YES];
    [self.taskField setBordered:YES];
    [self.taskField setBezelStyle:NSTextFieldSquareBezel];
    [self.taskField setDelegate:self];
    [self addSubview:self.taskField];

    // ── Todo button ──
    self.todoBtn = [[NSButton alloc] initWithFrame:NSMakeRect(W-[self L:116], Y-[self L:216], [self L:36], [self L:36])];
    [self.todoBtn setBordered:NO];
    [self.todoBtn setTarget:self];
    [self.todoBtn setAction:@selector(toggleTodo)];
    self.todoBtn.wantsLayer = YES;
    self.todoBtn.layer.backgroundColor = [NSColor colorWithWhite:0.82 alpha:0.5].CGColor;
    self.todoBtn.layer.cornerRadius = [self L:8];
    [self.todoBtn setTitle:@"📋"];
    [self.todoBtn setFont:[NSFont systemFontOfSize:[self L:16]]];
    [self addSubview:self.todoBtn];

    // ── Punch button ──
    self.punchBtn = [[NSButton alloc] initWithFrame:NSMakeRect(W-[self L:66], Y-[self L:216], [self L:50], [self L:36])];
    [self.punchBtn setBordered:NO];
    [self.punchBtn setTarget:self];
    [self.punchBtn setAction:@selector(punchIn)];
    self.punchBtn.wantsLayer = YES;
    self.punchBtn.layer.backgroundColor = C_GREEN.CGColor;
    self.punchBtn.layer.cornerRadius = [self L:8];

    // Use system checkmark icon (SF Symbols, macOS 11+)
    if (@available(macOS 11.0, *)) {
        NSImage *checkSymbol = [NSImage imageWithSystemSymbolName:@"checkmark"
                                            accessibilityDescription:nil];
        [self.punchBtn setImage:checkSymbol];
        [self.punchBtn setImagePosition:NSImageOnly];
        [self.punchBtn setContentTintColor:[NSColor whiteColor]];
    } else {
        [self.punchBtn setTitle:@"✓"];
        [self.punchBtn setFont:[NSFont systemFontOfSize:[self L:20] weight:NSFontWeightBold]];
    }
    [self addSubview:self.punchBtn];

    // ── Control buttons ──
    self.pauseBtn = [[NSButton alloc] initWithFrame:NSMakeRect([self L:16], Y-[self L:254], [self L:90], [self L:28])];
    [self.pauseBtn setTitle:@"⏸ 暂停"];
    [self.pauseBtn setFont:[NSFont systemFontOfSize:[self L:12]]];
    [self.pauseBtn setBezelStyle:NSBezelStyleTexturedRounded];
    [self.pauseBtn setTarget:self];
    [self.pauseBtn setAction:@selector(togglePause)];
    [self addSubview:self.pauseBtn];

    NSButton *skip = [[NSButton alloc] initWithFrame:NSMakeRect([self L:112], Y-[self L:254], [self L:72], [self L:28])];
    [skip setTitle:@"⏭ 跳过"];
    [skip setFont:[NSFont systemFontOfSize:[self L:12]]];
    [skip setBezelStyle:NSBezelStyleTexturedRounded];
    [skip setTarget:self];
    [skip setAction:@selector(skipBlock)];
    [self addSubview:skip];

    NSButton *reset = [[NSButton alloc] initWithFrame:NSMakeRect([self L:190], Y-[self L:254], [self L:72], [self L:28])];
    [reset setTitle:@"⟳ 重置"];
    [reset setFont:[NSFont systemFontOfSize:[self L:12]]];
    [reset setBezelStyle:NSBezelStyleTexturedRounded];
    [reset setTarget:self];
    [reset setAction:@selector(resetAll)];
    [self addSubview:reset];

    // ── Config ⚙️ (unobtrusive) ──
    NSButton *cfg = [[NSButton alloc] initWithFrame:NSMakeRect([self L:268], Y-[self L:254], [self L:24], [self L:28])];
    [cfg setBordered:NO];
    [cfg setTarget:self];
    [cfg setAction:@selector(showSettings:)];
    [cfg setTitle:@"⚙️"];
    [cfg setFont:[NSFont systemFontOfSize:[self L:10]]];
    [cfg setToolTip:@"设置"];
    [self addSubview:cfg];

    // ── Log table ──
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"c"];
    col.width = W - [self L:36];
    col.minWidth = W - [self L:36];

    NSTableView *tv = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, W-[self L:36], [self L:100])];
    [tv addTableColumn:col];
    [tv setHeaderView:nil];
    [tv setBackgroundColor:[NSColor clearColor]];
    [tv setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
    [tv setRowHeight:[self L:24]];
    [tv setIntercellSpacing:NSMakeSize(0, [self L:2])];
    tv.delegate = self;
    tv.dataSource = self;
    self.logTable = tv;

    NSScrollView *sv = [[NSScrollView alloc] initWithFrame:NSMakeRect([self L:16], [self L:4], W-[self L:32], [self L:130])];
    [sv setDocumentView:tv];
    [sv setHasVerticalScroller:YES];
    [sv setBorderType:NSNoBorder];
    [sv setDrawsBackground:NO];
    [sv setBackgroundColor:[NSColor clearColor]];
    [self addSubview:sv];

    self.flashView = [[NSView alloc] initWithFrame:self.bounds];
    self.flashView.wantsLayer = YES;
    self.flashView.layer.backgroundColor = [NSColor colorWithRed:1.0 green:0.78 blue:0.22 alpha:1.0].CGColor;
    self.flashView.alphaValue = 0.0;
    self.flashView.hidden = YES;
    [self addSubview:self.flashView positioned:NSWindowAbove relativeTo:nil];
}

- (void)updateBlockText {
    int idx = self.blockIdx;
    int h1 = idx*10/60, m1 = idx*10%60;
    int h2 = (idx+1)*10/60%24, m2 = (idx+1)*10%60;
    self.blockField.stringValue = [NSString stringWithFormat:@"%02d:%02d – %02d:%02d    第 %02d 块    %d 轮打卡",
                                    h1,m1,h2,m2,idx+1,self.round];
}

- (void)tick {
    if (!self.running) return;
    self.remaining--;
    if (self.remaining == 300 && !self.fiveMinuteAlerted) {
        self.fiveMinuteAlerted = YES;
        [self flashReminder];
    } else if (self.remaining == 60 && !self.oneMinuteAlerted) {
        self.oneMinuteAlerted = YES;
        [self flashReminder];
    }
    if (self.remaining <= 0) {
        self.remaining = 0;
        [self autoPunch];
        [self nextBlock];
    }
    [self updateDisplay];
}

- (void)flashReminder {
    if (!self.flashView) return;
    self.flashView.frame = self.bounds;
    [self.flashView removeFromSuperview];
    [self addSubview:self.flashView positioned:NSWindowAbove relativeTo:nil];
    self.flashView.hidden = NO;
    self.flashView.alphaValue = 0.0;

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.16;
        self.flashView.animator.alphaValue = 0.22;
    } completionHandler:^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.18;
            self.flashView.animator.alphaValue = 0.0;
        } completionHandler:^{
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                context.duration = 0.16;
                self.flashView.animator.alphaValue = 0.18;
            } completionHandler:^{
                [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                    context.duration = 0.24;
                    self.flashView.animator.alphaValue = 0.0;
                } completionHandler:^{
                    self.flashView.hidden = YES;
                }];
            }];
        }];
    }];
}

- (void)updateDisplay {
    int m = self.remaining / 60;
    int s = self.remaining % 60;
    self.timerField.stringValue = [NSString stringWithFormat:@"%d:%02d", m, s];
    BOOL warn = self.remaining < 180;
    self.timerField.textColor = warn ? C_WARN : C_ACCENT;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    CGFloat W = self.bounds.size.width;
    CGFloat Y = self.bounds.size.height;

    // Progress bar background
    NSRect bg = NSMakeRect([self L:16], Y-[self L:142], W-[self L:32], [self L:4]);
    [C_PROGRESS setFill];
    [[NSBezierPath bezierPathWithRoundedRect:bg xRadius:[self L:2] yRadius:[self L:2]] fill];

    // Progress fill
    double pct = (600.0 - self.remaining) / 600.0;
    if (pct > 0) {
        NSRect fg = NSMakeRect([self L:16], Y-[self L:142], (W-[self L:32])*pct, [self L:4]);
        [(self.remaining < 180 ? C_WARN : C_ACCENT) setFill];
        [[NSBezierPath bezierPathWithRoundedRect:fg xRadius:[self L:2] yRadius:[self L:2]] fill];
    }
}

- (void)fieldChanged {
    NSString *t = [self.taskField.stringValue stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceCharacterSet]];
    if (t.length > 0) {
        self.intentField.stringValue = [@"🎯 " stringByAppendingString:t];
        self.intentField.textColor = C_ACCENT;
    } else {
        self.intentField.stringValue = @"✏️ 写下这个10分钟的任务";
        self.intentField.textColor = C_DIM;
    }
}

- (void)controlTextDidChange:(NSNotification *)obj { [self fieldChanged]; }

// ─── Write to daily note ─────────────────────────────────
- (void)writeToDailyNote:(NSString *)timeStr task:(NSString *)task {
    NSString *section = [self todaySection];
    NSString *entry = [NSString stringWithFormat:@"%@ %@", timeStr, task];

    NSError *err = nil;
    NSString *content = [NSString stringWithContentsOfFile:NotePath() encoding:NSUTF8StringEncoding error:&err];
    if (!content) content = @"";

    // Split into lines and trim trailing empty lines
    NSMutableArray *lines = [[content componentsSeparatedByString:@"\n"] mutableCopy];
    while (lines.count > 0 && [lines.lastObject isEqualToString:@""])
        [lines removeLastObject];

    // Find today's section
    NSInteger sectionIdx = NSNotFound;
    for (NSInteger i = 0; i < lines.count; i++) {
        if ([lines[i] isEqualToString:section]) {
            sectionIdx = i;
            break;
        }
    }

    if (sectionIdx != NSNotFound) {
        // Find the last non-blank entry line in this section.
        // This avoids inserting after section-separator blank lines.
        NSInteger lastEntryIdx = sectionIdx;
        for (NSInteger i = sectionIdx + 1; i < lines.count; i++) {
            NSString *line = lines[i];
            if ([line hasPrefix:@"## "]) break;  // next section
            if ([line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0) {
                lastEntryIdx = i;
            }
        }
        // Insert after the last non-blank entry
        if (lastEntryIdx == sectionIdx) {
            // Empty section — blank line after header, then entry
            [lines insertObject:@"" atIndex:sectionIdx + 1];
            [lines insertObject:entry atIndex:sectionIdx + 2];
        } else {
            // Consecutive entry — no blank line
            [lines insertObject:entry atIndex:lastEntryIdx + 1];
        }
    } else {
        // New section — append at end
        [lines addObject:@""];
        [lines addObject:section];
        [lines addObject:@""];
        [lines addObject:entry];
    }

    NSString *result = [[lines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
    [result writeToFile:NotePath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

// ─── Punch ────────────────────────────────────────────────
- (void)punchIn {
    NSString *task = [self.taskField.stringValue stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceCharacterSet]];
    if (task.length == 0) task = @"（专注）";
    self.round++;

    // Log locally
    LogEntry *e = [LogEntry new];
    e.task = task;
    NSDateFormatter *df = [NSDateFormatter new];
    [df setDateFormat:@"HH:mm"];
    NSString *timeStr = [df stringFromDate:[NSDate date]];
    e.time = timeStr;
    e.blockIdx = self.blockIdx;
    [self.logs insertObject:e atIndex:0];
    [self.logTable reloadData];
    [self updateBlockText];
    [self saveLogs];

    // Sync to daily note
    [self writeToDailyNote:timeStr task:task];

    // ⭐ Restart 10-min timer — new task, fresh block
    self.remaining = 600;
    self.running = YES;
    [self.pauseBtn setTitle:@"⏸ 暂停"];
    [self updateDisplay];
}

- (void)autoPunch {
    NSString *task = [self.taskField.stringValue stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceCharacterSet]];
    if (task.length == 0) return;
    self.round++;

    LogEntry *e = [LogEntry new];
    e.task = task;
    NSDateFormatter *df = [NSDateFormatter new];
    [df setDateFormat:@"HH:mm"];
    NSString *timeStr = [df stringFromDate:[NSDate date]];
    e.time = timeStr;
    e.blockIdx = self.blockIdx;
    [self.logs insertObject:e atIndex:0];
    [self.logTable reloadData];
    [self updateBlockText];
    [self saveLogs];

    // Sync to daily note
    [self writeToDailyNote:timeStr task:task];
}

- (void)nextBlock {
    self.blockIdx = (self.blockIdx + 1) % (24*6);
    self.remaining = 600;
    self.running = YES;
    self.fiveMinuteAlerted = NO;
    self.oneMinuteAlerted = NO;
    [self.pauseBtn setTitle:@"⏸ 暂停"];
    [self updateBlockText];
    [self updateDisplay];
}

- (void)togglePause {
    self.running = !self.running;
    [self.pauseBtn setTitle:self.running ? @"⏸ 暂停" : @"▶ 继续"];
}

- (void)skipBlock { [self autoPunch]; [self nextBlock]; }

- (void)resetAll {
    self.blockIdx = [self currentBlockIdx];
    self.remaining = 600;
    self.running = YES;
    self.round = 0;
    self.fiveMinuteAlerted = NO;
    self.oneMinuteAlerted = NO;
    [self.taskField setStringValue:@""];
    [self.pauseBtn setTitle:@"⏸ 暂停"];
    [self.intentField setStringValue:@"✏️ 写下这个10分钟的任务"];
    [self.intentField setTextColor:C_DIM];
    [self.logs removeAllObjects];
    [self.logTable reloadData];
    [self updateBlockText];
    [self updateDisplay];
    [self clearLogs];
}

// ─── Persistence ─────────────────────────────────────────
- (void)saveLogs {
    NSMutableArray *arr = [NSMutableArray new];
    for (LogEntry *e in self.logs)
        [arr addObject:@{@"task":e.task?:@"",@"time":e.time?:@"",@"block":@(e.blockIdx)}];
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey:@"timebox_logs"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)loadLogs {
    NSArray *arr = [[NSUserDefaults standardUserDefaults] arrayForKey:@"timebox_logs"];
    if (!arr) return;
    for (NSDictionary *d in arr) {
        LogEntry *e = [LogEntry new];
        e.task = d[@"task"] ?: @"";
        e.time = d[@"time"] ?: @"";
        e.blockIdx = [d[@"block"] intValue];
        [self.logs addObject:e];
    }
    [self.logTable reloadData];
}

- (void)clearLogs {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"timebox_logs"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// ─── NSTableView ─────────────────────────────────────────
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
    return MIN((NSInteger)self.logs.count, 20);
}

- (NSView *)tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)col row:(NSInteger)row {
    if (row >= (NSInteger)self.logs.count) return nil;
    LogEntry *e = self.logs[row];
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect([self L:6], [self L:1], tv.bounds.size.width-[self L:12], [self L:22])];
    [label setStringValue:[NSString stringWithFormat:@"🎯 %@  · %@", e.task, e.time]];
    [label setFont:[NSFont systemFontOfSize:[self L:12]]];
    [label setTextColor:C_TEXT];
    [label setBezeled:NO];
    [label setEditable:NO];
    [label setBackgroundColor:[NSColor clearColor]];
    return label;
}

// ─── 📋 Todo ──────────────────────────────────────────────
- (void)applyWindowScale:(CGFloat)scale {
    scale = MAX(SCALE_MIN, MIN(SCALE_MAX, scale));
    [[NSUserDefaults standardUserDefaults] setDouble:scale forKey:@"timebox_window_scale"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSWindow *window = self.window;
    if (!window) return;

    NSSize contentSize = NSMakeSize(BASE_W * scale, BASE_H * scale);
    NSRect frame = window.frame;
    NSRect contentRect = [window contentRectForFrameRect:frame];
    CGFloat dx = contentSize.width - contentRect.size.width;
    CGFloat dy = contentSize.height - contentRect.size.height;
    frame.size.width += dx;
    frame.size.height += dy;
    frame.origin.y -= dy;
    NSString *task = [self.taskField.stringValue copy] ?: @"";
    NSString *todo = self.todoTextView ? [self.todoTextView.string copy] : nil;
    BOOL wasTodoOpen = self.todoOpen;

    [window setFrame:frame display:YES animate:YES];
    ApplyTitlebarScale(window, scale);

    self.frame = NSMakeRect(0, 0, contentSize.width, contentSize.height);
    self.bounds = NSMakeRect(0, 0, contentSize.width, contentSize.height);
    for (NSView *subview in [self.subviews copy]) [subview removeFromSuperview];
    self.timerField = nil;
    self.blockField = nil;
    self.intentField = nil;
    self.taskField = nil;
    self.punchBtn = nil;
    self.pauseBtn = nil;
    self.logTable = nil;
    self.todoBtn = nil;
    self.todoPanel = nil;
    self.todoTextView = nil;
    self.flashView = nil;
    self.todoOpen = NO;

    [self buildUI];
    self.taskField.stringValue = task;
    if (!self.running) [self.pauseBtn setTitle:@"▶ 继续"];
    [self updateBlockText];
    [self updateDisplay];
    [self fieldChanged];
    [self.logTable reloadData];
    if (todo) [[NSUserDefaults standardUserDefaults] setObject:todo forKey:@"timebox_todo_text"];
    if (wasTodoOpen) [self toggleTodo];
    [self setNeedsDisplay:YES];
}

- (void)scaleDown {
    [self applyWindowScale:TimeBoxScale() - SCALE_STEP];
}

- (void)scaleReset {
    [self applyWindowScale:1.0];
}

- (void)scaleUp {
    [self applyWindowScale:TimeBoxScale() + SCALE_STEP];
}

- (void)showSettings:(id)sender {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"TimeBox 设置"];
    CGFloat scale = TimeBoxScale();

    NSMenuItem *down = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"缩小一档  %.0f%%", MAX(SCALE_MIN, scale - SCALE_STEP) * 100]
                                                    action:@selector(scaleDown)
                                             keyEquivalent:@""];
    down.target = self;
    down.enabled = scale > SCALE_MIN;
    [menu addItem:down];

    NSMenuItem *reset = [[NSMenuItem alloc] initWithTitle:@"恢复正常  100%"
                                                     action:@selector(scaleReset)
                                              keyEquivalent:@""];
    reset.target = self;
    [menu addItem:reset];

    NSMenuItem *up = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"放大一档  %.0f%%", MIN(SCALE_MAX, scale + SCALE_STEP) * 100]
                                                  action:@selector(scaleUp)
                                           keyEquivalent:@""];
    up.target = self;
    up.enabled = scale < SCALE_MAX;
    [menu addItem:up];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *noteDir = [[NSMenuItem alloc] initWithTitle:@"设置笔记目录…"
                                                       action:@selector(configureNoteDir)
                                                keyEquivalent:@""];
    noteDir.target = self;
    [menu addItem:noteDir];

    NSView *view = [sender isKindOfClass:[NSView class]] ? sender : self;
    [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, view.bounds.size.height) inView:view];
}

- (void)configureNoteDir {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:NO];
    [panel setCanChooseDirectories:YES];
    [panel setCanCreateDirectories:YES];
    [panel setMessage:@"选择 daily note 目录"];
    [panel setDirectoryURL:[NSURL fileURLWithPath:
                            [[NSUserDefaults standardUserDefaults] stringForKey:@"timebox_note_dir"] ?:
                            [@"~/Documents/Notes/Today/" stringByExpandingTildeInPath]]];
    [panel beginWithCompletionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            NSString *path = panel.URL.path;
            [[NSUserDefaults standardUserDefaults] setObject:path forKey:@"timebox_note_dir"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }];
}

- (void)toggleTodo {
    self.todoOpen = !self.todoOpen;
    CGFloat W = self.bounds.size.width;
    if (self.todoOpen) {
        if (!self.todoPanel) {
            self.todoPanel = [[NSView alloc] initWithFrame:NSMakeRect([self L:16], [self L:28], W-[self L:32], [self L:128])];
            self.todoPanel.wantsLayer = YES;
            self.todoPanel.layer.backgroundColor = C_CARD.CGColor;
            self.todoPanel.layer.cornerRadius = [self L:6];
            self.todoPanel.layer.borderWidth = 0.5;
            self.todoPanel.layer.borderColor = C_BORDER.CGColor;
            [self addSubview:self.todoPanel];

            NSScrollView *sv = [[NSScrollView alloc] initWithFrame:NSMakeRect([self L:4], [self L:4], W-[self L:40], [self L:120])];
            self.todoTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, W-[self L:44], [self L:120])];
            [self.todoTextView setFont:[NSFont systemFontOfSize:[self L:12]]];
            [self.todoTextView setTextColor:C_TEXT];
            [self.todoTextView setBackgroundColor:[NSColor clearColor]];
            [self.todoTextView setDrawsBackground:NO];
            [self.todoTextView setDelegate:self];
            [self.todoTextView setRichText:NO];
            [sv setDocumentView:self.todoTextView];
            [sv setHasVerticalScroller:YES];
            [sv setBorderType:NSNoBorder];
            [sv setDrawsBackground:NO];
            [self.todoPanel addSubview:sv];

            NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:@"timebox_todo_text"];
            if (saved) [self.todoTextView setString:saved];
        }
        self.todoPanel.hidden = NO;
        [self.todoBtn setTitle:@"✕"];
        self.todoBtn.layer.backgroundColor = C_WARN.CGColor;
    } else {
        if (self.todoTextView) {
            NSString *text = [self.todoTextView.string copy];
            [[NSUserDefaults standardUserDefaults] setObject:text forKey:@"timebox_todo_text"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        self.todoPanel.hidden = YES;
        [self.todoBtn setTitle:@"📋"];
        NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:@"timebox_todo_text"];
        self.todoBtn.layer.backgroundColor = (saved.length > 0) ? C_ACCENT.CGColor : [NSColor colorWithWhite:0.82 alpha:0.5].CGColor;
    }
}

- (BOOL)textView:(NSTextView *)tv doCommandBySelector:(SEL)selector {
    if (tv == self.todoTextView && selector == @selector(insertNewlineIgnoringFieldEditor:)) {
        [self useTodoFromTextView];
        return YES;
    }
    return NO;
}

- (void)useTodoFromTextView {
    if (!self.todoTextView) return;
    NSString *text = self.todoTextView.string;
    NSRange sel = [self.todoTextView selectedRange];
    NSMutableArray *lines = [[text componentsSeparatedByString:@"\n"] mutableCopy];
    NSUInteger pos = 0;
    NSInteger targetLine = -1;
    for (NSInteger i = 0; i < (NSInteger)lines.count; i++) {
        NSString *line = lines[i];
        NSUInteger lineLen = line.length + 1;
        if (sel.location >= pos && sel.location < pos + lineLen) {
            NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (trimmed.length > 0) {
                self.taskField.stringValue = trimmed;
                [self fieldChanged];
                targetLine = i;
            }
            break;
        }
        pos += lineLen;
    }
    if (targetLine >= 0) {
        [lines removeObjectAtIndex:targetLine];
        if (targetLine < (NSInteger)lines.count && [lines[targetLine] isEqualToString:@""])
            [lines removeObjectAtIndex:targetLine];
        NSString *newText = [lines componentsJoinedByString:@"\n"];
        self.todoTextView.string = newText;
        [[NSUserDefaults standardUserDefaults] setObject:newText forKey:@"timebox_todo_text"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

@end

// ─── App Delegate ────────────────────────────────────────
@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (strong) NSWindow *window;
@end

@implementation AppDelegate
- (void)installApplicationMenu {
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@""];

    NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [mainMenu addItem:appMenuItem];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"TimeBox"];
    [appMenu addItemWithTitle:@"Quit TimeBox" action:@selector(terminate:) keyEquivalent:@"q"];
    [appMenuItem setSubmenu:appMenu];

    NSMenuItem *editMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [mainMenu addItem:editMenuItem];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];

    NSMenuItem *cutItem = [[NSMenuItem alloc] initWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [cutItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
    [editMenu addItem:cutItem];
    NSMenuItem *copyItem = [[NSMenuItem alloc] initWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [copyItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
    [editMenu addItem:copyItem];
    NSMenuItem *pasteItem = [[NSMenuItem alloc] initWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [pasteItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
    [editMenu addItem:pasteItem];

    [editMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *ctrlCutItem = [[NSMenuItem alloc] initWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [ctrlCutItem setKeyEquivalentModifierMask:NSEventModifierFlagControl];
    [editMenu addItem:ctrlCutItem];
    NSMenuItem *ctrlCopyItem = [[NSMenuItem alloc] initWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [ctrlCopyItem setKeyEquivalentModifierMask:NSEventModifierFlagControl];
    [editMenu addItem:ctrlCopyItem];
    NSMenuItem *ctrlPasteItem = [[NSMenuItem alloc] initWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [ctrlPasteItem setKeyEquivalentModifierMask:NSEventModifierFlagControl];
    [editMenu addItem:ctrlPasteItem];

    [editMenuItem setSubmenu:editMenu];
    [NSApp setMainMenu:mainMenu];
}

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    [self installApplicationMenu];

    NSScreen *screen = [NSScreen mainScreen];
    CGFloat sw = screen.visibleFrame.size.width;
    CGFloat sh = screen.visibleFrame.size.height;

    CGFloat scale = TimeBoxScale();
    NSRect rect = NSMakeRect(0, 0, BASE_W * scale, BASE_H * scale);
    self.window = [[NSWindow alloc] initWithContentRect:rect
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|
                NSWindowStyleMaskMiniaturizable
        backing:NSBackingStoreBuffered defer:NO];

    [self.window setTitle:@"TimeBox"];
    [self.window setTitleVisibility:NSWindowTitleHidden];
    [self.window setTitlebarAppearsTransparent:YES];
    [self.window setBackgroundColor:C_BG];
    [self.window setLevel:NSFloatingWindowLevel];
    [self.window setOpaque:YES];
    [self.window setMovableByWindowBackground:YES];
    [self.window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
    [self.window setRestorable:NO];
    [self.window center];

    TimeBoxView *view = [[TimeBoxView alloc] initWithFrame:NSMakeRect(0, 0, BASE_W * scale, BASE_H * scale)];
    [self.window setContentView:view];
    ApplyTitlebarScale(self.window, scale);

    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}
@end

int main() {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app setDelegate:[[AppDelegate alloc] init]];
        [app run];
    }
    return 0;
}
