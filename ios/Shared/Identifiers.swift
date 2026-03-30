import Foundation

enum AID {
    // MARK: - Tab Bar
    static let tabExpense = "tab_expense"
    static let tabProfile = "tab_profile"

    // MARK: - AddExpenseView
    static let btnExpenseList = "btn_expense_list"
    static let btnSaveExpense = "btn_save_expense"
    static let overlaySaveConfirm = "overlay_save_confirm"

    // MARK: - Calculator
    static func calcBtn(_ key: String) -> String { "calc_\(key)" }
    static let calcDisplay = "calc_display"

    // MARK: - Category
    static func categoryCell(_ key: String) -> String { "cat_\(key)" }
    static let btnCategorySettings = "btn_cat_settings"

    // MARK: - Ledger
    static func ledgerPill(_ id: String) -> String { "ledger_\(id)" }
    static let btnLedgerSettings = "btn_ledger_settings"

    // MARK: - Payer
    static func payerChip(_ id: String) -> String { "payer_\(id)" }

    // MARK: - Debug Panel
    static let debugIndicator = "debug_indicator"
    static let toggleOffline = "toggle_offline"
    static let toggleAPIFailure = "toggle_api_failure"

    // MARK: - Profile / Auth
    static let btnDevLogin = "btn_dev_login"
    static let btnSignOut = "btn_sign_out"
    static let fieldDevEmail = "field_dev_email"
    static let btnDevLoginSubmit = "btn_dev_login_submit"
    static let btnAppleSignIn = "btn_apple_sign_in"

    // MARK: - Expense List / Detail / Edit
    static func expenseCell(_ id: String) -> String { "expense_\(id)" }
    static let btnEditExpense = "btn_edit_expense"
    static let btnDeleteExpense = "btn_delete_expense"
    static let btnSaveEdit = "btn_save_edit"
    static let btnCancelEdit = "btn_cancel_edit"
    static let btnSettle = "btn_settle"
    static let btnChart = "btn_chart"

    // MARK: - Expense List
    static let expenseListEmpty = "expense_list_empty"

    // MARK: - Category Settings
    static let btnAddCategory = "btn_add_category"
    static func catSettingsRow(_ id: String) -> String { "cat_settings_\(id)" }

    // MARK: - Category Edit
    static let fieldCatName = "field_cat_name"
    static let btnCatSave = "btn_cat_save"
    static let btnCatDelete = "btn_cat_delete"
    static func catIconGroup(_ name: String) -> String { "cat_icon_group_\(name)" }
    static func catIcon(_ icon: String) -> String { "cat_icon_\(icon)" }

    // MARK: - Ledger Settings
    static let menuAddLedger = "menu_add_ledger"
    static let ledgerSettingsPersonal = "ledger_settings_personal"
    static func ledgerSettingsGroup(_ id: String) -> String { "ledger_settings_group_\(id)" }

    // MARK: - Ledger Edit
    static let fieldLedgerName = "field_ledger_name"
    static let btnLedgerSave = "btn_ledger_save"

    // MARK: - Join Ledger
    static let fieldInviteCode = "field_invite_code"
    static let btnJoinSubmit = "btn_join_submit"
    static let btnJoinDone = "btn_join_done"

    // MARK: - Ledger Detail
    static let btnLedgerEdit = "btn_ledger_edit"
    static let btnLedgerLeave = "btn_ledger_leave"

    // MARK: - Recurring Expense
    static let btnPersonalRecurring = "btn_personal_recurring"
    static let btnAddRecurring = "btn_add_recurring"
    static let btnSaveRecurring = "btn_save_recurring"
    static let btnDeleteRecurring = "btn_delete_recurring"
    static func recurringRow(_ id: String) -> String { "recurring_\(id)" }
    static func freqType(_ type: String) -> String { "freq_\(type)" }
}
