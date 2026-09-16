#import "KTHistoryAggregator.h"
#import "KTSettings.h"
#import <sqlite3.h>

static NSString * const KTHistoryDB = @"/var/mobile/Library/Preferences/com.keyboardtoolskayoko.history.sqlite3";
static sqlite3 *KTDB = NULL;
static dispatch_queue_t KTDBQueue;

static void KTDBOpen(void) {
    if (KTDB) return;
    if (!KTDBQueue) KTDBQueue = dispatch_queue_create("com.keyboardtoolskayoko.history.db", DISPATCH_QUEUE_SERIAL);
    if (sqlite3_open_v2(KTHistoryDB.UTF8String, &KTDB, SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE|SQLITE_OPEN_FULLMUTEX, NULL) != SQLITE_OK) {
        if (KTDB) sqlite3_close(KTDB);
        KTDB = NULL;
        return;
    }
    sqlite3_busy_timeout(KTDB, 3000);
    sqlite3_exec(KTDB, "PRAGMA journal_mode=WAL;", NULL, NULL, NULL);
    sqlite3_exec(KTDB, "PRAGMA synchronous=NORMAL;", NULL, NULL, NULL);
    sqlite3_exec(KTDB, "CREATE TABLE IF NOT EXISTS history (id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL, bundle TEXT NOT NULL, app TEXT NOT NULL, timestamp REAL NOT NULL, favorite INTEGER NOT NULL DEFAULT 0);", NULL, NULL, NULL);
}

static BOOL KTDBReady(void) {
    if (!KTDBQueue) KTDBQueue = dispatch_queue_create("com.keyboardtoolskayoko.history.db", DISPATCH_QUEUE_SERIAL);
    __block BOOL ready = NO;
    dispatch_sync(KTDBQueue, ^{ KTDBOpen(); ready = KTDB != NULL; });
    return ready;
}

static KTClipboardItem *KTItemFromStmt(sqlite3_stmt *stmt) {
    KTClipboardItem *item = [KTClipboardItem new];
    const unsigned char *text = sqlite3_column_text(stmt, 1);
    const unsigned char *bundle = sqlite3_column_text(stmt, 2);
    const unsigned char *app = sqlite3_column_text(stmt, 3);
    item.text = text ? [NSString stringWithUTF8String:(const char *)text] : @"";
    item.bundleIdentifier = bundle ? [NSString stringWithUTF8String:(const char *)bundle] : @"";
    item.appName = app ? [NSString stringWithUTF8String:(const char *)app] : @"";
    item.recordedAt = [NSDate dateWithTimeIntervalSince1970:sqlite3_column_double(stmt, 4)];
    item.favorite = sqlite3_column_int(stmt, 5) != 0;
    return item;
}

@implementation KTHistoryAggregator

+ (void)recordItem:(KTClipboardItem *)item {
    if (!item.text.length || !KTDBReady()) return;
    dispatch_sync(KTDBQueue, ^{
        KTDBOpen();
        sqlite3_stmt *stmt = NULL;
        const char *sql = "INSERT INTO history(text,bundle,app,timestamp,favorite) VALUES(?,?,?,?,0);";
        if (sqlite3_prepare_v2(KTDB, sql, -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_text(stmt, 1, item.text.UTF8String, -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(stmt, 2, (item.bundleIdentifier ?: @"").UTF8String, -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(stmt, 3, (item.appName ?: @"").UTF8String, -1, SQLITE_TRANSIENT);
            sqlite3_bind_double(stmt, 4, (item.recordedAt ?: NSDate.date).timeIntervalSince1970);
            if (sqlite3_step(stmt) == SQLITE_DONE) {
                item.databaseID = sqlite3_last_insert_rowid(KTDB);
                sqlite3_exec(KTDB, "DELETE FROM history WHERE id IN (SELECT id FROM history WHERE favorite=0 ORDER BY timestamp ASC, id ASC LIMIT MAX(0,(SELECT COUNT(*) FROM history)-100));", NULL, NULL, NULL);
            }
        }
        if (stmt) sqlite3_finalize(stmt);
    });
}

+ (NSArray<KTClipboardItem *> *)items {
    if (!KTDBReady()) return @[];
    __block NSMutableArray *result = [NSMutableArray array];
    dispatch_sync(KTDBQueue, ^{
        KTDBOpen();
        sqlite3_stmt *stmt = NULL;
        if (sqlite3_prepare_v2(KTDB, "SELECT id,text,bundle,app,timestamp,favorite FROM history ORDER BY timestamp DESC,id DESC;", -1, &stmt, NULL) == SQLITE_OK) {
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                KTClipboardItem *item = KTItemFromStmt(stmt);
                item.databaseID = sqlite3_column_int64(stmt, 0);
                [result addObject:item];
            }
        }
        if (stmt) sqlite3_finalize(stmt);
    });
    return result;
}

+ (NSArray<KTClipboardItem *> *)favorites {
    NSMutableArray *result = [NSMutableArray array];
    for (KTClipboardItem *item in self.items) if (item.favorite) [result addObject:item];
    return result;
}

+ (void)setFavorite:(BOOL)favorite forItem:(KTClipboardItem *)item {
    if (!item || !KTDBReady()) return;
    dispatch_async(KTDBQueue, ^{
        sqlite3_stmt *stmt = NULL;
        if (sqlite3_prepare_v2(KTDB, "UPDATE history SET favorite=? WHERE id=?;", -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_int(stmt, 1, favorite ? 1 : 0);
            sqlite3_bind_int64(stmt, 2, item.databaseID);
            sqlite3_step(stmt);
        }
        if (stmt) sqlite3_finalize(stmt);
    });
}

+ (void)removeItem:(KTClipboardItem *)item {
    if (!item || !item.databaseID || !KTDBReady()) return;
    dispatch_async(KTDBQueue, ^{
        sqlite3_stmt *stmt = NULL;
        if (sqlite3_prepare_v2(KTDB, "DELETE FROM history WHERE id=?;", -1, &stmt, NULL) == SQLITE_OK) {
            sqlite3_bind_int64(stmt, 1, item.databaseID);
            sqlite3_step(stmt);
        }
        if (stmt) sqlite3_finalize(stmt);
    });
}

+ (void)clearHistoryKeepingFavorites {
    if (!KTDBReady()) return;
    dispatch_async(KTDBQueue, ^{ sqlite3_exec(KTDB, "DELETE FROM history WHERE favorite=0;", NULL, NULL, NULL); });
}

@end
