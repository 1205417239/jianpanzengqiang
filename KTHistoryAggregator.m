#import "KTHistoryAggregator.h"
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>

static NSString * const KTAStore = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.aggregate.plist";
static NSString * const KTALock = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.aggregate.lock";

static NSArray *KTALoad(void) {
    NSArray *a = [NSArray arrayWithContentsOfFile:KTAStore];
    return [a isKindOfClass:NSArray.class] ? a : @[];
}

static void KTAWrite(NSArray *a) {
    [a writeToFile:KTAStore atomically:YES];
}

static int KTALockFD(void) {
    return open(KTALock.UTF8String, O_CREAT | O_RDWR, 0600);
}

static NSString *KTAKey(NSDictionary *d) {
    return [NSString stringWithFormat:@"%.6f|%@|%@",
            [d[@"timestamp"] doubleValue],
            d[@"bundle"] ?: @"",
            d[@"text"] ?: @""];
}

@implementation KTHistoryAggregator

+ (void)mergeItems:(NSArray<KTClipboardItem *> *)items {
    if (!items.count) return;

    int fd = KTALockFD();
    if (fd < 0) return;
    flock(fd, LOCK_EX);

    NSMutableArray *all = [KTALoad() mutableCopy];
    NSMutableSet *keys = [NSMutableSet setWithCapacity:all.count];
    for (NSDictionary *d in all) {
        if ([d isKindOfClass:NSDictionary.class]) [keys addObject:KTAKey(d)];
    }

    for (KTClipboardItem *item in items) {
        if (!item.text.length) continue;
        NSDictionary *d = [item dictionary];
        NSString *key = KTAKey(d);
        if ([keys containsObject:key]) continue;
        [keys addObject:key];
        [all addObject:d];
    }

    [all sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        NSTimeInterval ta = [a[@"timestamp"] doubleValue];
        NSTimeInterval tb = [b[@"timestamp"] doubleValue];
        if (ta > tb) return NSOrderedAscending;
        if (ta < tb) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    NSUInteger limit = KTHistoryLimit();
    while (all.count > limit) [all removeLastObject];
    KTAWrite(all);

    flock(fd, LOCK_UN);
    close(fd);
}

+ (NSArray<KTClipboardItem *> *)items {
    int fd = KTALockFD();
    if (fd < 0) return @[];
    flock(fd, LOCK_SH);

    NSArray *saved = KTALoad();
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:saved.count];
    for (NSDictionary *d in saved) {
        if ([d isKindOfClass:NSDictionary.class]) {
            [result addObject:[KTClipboardItem itemWithDictionary:d]];
        }
    }

    flock(fd, LOCK_UN);
    close(fd);
    return result;
}

+ (NSArray<KTClipboardItem *> *)favorites {
    NSMutableArray *result = [NSMutableArray array];
    for (KTClipboardItem *item in self.items) {
        if (item.favorite) [result addObject:item];
    }
    return result;
}

%hook KTClipboardManager
- (void)save {
    %orig;
    [KTHistoryAggregator mergeItems:[self items]];
}
%end

@end
