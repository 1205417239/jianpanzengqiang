#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <notify.h>
static NSString * const KTChanged=@"com.keyboardtoolskayoko.pasteboard.changed";
int main(int argc,char**argv){@autoreleasepool{int token=0;notify_register_dispatch("com.apple.pasteboard.notify.changed",&token,dispatch_get_main_queue(),^(int _){CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),(CFStringRef)KTChanged,NULL,NULL,YES);});[[NSRunLoop currentRunLoop]run];notify_cancel(token);}return 0;}
