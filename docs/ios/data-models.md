# iOS 資料模型

目前所有資料為 Client 端記憶體儲存。本文件記錄現有模型結構，並標注後端對應的 Table 設計方向。

---

## Client 資料模型

### Expense

開銷紀錄，存在 Ledger 內。

```swift
struct Expense: Identifiable, Equatable {
    let id: UUID
    var amount: Double
    var category: ExpenseCategory   // 完整物件（非 ID 參考）
    var memo: String
    var date: Date
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var ledgerId: String
    var paidBy: LedgerMember?       // 群組帳本的付款人
}
```

**備註**：目前 `category` 存完整物件，更新分類時需同步更新所有引用該分類的開銷。後端應改為 `categoryId` 外鍵。

---

### Ledger

帳本，包含分類和開銷。

```swift
struct Ledger: Identifiable, Equatable {
    let id: String
    var name: String
    var type: LedgerType            // .personal | .group
    var inviteCode: String?         // 群組帳本 6 碼邀請碼
    var members: [LedgerMember]
    var currency: Currency          // 帳本幣別
    var categories: [ExpenseCategory]
    var expenses: [Expense]
    var recurringExpenses: [RecurringExpense]
    var settledExpenseIds: Set<UUID> = []        // 已結算開銷 ID
    var settlementRecords: [SettlementRecord] = [] // 結算歷史紀錄
}
```

| 屬性 | personal | group |
|------|----------|-------|
| inviteCode | nil | 6 碼（自動生成） |
| members | 僅「我」 | 多人 |
| currency | 預設 .twd | 建立時選擇 |
| categories | 個人預設（25） | 群組預設（7） |
| settledExpenseIds | 不使用 | 重設時收集已結算開銷 ID |
| settlementRecords | 不使用 | 結算歷史（時間 + 操作者） |

---

### SettlementRecord

結算紀錄，記錄拆帳重設的時間和操作者。

```swift
struct SettlementRecord: Identifiable, Equatable {
    let id: UUID
    var date: Date
    var settledBy: LedgerMember
}
```

---

### LedgerMember

帳本成員。

```swift
struct LedgerMember: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
}
```

**備註**：目前 `id` 為任意字串，後端應對應 `User.id`。`Ledger.defaultMemberId = "me"` 代表當前用戶。

---

### LedgerType

```swift
enum LedgerType: Equatable {
    case personal
    case group
}
```

---

### Currency

帳本幣別。

```swift
struct Currency: Equatable, Hashable, Identifiable {
    let code: String      // "TWD", "JPY", "USD"
    let symbol: String    // "$", "¥", "€"
    let name: String      // "新台幣", "日幣", "美元"

    var unitLabel: String  // TWD→"元", JPY→"円", CNY→"元", 其他→code
}
```

14 種預設幣別（`Currency.all`）：TWD、JPY、USD、EUR、GBP、KRW、CNY、THB、VND、AUD、CAD、SGD、HKD、MYR。

預設值 `Currency.twd`。帳本已有開銷時，幣別不可變更。

---

### ExpenseCategory

開銷分類，存在 Ledger 內。

```swift
struct ExpenseCategory: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var icon: String       // SF Symbol 名稱
    var color: Color       // SwiftUI Color
}
```

**系統預設「其他」分類**：每個帳本最後一個分類為「其他」（個人 `id: "other"`、群組 `id: "groupOther"`），不可編輯、不可刪除、不可排序。刪除分類時，所屬開銷與固定開銷自動歸類到「其他」。`isSystemOther` 屬性判斷是否為系統預設。

**預設分類**：

| 群組 | 個人預設 | 群組預設 |
|------|---------|---------|
| 餐飲 | 早餐、午餐、晚餐、甜點、飲料 | 聚餐 |
| 購物 | 衣服、日用品、醫療、購物 | 採買 |
| 居住 | 租金 | 租金、水電 |
| 交通 | 交通、汽車、加油、停車、大眾運輸 | 交通 |
| 休閒 | 娛樂、運動、學習 | 娛樂 |
| 財務 | 信用卡、投資、轉帳 | — |
| 其他 | 禮物、紅包、電話費、訂閱、3C、**其他**（系統預設） | **其他**（系統預設） |

---

### RecurringExpense

固定開銷，存在 Ledger 內。

```swift
struct RecurringExpense: Identifiable, Equatable {
    let id: UUID
    var amount: Double
    var category: ExpenseCategory
    var frequency: RecurringFrequency
    var memo: String
    var isEnabled: Bool             // 開關，關閉時排程不會建立開銷
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

- `displayLabel`：「每天」「每週三」「每月 15 日」「每年 1 月 1 日」
- `dateWarningMessage`：月 29-31 日、年份特殊日期的警告文字

---

### CategoryIcon

分類圖示選擇器的資料來源。

```swift
struct CategoryIcon {
    struct Group {
        let name: String
        let icons: [String]    // SF Symbol 名稱
    }
    static let groups: [Group]  // 9 組
}
```

9 個圖示群組：餐飲（8）、交通（9）、購物（8）、居住（8）、娛樂（9）、財務（6）、健康（7）、通訊（6）、其他（15）

---

## Services

### ExpenseStore

核心狀態管理，持有所有帳本資料。

```swift
@Observable final class ExpenseStore {
    var ledgers: [Ledger]
    var currentLedgerId: String

    // Computed（代理到 currentLedger）
    var categories: [ExpenseCategory]         // get/set
    var expenses: [Expense]                   // get/set
    var recurringExpenses: [RecurringExpense]  // get/set
    var isGroupLedger: Bool                   // get
    var currentMembers: [LedgerMember]        // get
    var currentCurrency: Currency             // get
}
```

| 方法 | 說明 |
|------|------|
| addExpense(...) | 新增開銷到目前帳本 |
| deleteExpense(id:) | 刪除開銷 |
| addCategory(...) | 新增分類到目前帳本 |
| updateCategory(_) | 更新分類（同步更新開銷引用） |
| deleteCategory(id:) | 刪除分類 |
| moveCategory(from:to:) | 排序分類 |
| addLedger(_) | 新增帳本 |
| updateLedger(_) | 更新帳本 |
| deleteLedger(id:) | 刪除帳本（自動切回 personal） |
| moveLedger(from:to:) | 排序群組帳本 |
| addRecurringExpense(_) | 新增固定開銷 |
| updateRecurringExpense(_) | 更新固定開銷 |
| deleteRecurringExpense(id:) | 刪除固定開銷 |
| recurringExpenseCount(forLedger:) | 指定帳本的固定開銷數量 |

---

### AuthManager

登入狀態管理。

```swift
@Observable final class AuthManager {
    var isAuthenticated: Bool
    var currentUser: UserInfo?
    var isLoading: Bool
    var errorMessage: String?
}
```

| 方法 | 說明 |
|------|------|
| handleAppleSignIn(authorization:) | 處理 Apple Sign In 回調 |
| devLogin(email:) | 開發者模擬登入 |
| signOut() | 登出、清除 token |
| checkExistingToken() | 啟動時驗證已存 token |

**UserInfo**：id, email, name, avatar?, status

---

### CalculatorEngine

計算機邏輯。

```swift
@Observable final class CalculatorEngine {
    var displayText: String
    var currentValue: UInt64
}
```

- 支援四則運算（加減乘除）
- UInt64（無負數），減法下溢回傳 0，除法向上取整
- 最大 12 位數輸入
- 連續運算支援

---

### APIClient

HTTP 請求工具（Singleton）。

- 自動注入 Bearer token（從 KeychainService）
- 30 秒 timeout
- JSON 編碼/解碼
- 錯誤型別：invalidURL、invalidResponse、serverError、decodingError、networkError

---

### KeychainService

JWT Token 安全儲存（Singleton）。

- saveToken / getToken / deleteToken
- 使用 `kSecClassGenericPassword`
- Account: `tw.iwi.life.auth.token`

---

### LocationService

位置服務。

```swift
@Observable final class LocationService {
    var currentAddress: String?
    var latitude: Double?
    var longitude: Double?
    var isLoading: Bool
}
```

- `init(autoRequest: Bool = true)`：`true` 時授權後自動定位，`false` 時僅在用戶主動呼叫 `requestLocation()` 時定位
- CLLocationManager 定位
- CLGeocoder 反向地理編碼（組合行政區 + 路名）
- 授權狀態管理（`pendingRequest` 旗標確保首次授權後自動發起定位）

---

## 後端 Table 設計（建議）

基於目前 Client 資料結構，後端建議的 Table 規劃：

```
┌──────────┐     ┌──────────────┐     ┌──────────┐
│   User   │────<│ LedgerMember │>────│  Ledger  │
└──────────┘     └──────────────┘     └──────────┘
                                          │
                              ┌───────────┼───────────┐
                              │           │           │
                         ┌────┴────┐ ┌────┴────┐      │
                         │Category │ │ Expense │──────┘
                         └─────────┘ └─────────┘
```

### User（已建立）

| 欄位 | 型別 | 說明 |
|------|------|------|
| id | uint | PK |
| email | string | 唯一 |
| name | string | 顯示名稱 |
| avatar | image? | 頭像 |
| appleId | string? | Apple User ID |
| status | enum | active / disabled |
| createAt | datetime | |
| updateAt | datetime | |

### Ledger

| 欄位 | 型別 | 說明 |
|------|------|------|
| id | uint | PK |
| name | string | 帳本名稱 |
| type | enum | personal / group |
| currency | varchar(3) | 幣別代碼（TWD、JPY 等） |
| inviteCode | string? | 群組邀請碼（unique） |
| createdByUserId | uint | FK → User |
| createAt | datetime | |
| updateAt | datetime | |

- 每個用戶自動建立一個 personal 帳本（不可刪除）
- inviteCode 需 unique index，查詢加入時使用

### LedgerMember

| 欄位 | 型別 | 說明 |
|------|------|------|
| id | uint | PK |
| ledgerId | uint | FK → Ledger |
| userId | uint | FK → User |
| role | enum | owner / member |
| sort | uint | 帳本在該用戶列表中的排序 |
| joinAt | datetime | |

- unique(ledgerId, userId)
- personal 帳本：只有一筆 owner
- group 帳本：建立者為 owner，加入者為 member

### Category

| 欄位 | 型別 | 說明 |
|------|------|------|
| id | uint | PK |
| ledgerId | uint | FK → Ledger |
| name | string | 分類名稱 |
| icon | string | SF Symbol 名稱 |
| color | string | 色碼（如 #FF6B6B） |
| sort | uint | 排序 |
| createAt | datetime | |

- 建立帳本時批次建立預設分類

### Expense

| 欄位 | 型別 | 說明 |
|------|------|------|
| id | uint | PK |
| ledgerId | uint | FK → Ledger |
| categoryId | uint | FK → Category |
| amount | uint | 金額（整數，單位：元） |
| memo | string | 備註 |
| date | date | 消費日期 |
| latitude | decimal? | 緯度 |
| longitude | decimal? | 經度 |
| address | string? | 地址 |
| paidByUserId | uint? | FK → User（群組帳本付款人） |
| createdByUserId | uint | FK → User（建立者） |
| createAt | datetime | |

- `amount` 建議用整數存（前端 CalculatorEngine 已使用 UInt64）
- `paidByUserId` 個人帳本為 null，群組帳本為實際付款者
