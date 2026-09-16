#import "KTClipboardManager.h"
#import "KTSettings.h"
#import <sqlite3.h>

static NSString * const KTHistoryDBPath = @"/var/mobile/Library/.KeyboardToolsKayoko/history.sqlite3";
static NSString * const KTLastPasteboard = @"KTLastPasteboard";

@implementation KTClipboardItem
- (NSDictionary *)dictionary {
    return @{ @"id": @(self.rowID), @"text": self.text ?: @"", @"bundle": self.bundleIdentifier ?: @"", @"app": self.appName ?: @"", @"timestamp": @((self.recordedAt ?: NSDate.date).timeIntervalSince1970), @"favorite": @(self.favorite) };
}
+ (instancetype)itemWithDictionary:(NSDictionary *)d {
    KTClipboardItem *i=[KTClipboardItem new];
    i.rowID=[d[@"id"] integerValue];
    i.text=[d[@"text"] isKindOfClass:NSString.class] ? d[@"text"] : @"";
    i.bundleIdentifier=[d[@"bundle"] isKindOfClass:NSString.class] ? d[@"bundle"] : @"";
    i.appName=[d[@"app"] isKindOfClass:NSString.class] ? d[@"app"] : @"";
    NSNumber *ts=[d[@"timestamp"] isKindOfClass:NSNumber.class] ? d[@"timestamp"] : nil;
    i.recordedAt=ts ? [NSDate dateWithTimeIntervalSince1970:ts.doubleValue] : NSDate.date;
    i.favorite=[d[@"favorite"] boolValue];
    return i;
}
@end

@interface KTClipboardManager ()
@property(nonatomic,strong) NSMutableArray<KTClipboardItem *> *mutableItems;
@property(nonatomic,copy) NSString *lastString;
@end

@implementation KTClipboardManager
+ (instancetype)sharedManager { static KTClipboardManager *m; static dispatch_once_t once; dispatch_once(&once, ^{ m=[self new]; }); return m; }

- (instancetype)init {
    if ((self=[super init])) {
        _mutableItems=[NSMutableArray array];
        [self setupDatabase];
        [self reloadCache];
    }
    return self;
}

- (void)setupDatabase {
    NSString *dir=[KTHistoryDBPath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    sqlite3 *db=NULL;
    if (sqlite3_open_v2(KTHistoryDBPath.fileSystemRepresentation,&db,SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE,NULL)!=SQLITE_OK) { if(db) sqlite3_close(db); return; }
    sqlite3_busy_timeout(db,5000);
    sqlite3_exec(db,"PRAGMA journal_mode=WAL;",NULL,NULL,NULL);
    sqlite3_exec(db,"CREATE TABLE IF NOT EXISTS history (id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL, bundle TEXT NOT NULL DEFAULT '', app TEXT NOT NULL DEFAULT '', timestamp REAL NOT NULL, favorite INTEGER NOT NULL DEFAULT 0);",NULL,NULL,NULL);
    sqlite3_close(db);
}

- (void)reloadCache {
    NSArray *fresh=[self readItems:NO];
    self.mutableItems=[fresh mutableCopy] ?: [NSMutableArray array];
}

- (NSArray *)readItems:(BOOL)favoritesOnly {
    sqlite3 *db=NULL;
    if (sqlite3_open_v2(KTHistoryDBPath.fileSystemRepresentation,&db,SQLITE_OPEN_READONLY,NULL)!=SQLITE_OK) { if(db) sqlite3_close(db); return @[]; }
    sqlite3_busy_timeout(db,5000);
    const char *sql=favoritesOnly ? "SELECT id,text,bundle,app,timestamp,favorite FROM history WHERE favorite=1 ORDER BY id DESC;" : "SELECT id,text,bundle,app,timestamp,favorite FROM history ORDER BY id DESC;";
    sqlite3_stmt *stmt=NULL;
    NSMutableArray *result=[NSMutableArray array];
    if (sqlite3_prepare_v2(db,sql,-1,&stmt,NULL)==SQLITE_OK) {
        while (sqlite3_step(stmt)==SQLITE_ROW) {
            KTClipboardItem *i=[KTClipboardItem new];
            i.rowID=sqlite3_column_int64(stmt,0);
            const unsigned char *text=sqlite3_column_text(stmt,1);
            const unsigned char *bundle=sqlite3_column_text(stmt,2);
            const unsigned char *app=sqlite3_column_text(stmt,3);
            i.text=text ? [NSString stringWithUTF8String:(const char *)text] : @"";
            i.bundleIdentifier=bundle ? [NSString stringWithUTF8String:(const char *)bundle] : @"";
            i.appName=app ? [NSString stringWithUTF8String:(const char *)app] : @"";
            i.recordedAt=[NSDate dateWithTimeIntervalSince1970:sqlite3_column_double(stmt,4)];
            i.favorite=sqlite3_column_int(stmt,5)!=0;
            [result addObject:i];
        }
        sqlite3_finalize(stmt);
    }
    sqlite3_close(db);
    return result;
}

- (void)startMonitoring {
    if (KTEnabled() && KTRecordClipboard()) [self addCurrentClipboard];
}

- (void)addCurrentClipboard {
    if (!KTEnabled() || !KTRecordClipboard()) return;
    UIPasteboard *pb=UIPasteboard.generalPasteboard;
    NSString *s=pb.string;
    if (s.length) {
        NSString *last=[[NSUserDefaults standardUserDefaults] stringForKey:KTLastPasteboard];
        if (![last isEqualToString:s]) {
            [[NSUserDefaults standardUserDefaults] setObject:s forKey:KTLastPasteboard];
            NSString *bid=NSBundle.mainBundle.bundleIdentifier ?: @"";
            NSString *name=NSBundle.mainBundle.localizedInfoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleName"] ?: bid;
            [self addText:s bundleIdentifier:bid appName:name];
        }
    }
}

- (void)addText:(NSString *)text bundleIdentifier:(NSString *)bid appName:(NSString *)name {
    if (!text.length) return;
    sqlite3 *db=NULL;
    if (sqlite3_open_v2(KTHistoryDBPath.fileSystemRepresentation,&db,SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE,NULL)!=SQLITE_OK) { if(db) sqlite3_close(db); return; }
    sqlite3_busy_timeout(db,5000);
    sqlite3_exec(db,"BEGIN IMMEDIATE;",NULL,NULL,NULL);
    sqlite3_stmt *stmt=NULL;
    if (sqlite3_prepare_v2(db,"INSERT INTO history(text,bundle,app,timestamp,favorite) VALUES(?,?,?,?,0);",-1,&stmt,NULL)==SQLITE_OK) {
        sqlite3_bind_text(stmt,1,text.UTF8String,-1,SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt,2,(bid ?: @"").UTF8String,-1,SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt,3,(name ?: @"").UTF8String,-1,SQLITE_TRANSIENT);
        sqlite3_bind_double(stmt,4,NSDate.date.timeIntervalSince1970);
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }
    sqlite3_exec(db,"COMMIT;",NULL,NULL,NULL);
    sqlite3_exec(db,"DELETE FROM history WHERE favorite=0 AND id NOT IN (SELECT id FROM history WHERE favorite=0 ORDER BY id DESC LIMIT 50);",NULL,NULL,NULL);
    sqlite3_close(db);
    [self reloadCache];
}

- (NSArray *)items {
    if (KTEnabled() && KTRecordClipboard()) [self addCurrentClipboard];
    NSArray *fresh=[self readItems:NO];
    self.mutableItems=[fresh mutableCopy] ?: [NSMutableArray array];
    return fresh;
}

- (NSArray *)favorites { return [self readItems:YES]; }

- (void)setFavorite:(BOOL)favorite forItem:(KTClipboardItem *)item {
    if (!item || item.rowID<=0) return;
    sqlite3 *db=NULL;
    if (sqlite3_open_v2(KTHistoryDBPath.fileSystemRepresentation,&db,SQLITE_OPEN_READWRITE,NULL)!=SQLITE_OK) { if(db) sqlite3_close(db); return; }
    sqlite3_busy_timeout(db,5000);
    sqlite3_stmt *stmt=NULL;
    if (sqlite3_prepare_v2(db,"UPDATE history SET favorite=? WHERE id=?;",-1,&stmt,NULL)==SQLITE_OK) {
        sqlite3_bind_int(stmt,1,favorite?1:0);
        sqlite3_bind_int64(stmt,2,item.rowID);
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }
    sqlite3_close(db);
    [self reloadCache];
}

- (void)removeItem:(KTClipboardItem *)item {
    if (!item || item.rowID<=0) return;
    sqlite3 *db=NULL;
    if (sqlite3_open_v2(KTHistoryDBPath.fileSystemRepresentation,&db,SQLITE_OPEN_READWRITE,NULL)!=SQLITE_OK) { if(db) sqlite3_close(db); return; }
    sqlite3_busy_timeout(db,5000);
    sqlite3_stmt *stmt=NULL;
    if (sqlite3_prepare_v2(db,"DELETE FROM history WHERE id=?;",-1,&stmt,NULL)==SQLITE_OK) {
        sqlite3_bind_int64(stmt,1,item.rowID);
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }
    sqlite3_close(db);
    [self reloadCache];
}

- (void)clearClipboardHistory {
    sqlite3 *db=NULL;
    if (sqlite3_open_v2(KTHistoryDBPath.fileSystemRepresentation,&db,SQLITE_OPEN_READWRITE,NULL)!=SQLITE_OK) { if(db) sqlite3_close(db); return; }
    sqlite3_busy_timeout(db,5000);
    sqlite3_exec(db,"DELETE FROM history WHERE favorite=0;",NULL,NULL,NULL);
    sqlite3_close(db);
    [self reloadCache];
}

- (void)clearImages { UIPasteboard *pb=UIPasteboard.generalPasteboard; if (pb.hasImages) pb.items=@[]; }

- (void)pasteItem:(KTClipboardItem *)item intoInput:(id<UITextInput>)input {
    if (!item.text.length || !input) return;
    UITextRange *r=input.selectedTextRange;
    if (r) [input replaceRange:r withText:item.text];
}
@end
