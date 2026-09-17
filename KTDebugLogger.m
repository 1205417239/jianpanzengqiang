#import <unistd.h>
#import "KTDebugLogger.h"

static NSString * const KTDebugLogPath = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.runtime.log";

void KTDebugLog(NSString *format, ...) {
    if (!format) return;
    va_list args;
    va_start(args, format);
    NSString *body=[[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    if (!body.length) return;
    NSString *line=[NSString stringWithFormat:@"%@ pid=%d %@\n", [[NSDate date] descriptionWithLocale:nil], getpid(), body];
    NSFileManager *fm=NSFileManager.defaultManager;
    [fm createFileAtPath:KTDebugLogPath contents:nil attributes:nil];
    @try {
        NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:KTDebugLogPath];
        [h seekToEndOfFile];
        [h writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [h closeFile];
    } @catch (__unused NSException *e) { return; }
    NSDictionary *a=[fm attributesOfItemAtPath:KTDebugLogPath error:nil];
    if ([a[NSFileSize] unsignedLongLongValue] > 24000) {
        NSString *all=[NSString stringWithContentsOfFile:KTDebugLogPath encoding:NSUTF8StringEncoding error:nil] ?: @"";
        NSArray *rows=[all componentsSeparatedByString:@"\n"];
        NSUInteger start=rows.count>120 ? rows.count-120 : 0;
        NSString *trim=[[rows subarrayWithRange:NSMakeRange(start, rows.count-start)] componentsJoinedByString:@"\n"];
        [trim writeToFile:KTDebugLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

NSString *KTDebugLogText(void) {
    NSString *s=[NSString stringWithContentsOfFile:KTDebugLogPath encoding:NSUTF8StringEncoding error:nil];
    return s.length ? s : @"暂无插件运行记录";
}

void KTDebugLogClear(void) {
    [[NSFileManager defaultManager] removeItemAtPath:KTDebugLogPath error:nil];
}
