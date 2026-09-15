#import <Foundation/Foundation.h>

static inline BOOL KTEnabled(void) {
    NSNumber *v = [[NSUserDefaults standardUserDefaults] objectForKey:@"Enabled"];
    return v ? v.boolValue : YES;
}

static inline NSInteger KTHistoryLimit(void) {
    NSNumber *v = [[NSUserDefaults standardUserDefaults] objectForKey:@"HistoryLimit"];
    NSInteger n = v ? v.integerValue : 50;
    if (n < 10) n = 10;
    if (n > 100) n = 100;
    return n;
}

static inline BOOL KTRecordClipboard(void) {
    NSNumber *v = [[NSUserDefaults standardUserDefaults] objectForKey:@"RecordClipboard"];
    return v ? v.boolValue : YES;
}

static inline BOOL KTShowSource(void) {
    NSNumber *v = [[NSUserDefaults standardUserDefaults] objectForKey:@"ShowSource"];
    return v ? v.boolValue : YES;
}
