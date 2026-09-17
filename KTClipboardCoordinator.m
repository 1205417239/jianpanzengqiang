#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <math.h>
#import "KTClipboardManager.h"

static NSString * const KTCCStoreKey = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.history.plist";

static NSArray *KTCCRead(void) {
    NSArray *a=[NSArray arrayWithContentsOfFile:KTCCStoreKey];
    return [a isKindOfClass:NSArray.class] ? a : @[];
}

static BOOL KTCCSame(NSDictionary *a, NSDictionary *b) {
    if (![a isKindOfClass:NSDictionary.class] || ![b isKindOfClass:NSDictionary.class]) return NO;
    NSString *ta=a[@"text"], *tb=b[@"text"];
    NSString *ba=a[@"bundle"], *bb=b[@"bundle"];
    NSString *aa=a[@"app"], *ab=b[@"app"];
    NSNumber *xa=a[@"timestamp"], *xb=b[@"timestamp"];
    if (![ta isEqualToString:tb] || ![ba isEqualToString:bb] || ![aa isEqualToString:ab]) return NO;
    if (![xa isKindOfClass:NSNumber.class] || ![xb isKindOfClass:NSNumber.class]) return NO;
    return fabs(xa.doubleValue-xb.doubleValue) < 0.000001;
}

static void KTCCWriteMerged(NSArray *local) {
    NSMutableArray *merged=[NSMutableArray array];
    NSArray *shared=KTCCRead();
    for (NSDictionary *d in shared) if ([d isKindOfClass:NSDictionary.class]) [merged addObject:d];
    for (NSDictionary *d in local) {
        if (![d isKindOfClass:NSDictionary.class]) continue;
        BOOL found=NO;
        for (NSDictionary *old in merged) if (KTCCSame(d,old)) { found=YES; break; }
        if (!found) [merged addObject:d];
    }
    [merged sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        double ta=[a[@"timestamp"] doubleValue];
        double tb=[b[@"timestamp"] doubleValue];
        if (ta>tb) return NSOrderedAscending;
        if (ta<tb) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    NSUInteger limit=200;
    if (merged.count>limit) [merged removeObjectsInRange:NSMakeRange(limit, merged.count-limit)];
    [merged writeToFile:KTCCStoreKey atomically:YES];
}

static void KTCCSave(id self, SEL _cmd) {
    NSArray *items=[self valueForKey:@"mutableItems"];
    NSMutableArray *local=[NSMutableArray array];
    for (id item in items) {
        if ([item respondsToSelector:@selector(dictionary)]) [local addObject:[item dictionary]];
    }
    KTCCWriteMerged(local);
}

__attribute__((constructor)) static void KTCCInstall(void) {
    @autoreleasepool {
        Class cls=objc_getClass("KTClipboardManager");
        if (!cls) return;
        SEL sel=@selector(save);
        Method m=class_getInstanceMethod(cls,sel);
        if (!m) return;
        method_setImplementation(m,(IMP)KTCCSave);
    }
}
