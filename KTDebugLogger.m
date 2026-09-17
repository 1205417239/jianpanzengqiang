#import <UIKit/UIKit.h>
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
    NSString *app=NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleName"] ?: @"";
    NSString *bundle=NSBundle.mainBundle.bundleIdentifier ?: @"";
    NSString *line=[NSString stringWithFormat:@"%@ pid=%d app=%@ bundle=%@ %@\n", [[NSDate date] descriptionWithLocale:nil], getpid(), app, bundle, body];
    NSFileManager *fm=NSFileManager.defaultManager;
    @try {
        NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:KTDebugLogPath];
        if (!h) { [fm createFileAtPath:KTDebugLogPath contents:nil attributes:nil]; h=[NSFileHandle fileHandleForWritingAtPath:KTDebugLogPath]; }
        if (!h) return;
        [h seekToEndOfFile];
        [h writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [h closeFile];
    } @catch (__unused NSException *e) { return; }
    NSDictionary *a=[fm attributesOfItemAtPath:KTDebugLogPath error:nil];
    if ([a[NSFileSize] unsignedLongLongValue] > 24000) {
        NSString *all=[NSString stringWithContentsOfFile:KTDebugLogPath encoding:NSUTF8StringEncoding error:nil] ?: @"";
        NSArray *rows=[all componentsSeparatedByString:@"\n"];
        NSUInteger count=rows.count;
        NSUInteger start=count>160 ? count-160 : 0;
        NSString *trim=[[rows subarrayWithRange:NSMakeRange(start,count-start)] componentsJoinedByString:@"\n"];
        [trim writeToFile:KTDebugLogPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

NSString *KTDebugLogText(void) {
    NSString *s=[NSString stringWithContentsOfFile:KTDebugLogPath encoding:NSUTF8StringEncoding error:nil];
    if (!s.length) return @"暂无插件运行记录";
    NSArray *rows=[s componentsSeparatedByString:@"\n"];
    NSMutableArray *valid=[NSMutableArray array];
    for (NSString *row in rows) if (row.length) [valid addObject:row];
    return valid.count ? [[[valid reverseObjectEnumerator] allObjects] componentsJoinedByString:@"\n"] : @"暂无插件运行记录";
}

void KTDebugLogClear(void) {
    [[NSFileManager defaultManager] removeItemAtPath:KTDebugLogPath error:nil];
}
