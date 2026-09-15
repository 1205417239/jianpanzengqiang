#import <Foundation/Foundation.h>

static NSString * const KTPrefsDomain = @"com.keyboardtoolskayoko";

// 统一从 com.keyboardtoolskayoko 偏好域读取，而不是宿主进程自己的 NSUserDefaults 域。
// Root.plist 里每个 PSSwitchCell/PSLinkListCell 的 defaults 都写的是这个域，
// 必须在这里保持一致，否则设置面板的开关不会对 Tweak 的行为产生任何影响。
static inline id KTPrefValue(CFStringRef key) {
    CFPropertyListRef value =
        CFPreferencesCopyAppValue(key, (__bridge CFStringRef)KTPrefsDomain);

    if (!value)
        return nil;

    id result = (__bridge_transfer id)value;
    return result;
}

static inline BOOL KTEnabled(void) {
    NSNumber *v = KTPrefValue(CFSTR("Enabled"));
    return v ? v.boolValue : YES;
}

static inline NSInteger KTHistoryLimit(void) {
    NSNumber *v = KTPrefValue(CFSTR("HistoryLimit"));
    NSInteger n = v ? v.integerValue : 50;
    if (n < 10) n = 10;
    if (n > 100) n = 100;
    return n;
}

static inline BOOL KTRecordClipboard(void) {
    NSNumber *v = KTPrefValue(CFSTR("RecordClipboard"));
    return v ? v.boolValue : YES;
}

static inline BOOL KTShowSource(void) {
    NSNumber *v = KTPrefValue(CFSTR("ShowSource"));
    return v ? v.boolValue : YES;
}
