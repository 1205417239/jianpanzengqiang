#import "KTKPrefsRootListController.h"
#import <Preferences/PSSpecifier.h>

@implementation KTKPrefsRootListController
- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"键盘增强";
}
@end
