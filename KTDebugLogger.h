#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif
void KTDebugLog(NSString *format, ...);
NSString *KTDebugLogText(void);
void KTDebugLogClear(void);
#ifdef __cplusplus
}
#endif
