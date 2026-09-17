#import "KTDebugLogger.h"

static NSString * const KTDebugLogPath = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.debug.log";

void KTDebugLog(NSString *format, ...) {
    if (!format) return;
    va_list args;
    va_start(args, format);
    NSString *line = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    if (!line.length) return;
    NSString *s = [NSString stringWithFormat:@"%@\n", line];
    NSFileHandle *h = [NSFileHandle fileHandleForWritingAtPath:KTDebugLogPath];
    if (!h) {
        [s writeToFile:KTDebugLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        return;
    }
    @try {
        [h seekToEndOfFile];
        [h writeData:[s dataUsingEncoding:NSUTF8StringEncoding]];
        [h closeFile];
    } @catch (__unused NSException *e) {}
    NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:KTDebugLogPath error:nil];
    unsigned long long size = [attr[NSFileSize] unsignedLongLongValue];
    if (size > 24000) {
        NSString *all = [NSString stringWithContentsOfFile:KTDebugLogPath encoding:NSUTF8StringEncoding error:nil] ?: @"";
        NSArray *rows = [all componentsSeparatedByString:@"\n"];
        NSUInteger start = rows.count > 120 ? rows.count - 120 : 0;
        NSString *trim = [[rows subarrayWithRange:NSMakeRange(start, rows.count - start)] componentsJoinedByString:@"\n"];
        [trim writeToFile:KTDebugLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

NSString *KTDebugLogText(void) {
    NSString *s = [NSString stringWithContentsOfFile:KTDebugLogPath encoding:NSUTF8StringEncoding error:nil];
    return s ?: @"暂无调试记录";
}

void KTDebugLogClear(void) {
    [[NSFileManager defaultManager] removeItemAtPath:KTDebugLogPath error:nil];
}
