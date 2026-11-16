' Older /account/info payloads omit account_status and only send account_active.
function isAccountInactive(user as dynamic) as boolean
    if type(user) <> "roAssociativeArray" and type(user) <> "AssociativeArray"
        return false
    end if

    status = user.account_status
    if type(status) = "roString" or type(status) = "String"
        return LCase(status) = "inactive"
    end if

    active = user.account_active
    if type(active) = "roBoolean" or type(active) = "Boolean"
        return not active
    end if

    return false
end function

' A deactivated account's streams fail like a broken file, so the account state replaces
' the generic error.
sub applyAccountNoticeToDialog(dialog as object, user as dynamic)
    notice = getAccountNotice(user)
    if notice = invalid or dialog = invalid
        return
    end if

    dialog.title = notice.title
    dialog.message = notice.message
end sub

function getAccountNotice(user as dynamic) as dynamic
    now = createObject("roDateTime")
    return buildAccountNotice(user, now.asSeconds())
end function

function buildAccountNotice(user as dynamic, nowSeconds as integer) as dynamic
    if not isAccountInactive(user)
        return invalid
    end if

    if user.is_sub_account = true
        return {
            title: "Your account has been deactivated",
            message: "Your family plan's owner needs to update their payment details to keep your plan active.",
        }
    end if

    message = ""
    days = getDaysUntilAccountFileDeletion(user.files_will_be_deleted_at, nowSeconds)
    if days >= 0
        unit = " days."
        if days = 1
            unit = " day."
        end if
        message = "Your files are still here, but they are scheduled to be deleted in " + days.toStr() + unit
    end if

    return {
        title: "Your account has been deactivated",
        message: message,
    }
end function

' Counts calendar days in UTC like the web app's daysDiffFromNow, so every client shows the
' same number on the same day. Returns -1 when the API sends no usable date.
function getDaysUntilAccountFileDeletion(deleteAt as dynamic, nowSeconds as integer) as integer
    if type(deleteAt) <> "roString" and type(deleteAt) <> "String"
        return -1
    end if

    if deleteAt = ""
        return -1
    end if

    deleteDate = createObject("roDateTime")
    deleteDate.fromISO8601String(deleteAt)
    deleteSeconds = deleteDate.asSeconds()
    if deleteSeconds <= 0
        return -1
    end if

    secondsPerDay = 86400
    days = Int(deleteSeconds / secondsPerDay) - Int(nowSeconds / secondsPerDay)
    if days < 0
        return 0
    end if

    return days
end function
