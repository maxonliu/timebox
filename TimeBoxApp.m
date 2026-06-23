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

// ─── Daily note path — helper ────────────────────────────
// Configurable via NOTE_DIR environment variable.
// Default: /Users/lw/Documents/Notes/Wayne/Today/
static NSString *NotePath(void) {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSInteger y = [cal component:NSCalendarUnitYear fromDate:[NSDate date]];
    NSInteger m = [cal component:NSCalendarUnitMonth fromDate:[NSDate date]];

    char *env = getenv("NOTE_DIR");
    NSString *dir;
    if (env && strlen(env) > 0) {
        dir = [NSString stringWithUTF8String:env];
    } else {
        dir = @"/Users/lw/Documents/Notes/Wayne/Today/";
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

- (void)buildUI {
    CGFloat W = self.bounds.size.width;
    CGFloat Y = self.bounds.size.height;

    // ── Timer display ──
    self.timerField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, Y-90, W, 80)];
    [self.timerField setFont:[NSFont monospacedDigitSystemFontOfSize:72 weight:NSFontWeightThin]];
    [self.timerField setTextColor:C_ACCENT];
    [self.timerField setAlignment:NSTextAlignmentCenter];
    [self.timerField setStringValue:@"10:00"];
    [self.timerField setBezeled:NO];
    [self.timerField setEditable:NO];
    [self.timerField setBackgroundColor:[NSColor clearColor]];
    [self addSubview:self.timerField];

    // ── Block info ──
    self.blockField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, Y-115, W, 22)];
    [self.blockField setFont:[NSFont systemFontOfSize:12 weight:NSFontWeightMedium]];
    [self.blockField setTextColor:C_DIM];
    [self.blockField setAlignment:NSTextAlignmentCenter];
    [self.blockField setStringValue:@"—"];
    [self.blockField setBezeled:NO];
    [self.blockField setEditable:NO];
    [self.blockField setBackgroundColor:[NSColor clearColor]];
    [self addSubview:self.blockField];
    [self updateBlockText];

    // ── Intention ──
    self.intentField = [[NSTextField alloc] initWithFrame:NSMakeRect(16, Y-168, W-32, 22)];
    [self.intentField setFont:[NSFont systemFontOfSize:13 weight:NSFontWeightMedium]];
    [self.intentField setTextColor:C_DIM];
    [self.intentField setStringValue:@"✏️ 写下这个10分钟的任务"];
    [self.intentField setAlignment:NSTextAlignmentCenter];
    [self.intentField setBezeled:NO];
    [self.intentField setEditable:NO];
    [self.intentField setBackgroundColor:[NSColor clearColor]];
    [self addSubview:self.intentField];

    // ── Task input ──
    self.taskField = [[NSTextField alloc] initWithFrame:NSMakeRect(16, Y-206, 200, 34)];
    [self.taskField setPlaceholderString:@"要做什么？"];
    [self.taskField setFont:[NSFont systemFontOfSize:14]];
    [self.taskField setTextColor:C_TEXT];
    [self.taskField setBackgroundColor:C_CARD];
    [self.taskField setBezeled:YES];
    [self.taskField setBordered:YES];
    [self.taskField setBezelStyle:NSTextFieldSquareBezel];
    [self.taskField setDelegate:self];
    [self addSubview:self.taskField];

    // ── Todo button ──
    self.todoBtn = [[NSButton alloc] initWithFrame:NSMakeRect(W-116, Y-208, 36, 36)];
    [self.todoBtn setBordered:NO];
    [self.todoBtn setTarget:self];
    [self.todoBtn setAction:@selector(toggleTodo)];
    self.todoBtn.wantsLayer = YES;
    self.todoBtn.layer.backgroundColor = [NSColor colorWithWhite:0.82 alpha:0.5].CGColor;
    self.todoBtn.layer.cornerRadius = 8;
    [self.todoBtn setTitle:@"📋"];
    [self.todoBtn setFont:[NSFont systemFontOfSize:16]];
    [self addSubview:self.todoBtn];

    // ── Punch button ──
    self.punchBtn = [[NSButton alloc] initWithFrame:NSMakeRect(W-66, Y-208, 50, 36)];
    [self.punchBtn setBordered:NO];
    [self.punchBtn setTarget:self];
    [self.punchBtn setAction:@selector(punchIn)];
    self.punchBtn.wantsLayer = YES;
    self.punchBtn.layer.backgroundColor = C_GREEN.CGColor;
    self.punchBtn.layer.cornerRadius = 8;

    // Use system checkmark icon (SF Symbols, macOS 11+)
    if (@available(macOS 11.0, *)) {
        NSImage *checkSymbol = [NSImage imageWithSystemSymbolName:@"checkmark"
                                            accessibilityDescription:nil];
        [self.punchBtn setImage:checkSymbol];
        [self.punchBtn setImagePosition:NSImageOnly];
        [self.punchBtn setContentTintColor:[NSColor whiteColor]];
    } else {
        [self.punchBtn setTitle:@"✓"];
        [self.punchBtn setFont:[NSFont systemFontOfSize:20 weight:NSFontWeightBold]];
    }
    [self addSubview:self.punchBtn];

    // ── Control buttons ──
    self.pauseBtn = [[NSButton alloc] initWithFrame:NSMakeRect(16, Y-250, 90, 28)];
    [self.pauseBtn setTitle:@"⏸ 暂停"];
    [self.pauseBtn setFont:[NSFont systemFontOfSize:12]];
    [self.pauseBtn setBezelStyle:NSBezelStyleTexturedRounded];
    [self.pauseBtn setTarget:self];
    [self.pauseBtn setAction:@selector(togglePause)];
    [self addSubview:self.pauseBtn];

    NSButton *skip = [[NSButton alloc] initWithFrame:NSMakeRect(112, Y-250, 72, 28)];
    [skip setTitle:@"⏭ 跳过"];
    [skip setFont:[NSFont systemFontOfSize:12]];
    [skip setBezelStyle:NSBezelStyleTexturedRounded];
    [skip setTarget:self];
    [skip setAction:@selector(skipBlock)];
    [self addSubview:skip];

    NSButton *reset = [[NSButton alloc] initWithFrame:NSMakeRect(190, Y-250, 72, 28)];
    [reset setTitle:@"⟳ 重置"];
    [reset setFont:[NSFont systemFontOfSize:12]];
    [reset setBezelStyle:NSBezelStyleTexturedRounded];
    [reset setTarget:self];
    [reset setAction:@selector(resetAll)];
    [self addSubview:reset];

    // ── Log table ──
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"c"];
    col.width = W - 36;
    col.minWidth = W - 36;

    NSTableView *tv = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, W-36, 100)];
    [tv addTableColumn:col];
    [tv setHeaderView:nil];
    [tv setBackgroundColor:[NSColor clearColor]];
    [tv setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
    [tv setRowHeight:24];
    [tv setIntercellSpacing:NSMakeSize(0, 2)];
    tv.delegate = self;
    tv.dataSource = self;
    self.logTable = tv;

    NSScrollView *sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(16, 4, W-32, 130)];
    [sv setDocumentView:tv];
    [sv setHasVerticalScroller:YES];
    [sv setBorderType:NSNoBorder];
    [sv setDrawsBackground:NO];
    [sv setBackgroundColor:[NSColor clearColor]];
    [self addSubview:sv];
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
    if (self.remaining <= 0) {
        self.remaining = 0;
        [self autoPunch];
        [self nextBlock];
    }
    [self updateDisplay];
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
    NSRect bg = NSMakeRect(16, Y-126, W-32, 4);
    [C_PROGRESS setFill];
    [[NSBezierPath bezierPathWithRoundedRect:bg xRadius:2 yRadius:2] fill];

    // Progress fill
    double pct = (600.0 - self.remaining) / 600.0;
    if (pct > 0) {
        NSRect fg = NSMakeRect(16, Y-126, (W-32)*pct, 4);
        [(self.remaining < 180 ? C_WARN : C_ACCENT) setFill];
        [[NSBezierPath bezierPathWithRoundedRect:fg xRadius:2 yRadius:2] fill];
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
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(6, 1, tv.bounds.size.width-12, 22)];
    [label setStringValue:[NSString stringWithFormat:@"🎯 %@  · %@", e.task, e.time]];
    [label setFont:[NSFont systemFontOfSize:12]];
    [label setTextColor:C_TEXT];
    [label setBezeled:NO];
    [label setEditable:NO];
    [label setBackgroundColor:[NSColor clearColor]];
    return label;
}

// ─── 📋 Todo ──────────────────────────────────────────────
- (void)toggleTodo {
    self.todoOpen = !self.todoOpen;
    CGFloat W = self.bounds.size.width;
    if (self.todoOpen) {
        if (!self.todoPanel) {
            self.todoPanel = [[NSView alloc] initWithFrame:NSMakeRect(16, 28, W-32, 128)];
            self.todoPanel.wantsLayer = YES;
            self.todoPanel.layer.backgroundColor = C_CARD.CGColor;
            self.todoPanel.layer.cornerRadius = 6;
            self.todoPanel.layer.borderWidth = 0.5;
            self.todoPanel.layer.borderColor = C_BORDER.CGColor;
            [self addSubview:self.todoPanel];

            NSScrollView *sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(4, 4, W-40, 120)];
            self.todoTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, W-44, 120)];
            [self.todoTextView setFont:[NSFont systemFontOfSize:12]];
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
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    NSScreen *screen = [NSScreen mainScreen];
    CGFloat sw = screen.visibleFrame.size.width;
    CGFloat sh = screen.visibleFrame.size.height;

    NSRect rect = NSMakeRect(0, 0, 340, 380);
    self.window = [[NSWindow alloc] initWithContentRect:rect
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|
                NSWindowStyleMaskMiniaturizable
        backing:NSBackingStoreBuffered defer:NO];

    [self.window setTitle:@"TimeBox"];
    [self.window setBackgroundColor:C_BG];
    [self.window setLevel:NSFloatingWindowLevel];
    [self.window setOpaque:YES];
    [self.window setMovableByWindowBackground:YES];
    [self.window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
    [self.window setRestorable:NO];
    [self.window center];

    TimeBoxView *view = [[TimeBoxView alloc] initWithFrame:NSMakeRect(0, 0, 340, 380)];
    [self.window setContentView:view];

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
