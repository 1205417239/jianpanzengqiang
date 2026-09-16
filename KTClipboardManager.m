#import "KTClipboardManager.h"
#import "KTSettings.h"
#import <sqlite3.h>

static NSString * const KTHistoryDBPath = @"/var/mobile/Library/.KeyboardToolsKayoko/history.sqlite3";
static NSString * const KTLegacyStoreKey = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.history.plist";
static NSString * const KTLastPasteboardChange = @"KTLastPasteboardChangeCount";

@implementation KTClipboardItem
- (NSDictionary *)dictionary {
    return @{
        @"id": @(self.rowID),
        @"text": self.text ?: @"",
        @"bundle": self.bundleIdentifier ?: @"",
        @"app": self.appName ?: @"",
        @"timestamp": @((self.recordedAt ?: NSDate.date).timeIntervalSince1970),
        @"favorite": @(self.favorite)
    };
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
@end

@implementation KTClipboardManager
+ (instancetype)sharedManager { static KTClipboardManager *m; static dispatch_once_t once; dispatch_once(&once, ^{ m=[self new]; }); return m; }

- (instancetype)init {
    if ((self=[super init])) {
        _mutableItems=[NSMutableArray array];
        [self setupDatabase];
        [self reloadCache];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pasteboardChanged:) name:UIPasteboardChangedNotification object:UIPasteboard.generalPasteboard];
    }
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)setupDatabase {
    NSString *dir=[KTHistoryDBPath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    sqlite3 *db=NULL;
    if (sqlite3_open(KTHistoryDBPath.fileSystemRepresentation, &db)!=SQLITE_OK) { if (db) sqlite3_close(db); return; }
    sqlite3_exec(db, "PRAGMA journal_mode=WAL;", NULL, NULL, NULL);
    sqlite3_exec(db, "PRAGMA busy_timeout=3000;", NULL, NULL, NULL);
    sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS history (id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL, bundle TEXT NOT NULL DEFAULT '', app TEXT NOT NULL DEFAULT '', timestamp REAL NOT NULL, favorite INTEGER NOT NULL DEFAULT 0);", NULL, NULL, NULL);
    sqlite3_stmt *stmt=NULL;
    BOOL empty=YES;
    if (sqlite3_prepare_v2(db, "SELECT 1 FROM history LIMIT 1;", -1, &stmt, NULL)==SQLITE_OK) empty=(sqlite3_step(stmt)!=SQLITE_ROW);
    if (stmt) sqlite3_finalize(stmt);
    if (empty) {
        NSArray *saved=[NSArray arrayWithContentsOfFile:KTLegacyStoreKey];
        if ([saved isKindOfClass:NSArray.class] && saved.count) {
            sqlite3_exec(db, "BEGIN IMMEDIATE;", NULL, NULL, NULL);
            sqlite3_stmt *ins=NULL;
            if (sqlite3_prepare_v2(db, "INSERT INTO history(text,bundle,app,timestamp,favorite) VALUES(?,?,?,?,?);", -1, &ins, NULL)==SQLITE_OK) {
                for (NSDictionary *d in saved) {
                    if (![d isKindOfClass:NSDictionary.class]) continue;
                    NSString *text=[d[@"text"] isKindOfClass:NSString.class] ? d[@"text"] : @"";
                    if (!text.length) continue;
                    NSString *bundle=[d[@"bundle"] isKindOfClass:NSString.class] ? d[@"bundle"] : @"";
                    NSString *app=[d[@"app"] isKindOfClass:NSString.class] ? d[@"app"] : @"";
                    double ts=[d[@"timestamp"] respondsToSelector:@selector(doubleValue)] ? [d[@"timestamp"] doubleValue] : NSDate.date.timeIntervalSince1970;
                    int fav=[d[@"favorite"] boolValue] ? 1 : 0;
                    sqlite3_bind_text(ins,1,text.UTF8String,-1,SQLITE_TRANSIENT);
                    sqlite3_bind_text(ins,2,bundle.UTF8String,-1,SQLITE_TRANSIENT);
                    sqlite3_bind_text(ins,3,app.UTF8String,-1,SQLITE_TRANSIENT);
                    sqlite3_bind_double(ins,4,ts);
                    sqlite3_bind_int(ins,5,fav);
                    sqlite3_step(ins);
                    sqlite3_reset(ins);
                    sqlite3_clear_bindings(ins);
                }
                sqlite3_finalize(ins);
            }
            sqlite3_exec(db, "COMMIT;", NULL, NULL, NULL);
        }
    }
    sqlite3_close(db);
}

- (void)reloadCache {
    NSArray *fresh=[self readItems:NO];
    self.mutableItems=[fresh mutableCopy] ?: [NSMutableArray array];
}

- (NSArray *)readItems:(BOOL)favoritesOnly {
    sqlite3 *db=NULL;
    if (sqlite3_open_v2(KTHistoryDBPath.fileSystemRepresentation, &db, SQLITE_OPEN_READONLY, NULL)!=SQLITE_OK) { if (db) sqlite3_close(db); return @[]; }
    sqlite3_busy_timeout(db,3000);
    NSString *sql=favoritesOnly ? @"SELECT id,text,bundle,app,timestamp,favorite FROM history WHERE favorite=1 ORDER BY id DESC;" : @"SELECT id,text,bundle,app,timestamp,favorite FROM history ORDER BY id DESC;";
    sqlite3_stmt *stmt=NULL;
    NSMutableArray *result=[NSMutableArray array];
    if (sqlite3_prepare_v2(db, sql.UTF8String, -1, &stmt, NULL)==SQLITE_OK) {
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
    if (!KTEnabled() || !KTRecordClipboard()) return;
    [self addCurrentClipboard];
}

- (void)pasteboardChanged:(NSNotification *)note {
    if (!KTEnabled() || !KTRecordClipboard()) return;
    UIPasteboard *pb=UIPasteboard.generalPasteboard;
    NSInteger change=pb.changeCount;
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
    NSNumber *last=[defaults objectForKey:KTLastPasteboardChange];
    if (last && last.integerValue == change) return;
    [defaults setObject:@(change) forKey:KTLastPasteboardChange];

    NSString *text=pb.string;
    if (!text.length) return;

    NSString *bid=NSBundle.mainBundle.bundleIdentifier ?: @"";
    NSString *name=NSBundle.mainBundle.localizedInfoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleName"] ?: bid;
    NSDate *recordedAt=NSDate.date;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self addCapturedText:text bundleIdentifier:bid appName:name recordedAt:recordedAt];
    });
}

- (void)addCurrentClipboard {
    if (!KTEnabled() || !KTRecordClipboard()) return;
    UIPasteboard *pb=UIPasteboard.generalPasteboard;
    NSInteger change=pb.changeCount;
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
    NSNumber *last=[defaults objectForKey:KTLastPasteboardChange];
    if (last && last.integerValue == change) return;
    [defaults setObject:@(change) forKey:KTLastPasteboardChange];

    NSString *text=pb.string;
    if (!text.length) return;
    NSString *bid=NSBundle.mainBundle.bundleIdentifier ?: @"";
    NSString *name=NSBundle.mainBundle.localizedInfoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleName"] ?: bid;
    [self addCapturedText:text bundleIdentifier:bid appName:name recordedAt:NSDate.date];
}

- (void)addCapturedText:(NSString *)text bundleIdentifier:(NSString *)bid appName:(NSString *)name recordedAt:(NSDate *)recordedAt {
    if (!text.length) return;
    sqlite3 *db=NULL;
    if (sqlite3_open_v2(KTHistoryDBPath.fileSystemRepresentation, &db, SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE, NULL)!=SQLITE_OK) { if (db) sqlite3_close(db); return; }
    sqlite3_busy_timeout(db,3000);
    sqlite3_exec(db, "PRAGMA journal_mode=WAL;", NULL, NULL, NULL);
    sqlite3_stmt *stmt=NULL;
    if (sqlite3_prepare_v2(db, "INSERT INTO history(text,bundle,app,timestamp,favorite) VALUES(?,?,?,?,0);", -1, &stmt, NULL)==SQLITE_OK) {
        sqlite3_bind_text(stmt,1,text.UTF8String,-1,SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt,2,(bid ?: @"").UTF8String,-1,SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt,3,(name ?: @"").UTF8String,-1,SQLITE_TRANSIENT);
        sqlite3_bind_double(stmt,4,(recordedAt ?: NSDate.date).timeIntervalSince1970);
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }
    sqlite3_exec(db, "DELETE FROM history WHERE favorite=0 AND id NOT IN (SELECT id FROM history WHERE favorite=0 ORDER BY id DESC LIMIT 50);", NULL, NULL, NULL);
    sqlite3_close(db);
    [self reloadCache];
}

- (void)addText:(NSString *)text bundleIdentifier:(NSString *)bid appName:(NSString *)name {
    [self addCapturedText:text bundleIdentifier:bid appName:name recordedAt:NSDate.date];
}

- (NSArray *)items {
    if (KTEnabled() && KTRecordClipboard()) [self addCurrentClipboard];
    NSArray *fresh=[self readItems:NO];
    self.mutableItems=[fresh mutableCopy] ?: [NSMutableArray array];
    return fresh;
}

- (NSArray *)favorites {
    NSArray *fresh=[self readItems:YES];
    return fresh;
}

- (void)setFavorite:(BOOL)favorite forItem:(KTClipboardItem *)item {
    if (!item || item.rowID<=0) return;
    sqlite3 *db=NULL;
    if (sqlite3_open_v2(KTHistoryDBPath.fileSystemRepresentation, &db, SQLITE_OPEN_READWRITE, NULL)!=SQLITE_OK) { if (db) sqlite3_close(db); return; }
    sqlite3_busy_timeout(db,3000);
    sqlite3_stmt *stmt=NULL;
    if (sqlite3_prepare_v2(db, "UPDATE history SET favorite=? WHERE id=?;", -1, &stmt, NULL)==SQLITE_OK) {
        sqlite3_bind_int(stmt,1,favorite ? 1 : 0);
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
    if (sqlite3_open_v2(KTHistoryDBPath.fileSystemRepresentation, &db, SQLITE_OPEN_READWRITE, NULL)!=SQLITE_OK) { if (db) sqlite3_close(db); return; }
    sqlite3_busy_timeout(db,3000);
    sqlite3_stmt *stmt=NULL;
    if (sqlite3_prepare_v2(db, "DELETE FROM history WHERE id=?;", -1, &stmt, NULL)==SQLITE_OK) {
        sqlite3_bind_int64(stmt,1,item.rowID);
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }
    sqlite3_close(db);
    [self reloadCache];
}

- (void)clearClipboardHistory {
    sqlite3 *db=NULL;
    if (sqlite3_open_v2(KTHistoryDBPath.fileSystemRepresentation, &db, SQLITE_OPEN_READWRITE, NULL)!=SQLITE_OK) { if (db) sqlite3_close(db); return; }
    sqlite3_busy_timeout(db,3000);
    sqlite3_exec(db, "DELETE FROM history WHERE favorite=0;", NULL, NULL, NULL);
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
