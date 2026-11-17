function classifyPlaybackFailure(input as object) as object
    errorInfo = input.errorInfo
    if type(errorInfo) <> "roAssociativeArray"
        errorInfo = invalid
    end if

    httpStatus = invalid
    if errorInfo <> invalid
        httpStatus = parsePlaybackHttpStatus(errorInfo.dbgmsg)
    end if
    if httpStatus = invalid
        httpStatus = parsePlaybackHttpStatus(input.errorStr)
    end if

    expiredLink = isExpiredLinkFailure(httpStatus, getPlaybackErrorCode(input.errorCode), getPlaybackErrorCategory(errorInfo))
    if expiredLink and input.started = true and isExpiredLinkHttpStatus(httpStatus) = false
        return createPlaybackFailureVerdict("retry", "connection_lost", httpStatus)
    end if

    if expiredLink
        if input.reresolved = true
            return createPlaybackFailureVerdict("fail", "link_expired", httpStatus)
        end if

        return createPlaybackFailureVerdict("reresolve", "link_expired", httpStatus)
    end if

    if input.started = true
        return createPlaybackFailureVerdict("retry", "playback_stopped", httpStatus)
    end if

    reason = "decoder_error"
    if getPlaybackErrorCode(input.errorCode) = getMediaFormatErrorCode() or httpStatus = getHttpBadRequestStatus()
        reason = "container_unsupported"
    end if

    if input.source = "original" and input.rescued <> true
        return createPlaybackFailureVerdict("rescue", reason, httpStatus)
    end if

    return createPlaybackFailureVerdict("fail", reason, httpStatus)
end function

function createPlaybackFailureVerdict(action as string, reason as string, httpStatus as dynamic) as object
    return {
        action: action,
        reason: reason,
        httpStatus: httpStatus
    }
end function

function isExpiredLinkFailure(httpStatus as dynamic, errorCode as integer, category as string) as boolean
    if httpStatus <> invalid
        if httpStatus = getHttpBadRequestStatus()
            return false
        end if

        if isExpiredLinkHttpStatus(httpStatus)
            return true
        end if
    end if

    return errorCode = getNetworkErrorCode() or errorCode = getConnectionTimeoutErrorCode() or category = "http"
end function

' Roku's Video node has no HTTP status field; the status shows up only in the free text of
' errorInfo.dbgmsg or errorStr, and HTTP failures can arrive with category "mediaplayer".
function parsePlaybackHttpStatus(text as dynamic) as dynamic
    if text = invalid
        return invalid
    end if

    lowerText = LCase(text.toStr())
    length = Len(lowerText)
    statusDigits = 3
    for index = 1 to length - statusDigits + 1
        candidate = Mid(lowerText, index, statusDigits)
        if isPlaybackDigits(candidate) and isPlaybackStatusStart(lowerText, index) and isPlaybackStatusEnd(lowerText, index + statusDigits) and hasPlaybackStatusLabel(lowerText, index)
            status = Val(candidate, 10)
            if status >= getLowestHttpStatus() and status <= getHighestHttpStatus()
                return status
            end if
        end if
    end for

    return invalid
end function

function isPlaybackDigits(text as string) as boolean
    for index = 1 to Len(text)
        if isPlaybackDigit(Mid(text, index, 1)) = false
            return false
        end if
    end for

    return true
end function

function isPlaybackDigit(character as string) as boolean
    return character >= "0" and character <= "9"
end function

function isPlaybackLetter(character as string) as boolean
    return character >= "a" and character <= "z"
end function

function isPlaybackWordCharacter(character as string) as boolean
    return isPlaybackDigit(character) or isPlaybackLetter(character) or character = "_"
end function

function isPlaybackStatusStart(text as string, statusIndex as integer) as boolean
    if statusIndex <= 1
        return true
    end if

    previous = Mid(text, statusIndex - 1, 1)
    if isPlaybackWordCharacter(previous) or previous = "/" or previous = "." or previous = "-"
        return false
    end if

    if previous = "="
        word = getPlaybackWordBefore(text, statusIndex - 1)
        return word = "status" or word = "code"
    end if

    if previous = ":"
        return Instr(1, getPlaybackHostBefore(text, statusIndex - 1), ".") = 0
    end if

    return true
end function

function isPlaybackStatusEnd(text as string, index as integer) as boolean
    if index > Len(text)
        return true
    end if

    character = Mid(text, index, 1)
    if character = "."
        return index = Len(text) or isPlaybackDigit(Mid(text, index + 1, 1)) = false
    end if

    return isPlaybackWordCharacter(character) = false and character <> "/" and character <> "-"
end function

function getPlaybackWordBefore(text as string, endIndex as integer) as string
    start = endIndex
    while start > 1 and isPlaybackWordCharacter(Mid(text, start - 1, 1))
        start = start - 1
    end while

    return Mid(text, start, endIndex - start)
end function

function getPlaybackHostBefore(text as string, endIndex as integer) as string
    start = endIndex
    while start > 1
        character = Mid(text, start - 1, 1)
        if isPlaybackWordCharacter(character) = false and character <> "." and character <> "-"
            exit while
        end if
        start = start - 1
    end while

    return Mid(text, start, endIndex - start)
end function

function hasPlaybackStatusLabel(text as string, statusIndex as integer) as boolean
    windowStart = statusIndex - getPlaybackStatusLabelWindow()
    if windowStart < 1
        windowStart = 1
    end if

    for each label in ["http", "status", "code"]
        position = Instr(windowStart, text, label)
        while position > 0 and position + Len(label) <= statusIndex
            if position = 1 or isPlaybackLetter(Mid(text, position - 1, 1)) = false
                return true
            end if
            position = Instr(position + 1, text, label)
        end while
    end for

    return false
end function

function isExpiredLinkHttpStatus(httpStatus as dynamic) as boolean
    if httpStatus = invalid
        return false
    end if

    for each expiredStatus in getExpiredLinkHttpStatuses()
        if httpStatus = expiredStatus
            return true
        end if
    end for

    return false
end function

function getPlaybackErrorCode(value as dynamic) as integer
    if value = invalid
        return 0
    end if

    valueType = type(value)
    if valueType = "roString" or valueType = "String"
        return Val(value, 10)
    end if

    return Int(value)
end function

function getPlaybackErrorCategory(errorInfo as object) as string
    if errorInfo = invalid or errorInfo.category = invalid
        return ""
    end if

    return LCase(errorInfo.category.toStr())
end function

function getNetworkErrorCode() as integer
    return -1
end function

function getConnectionTimeoutErrorCode() as integer
    return -2
end function

function getMediaFormatErrorCode() as integer
    return -5
end function

function getHttpBadRequestStatus() as integer
    return 400
end function

function getExpiredLinkHttpStatuses() as object
    return [401, 403, 404, 410]
end function

function getLowestHttpStatus() as integer
    return 100
end function

function getHighestHttpStatus() as integer
    return 599
end function

function getPlaybackStatusLabelWindow() as integer
    return 24
end function
