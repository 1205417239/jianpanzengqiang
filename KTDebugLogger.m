#import "KTDebugLogger.h"
static NSString * const KTDebugLogPath = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.debug.log";
void KTDebugLog(NSString *format, ...) {
    if (!format) return;
    va_list args; va_start(args, format);
    NSString *line=[[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    if (!line.length) return;
    NSFileManager *fm=NSFileManager.defaultManager;
    [fm createFileAtPath:KTDebugLogPath contents:nil attributes:nil];
    @try {
        NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:KTDebugLogPath];
        [h seekToEndOfFile];
        NSString *s=[line stringByAppendingString:@"\n"];
        [h writeData:[s dataUsingEncoding:NSUTF8StringEncoding]];
        [h closeFile];
    } @catch (__unused NSException *e) { return; }
    NSDictionary *a=[fm attributesOfItemAtPath:KTDebugLogPath error:nil];
    if ([a[NSFileSize] unsignedLongLongValue] > 12000) {
        NSString *all=[NSString stringWithContentsOfFile:KTDebugLogPath encoding:NSUTF8StringEncoding error:nil] ?: @"";
        NSArray *rows=[all componentsSeparatedByString:@"\n"];
        NSUInteger start=rows.count>80 ? rows.count-80 : 0;
        NSString *trim=[[rows subarrayWithRange:NSMakeRange(start, rows.count-start)] componentsJoinedByString:@"\n"];
        [trim writeToFile:KTDebugLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}
NSString *KTDebugLogText(void) {
    NSString *s=[NSString stringWithContentsOfFile:KTDebugLogPath encoding:NSUTF8StringEncoding error:nil];
    return s.length ? s : @"暂无调试记录";
}
void KTDebugLogClear(void) { [[NSFileManager defaultManager] removeItemAtPath:KTDebugLogPath error:nil]; }
