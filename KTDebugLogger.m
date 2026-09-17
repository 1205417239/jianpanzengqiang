#import "KTDebugLogger.h"
#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>

static NSString * const KTDebugPath = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.debug.log";

void KTDebugLog(NSString *format, ...) {
    if (!format.length) return;
    va_list args;
    va_start(args, format);
    NSString *message=[[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSString *bid=NSBundle.mainBundle.bundleIdentifier ?: @"?";
    NSString *proc=NSProcessInfo.processInfo.processName ?: @"?";
    NSString *line=[NSString stringWithFormat:@"[%@] %@ %@\n", proc, bid, message];
    int fd=open(KTDebugPath.UTF8String, O_RDWR|O_CREAT, 0644);
    if (fd<0) return;
    flock(fd, LOCK_EX);
    NSData *oldData=[NSData dataWithContentsOfFile:KTDebugPath];
    NSString *old=oldData.length ? [[NSString alloc] initWithData:oldData encoding:NSUTF8StringEncoding] : @"";
    NSString *all=[old stringByAppendingString:line];
    NSArray *parts=[all componentsSeparatedByString:@"\n"];
    NSUInteger start=parts.count>121 ? parts.count-121 : 0;
    if (start>0) parts=[parts subarrayWithRange:NSMakeRange(start, parts.count-start)];
    all=[parts componentsJoinedByString:@"\n"];
    ftruncate(fd,0);
    lseek(fd,0,SEEK_SET);
    write(fd,all.UTF8String,strlen(all.UTF8String));
    fsync(fd);
    flock(fd, LOCK_UN);
    close(fd);
}

NSString *KTDebugLogText(void) {
    NSString *s=[NSString stringWithContentsOfFile:KTDebugPath encoding:NSUTF8StringEncoding error:nil];
    return s.length ? s : @"暂无调试日志";
}
