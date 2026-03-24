# iOS 資料模型

iOS 端分為 **Guest**（純本地 SwiftData）和 **Authenticated**（API-first + SwiftData 快取）兩種模式。View 層統一使用 `Shared/Models/` 的 struct 作為 ViewModel，由 `DataManager` 負責 SwiftData ↔ struct 映射。

> **共用 Models**：`Expense`、`Ledger`、`ExpenseCategory`、`Currency`、`RecurringExpense` 位於 `Shared/Models/`，由 Life（iPhone）和 LifeWatch（Watch）兩個 target 共用。`CategoryIcon` 僅 Life 使用，保留在 `Life/Models/`。

---

## SwiftData 持久化模型

位於 `Life/Models/Persistence/`，由 `LifeSchema`（SchemaV1）定義。

### GuestExpense（訪客開銷）

未登入時的本地開銷儲存，登入後透過 `POST /api/auth/init` 上傳至 Server。

```swift
@Model final class GuestExpense {
    var id: UUID = UUID()
    var categoryKey: String    // "breakfast", "lunch", ... 對應 ExpenseCategory.defaults 的 key
    var amount: Int
    var memo: String
    var date: Date
    var latitude: Double?
    var longitude: Double?
    var address: String?
}
```

### CachedLedger（帳本快取）

```swift
@Model final class CachedLedger {
    @Attribute(.unique) var serverId: Int
    var name: String
    var type: String           // "personal" / "group"
    var currencyCode: String
    var inviteCode: String?
    var sortOrder: Int
    @Relationship(deleteRule: .cascade) var members: [CachedMember]
    @Relationship(deleteRule: .cascade) var categories: [CachedCategory]
    @Relationship(deleteRule: .cascade) var expenses: [CachedExpense]
    @Relationship(deleteRule: .cascade) var recurringExpenses: [CachedRecurringExpense]
    @Relationship(deleteRule: .cascade) var settlements: [CachedSettlement]
}
```

`toViewModel()` 方法將 CachedLedger 及其所有關聯轉換為 `Ledger` struct，使用 `serverId` 產生確定性 UUID 作為 View 的 stable identity。

### CachedCategory（分類快取）

```swift
@Model final class CachedCategory {
    @Attribute(.unique) var serverId: Int
    var key: String?           // 系統預設分類才有（如 "breakfast"）
    var name: String
    var icon: String
    var colorHex: String
    var sortOrder: Int
    var ledger: CachedLedger?
}
```

### CachedExpense（開銷快取）

```swift
@Model final class CachedExpense {
    var localId: UUID = UUID()  // SwiftData 內部識別（不送 Server）
    var serverId: Int?          // nil = 離線建立，尚未同步
    var categoryServerId: Int?  // nil = 其他分類
    var amount: Int
    var memo: String
    var date: Date
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var isSettled: Bool
    var paidByUserServerId: Int?
    var createdByUserServerId: Int?
    var isSynced: Bool          // false = 離線建立待同步
    var ledger: CachedLedger?
}
```

`isSynced = false` 代表離線建立的開銷，網路恢復時由 `ExpenseStore.syncOfflineExpenses()` 批次上傳。

### CachedMember（成員快取）

```swift
@Model final class CachedMember {
    @Attribute(.unique) var serverId: Int
    var userId: Int
    var name: String
    var role: String           // "owner" / "member"
    var isCurrentUser: Bool
    var ledger: CachedLedger?
}
```

### CachedRecurringExpense（固定開銷快取）

```swift
@Model final class CachedRecurringExpense {
    @Attribute(.unique) var serverId: Int
    var categoryServerId: Int?
    var amount: Int
    var frequencyType: String
    var frequencyValue: String? // JSON 字串
    var memo: String
    var isEnabled: Bool
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var paidByUserServerId: Int?
    var createdByUserServerId: Int?
    var ledger: CachedLedger?
}
```

### CachedSettlement（結算紀錄快取）

```swift
@Model final class CachedSettlement {
    @Attribute(.unique) var serverId: Int
    var date: Date
    var settledByUserId: Int
    var transfersJson: String?  // JSON 字串
    var currencySymbol: String
    var ledger: CachedLedger?
}
```

---

## Shared ViewModel 模型

位於 `Shared/Models/`，Life 和 LifeWatch 共用。

### Expense

```swift
struct Expense: Identifiable, Equatable {
    let id: UUID
    var serverId: Int?          // Server 端 ID（離線建立時為 nil）
    var amount: Double
    var category: ExpenseCategory
    var memo: String
    var date: Date
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var ledgerId: String
    var paidBy: LedgerMember?
}
```

### Ledger

```swift
struct Ledger: Identifiable, Equatable {
    let id: String              // Authenticated: String(serverId), Guest: 固定值
    var name: String
    var type: LedgerType        // .personal | .group
    var inviteCode: String?
    var members: [LedgerMember]
    var currency: Currency
    var categories: [ExpenseCategory]
    var expenses: [Expense]
    var recurringExpenses: [RecurringExpense]
    var settledExpenseIds: Set<UUID> = []
    var settlementRecords: [SettlementRecord] = []
}
```

### ExpenseCategory

```swift
struct ExpenseCategory: Identifiable, Equatable, Hashable {
    let id: String
    var key: String?            // 系統預設分類識別碼（Guest 時 id == key）
    var name: String
    var icon: String            // SF Symbol
    var color: Color
}
```

- `key` 用於 Guest → Authenticated 登入轉換時配對分類
- `categoryId = null`（Server）對應 `ExpenseCategory.otherCategory` 靜態屬性
- `isOther` computed property 判斷是否為「其他」分類
- 靜態預設：`ExpenseCategory.defaults`（26 個人預設）、`ExpenseCategory.groupDefaults`（6 群組預設）

### LedgerMember

```swift
struct LedgerMember: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var isCurrentUser: Bool = false
}
```

### Currency

```swift
struct Currency: Equatable, Hashable, Identifiable {
    let code: String      // "TWD", "JPY", "USD"
    let symbol: String    // "$", "¥", "€"
    let name: String      // "新台幣", "日幣", "美元"
    var unitLabel: String  // TWD→"元", JPY→"円", CNY→"元", 其他→code
}
```

14 種預設幣別（`Currency.all`）：TWD、JPY、USD、EUR、GBP、KRW、CNY、THB、VND、AUD、CAD、SGD、HKD、MYR。

### RecurringExpense

```swift
struct RecurringExpense: Identifiable, Equatable {
    let id: UUID
    var amount: Double
    var category: ExpenseCategory
    var frequency: RecurringFrequency
    var memo: String
    var isEnabled: Bool
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var ledgerId: String
    var paidBy: LedgerMember?
}
```

### RecurringFrequency

```swift
enum RecurringFrequency: Equatable {
    case daily
    case weekly(dayOfWeek: Int)        // 1=日 ... 7=六
    case monthly(dayOfMonth: Int)      // 1-31
    case yearly(month: Int, day: Int)  // month 1-12, day 1-31
}
```

### SettlementTransfer / SettlementRecord

```swift
struct SettlementTransfer: Identifiable, Equatable {
    let id: UUID
    var from: LedgerMember
    var to: LedgerMember
    var amount: Double
}

struct SettlementRecord: Identifiable, Equatable {
    let id: UUID
    var date: Date
    var settledBy: LedgerMember
    var transfers: [SettlementTransfer]
    var currencySymbol: String
}
```

---

## API Response 模型

位於 `Life/Models/API/`。

### StateResponse.swift

```swift
struct StateResponse: Decodable {
    let ledgers: [StateLedger]
}
struct StateLedger: Decodable {
    let id: Int
    let name, type, currency: String
    let inviteCode: String?
    let members: [StateMember]
    let categories: [StateCategory]
    let expenses: [StateExpense]
    let recurringExpenses: [StateRecurringExpense]
    let settlements: [StateSettlement]
}
struct StateMember: Decodable { ... }
struct StateCategory: Decodable { let id: Int; let key: String?; let name, icon, color: String; let sort: Int }
struct StateExpense: Decodable { ... }
struct StateRecurringExpense: Decodable { ... }
struct StateSettlement: Decodable { ... }
```

### CRUDResponses.swift

```swift
struct CategoryResponse: Decodable { let category: StateCategory }
struct ExpenseResponse: Decodable { let expense: StateExpense }
struct ExpenseBatchResponse: Decodable { let expenses: [StateExpense] }
struct RecurringExpenseResponse: Decodable { let recurringExpense: StateRecurringExpense }
struct LedgerCreateResponse: Decodable { let ledger: StateLedger }
struct LedgerJoinResponse: Decodable { let ledger: StateLedger }
struct LedgerLeaveResponse: Decodable { let success: Bool }
struct SettleResponse: Decodable { let settlement: StateSettlement }
struct SuccessResponse: Decodable { let success: Bool }
```

---

## Services

### DataManager（@MainActor）

Repository 層，管理 SwiftData 的所有讀寫操作。

**Guest 方法**：
| 方法 | 說明 |
|------|------|
| `addGuestExpense(...)` | 新增訪客開銷 |
| `fetchGuestExpenses()` | 取得所有訪客開銷 |
| `guestExpenseCount()` | 訪客開銷數量 |
| `updateGuestExpense(id:...)` | 更新訪客開銷 |
| `deleteGuestExpense(id:)` | 刪除訪客開銷 |
| `clearAllGuestData()` | 清除所有訪客資料 |

**Authenticated 快取方法**：
| 方法 | 說明 |
|------|------|
| `rebuildFromState(_:)` | 從 StateResponse 重建全部快取（保留 unsynced） |
| `fetchCachedLedgers()` | 取得所有快取帳本（轉為 ViewModel） |
| `cacheExpense(from:ledgerServerId:)` | 快取單筆開銷 |
| `updateCachedExpense(serverId:from:)` | 更新快取開銷 |
| `deleteCachedExpense(serverId:)` | 刪除快取開銷 |
| `addUnsyncedExpense(...)` | 新增離線開銷（isSynced = false） |
| `fetchUnsyncedExpenses()` | 取得待同步開銷 |
| `markExpensesSynced(_:)` | 標記開銷已同步 |
| `cacheCategory / update / delete` | 分類快取 CRUD |
| `updateCategorySortOrder(...)` | 更新分類排序 |
| `cacheRecurringExpense / update / delete` | 固定開銷快取 CRUD |
| `cacheLedgerFromState(_:sortOrder:)` | 快取帳本（加入群組時） |
| `deleteCachedLedger(serverId:)` | 刪除快取帳本 |
| `clearAllCache()` | 清除所有 Cached* 資料 |

### ExpenseStore（@MainActor）

核心業務邏輯層，依 auth 狀態自動切換 Guest / Authenticated 行為。

```swift
@MainActor @Observable final class ExpenseStore {
    var ledgers: [Ledger]
    var currentLedgerId: String

    // Computed（代理到 currentLedger）
    var categories: [ExpenseCategory]
    var expenses: [Expense]
    var recurringExpenses: [RecurringExpense]
    var isGroupLedger: Bool
    var currentMembers: [LedgerMember]
    var currentCurrency: Currency
}
```

**開銷方法**（Guest: 本地；Authenticated: API → 快取）：
| 方法 | 說明 |
|------|------|
| `addExpense(...)` async | 新增開銷（離線時 addUnsyncedExpense） |
| `updateExpense(_:)` async throws | 更新開銷 |
| `deleteExpense(id:)` async throws | 刪除開銷 |

**分類方法**（僅 Authenticated，需網路）：
| 方法 | 說明 |
|------|------|
| `addCategory(...)` async throws | 新增分類 |
| `updateCategory(_:)` async throws | 更新分類 |
| `deleteCategory(id:)` async throws | 刪除分類 |
| `moveCategory(from:to:)` async throws | 排序分類 |

**固定開銷方法**（僅 Authenticated，需網路）：
| 方法 | 說明 |
|------|------|
| `addRecurringExpense(_:)` async throws | 新增固定開銷 |
| `updateRecurringExpense(_:)` async throws | 更新固定開銷 |
| `deleteRecurringExpense(_:)` async throws | 刪除固定開銷 |

**帳本方法**：
| 方法 | 說明 |
|------|------|
| `updatePersonalLedger(...)` async throws | 更新個人帳本 |
| `createGroupLedger(...)` async throws → String | 建立群組帳本 |
| `joinGroupLedger(inviteCode:)` async throws | 加入群組帳本 |
| `leaveGroupLedger(id:)` async throws | 退出群組帳本 |
| `updateGroupLedger(_:)` async throws | 更新群組帳本 |
| `settleGroupLedger(id:transfers:)` async throws | 結算拆帳 |
| `moveLedger(from:to:)` | 排序帳本（本地） |

**同步方法**：
| 方法 | 說明 |
|------|------|
| `refreshState()` async | GET /api/state → rebuildFromState → reload |
| `syncOfflineExpenses()` async | 批次上傳離線開銷 → markSynced |
| `initAfterLogin(guestExpenses:)` async | POST /api/auth/init → rebuildFromState |
| `reload()` | 從 DataManager 重新載入 ledgers |

---

## 後端 Table 設計

完整 Table 設計請見 `docs/architecture.md`。關鍵設計決策：

- **無 localId**：移除所有 localId 欄位，Server ID 為唯一識別
- **categoryId nullable**：`null` 代表「其他」分類，移除 isSystemDefault
- **Category.key**：系統預設分類帶 key（如 `breakfast`），用於 Guest 登入轉換時配對
- **isSettled enum**：`yes`/`no` 而非 tinyint
- **isEnabled enum**：`yes`/`no` 而非 tinyint
