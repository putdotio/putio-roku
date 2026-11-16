' Driver for account-notice.test.ts, run by the @rokucommunity/brs interpreter.
function main() as string
    now = createObject("roDateTime")
    now.fromISO8601String("2026-11-16T22:30:00Z")
    nowSeconds = now.asSeconds()

    return formatJson({
        active: buildAccountNotice({ account_status: "active", account_active: true }, nowSeconds),
        legacyActive: buildAccountNotice({ account_active: true }, nowSeconds),
        noUser: buildAccountNotice(invalid, nowSeconds),
        ownerWithDate: buildAccountNotice({ account_status: "inactive", is_sub_account: false, files_will_be_deleted_at: "2026-11-30T03:00:00" }, nowSeconds),
        ownerTomorrow: buildAccountNotice({ account_status: "inactive", files_will_be_deleted_at: "2026-11-17T01:00:00" }, nowSeconds),
        ownerPastDate: buildAccountNotice({ account_status: "inactive", files_will_be_deleted_at: "2026-11-10T00:00:00" }, nowSeconds),
        ownerNoDate: buildAccountNotice({ account_status: "inactive", files_will_be_deleted_at: invalid }, nowSeconds),
        legacyInactive: buildAccountNotice({ account_active: false }, nowSeconds),
        familyMember: buildAccountNotice({ account_status: "inactive", is_sub_account: true, files_will_be_deleted_at: "2026-11-30T00:00:00" }, nowSeconds),
    })
end function
