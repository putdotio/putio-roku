function getUpdateManifestUrl() as string
    return "https://roku.put.io/version.json"
end function

function parseAppVersion(value as dynamic) as dynamic
    if GetInterface(value, "ifString") = invalid
        return invalid
    end if

    parts = value.trim().split(".")
    if parts.count() <> 3
        return invalid
    end if

    numbers = []
    for each part in parts
        if part = "" or CreateObject("roRegex", "^\d+$", "").isMatch(part) = false
            return invalid
        end if
        numbers.push(part.toInt())
    end for

    return numbers
end function

function formatAppVersion(value as dynamic) as string
    numbers = parseAppVersion(value)
    if numbers = invalid
        return ""
    end if

    return numbers[0].toStr() + "." + numbers[1].toStr() + "." + numbers[2].toStr()
end function

function isNewerAppVersion(candidate as dynamic, current as dynamic) as boolean
    candidateNumbers = parseAppVersion(candidate)
    currentNumbers = parseAppVersion(current)
    if candidateNumbers = invalid or currentNumbers = invalid
        return false
    end if

    for i = 0 to 2
        if candidateNumbers[i] <> currentNumbers[i]
            return candidateNumbers[i] > currentNumbers[i]
        end if
    end for

    return false
end function

function readUpdateManifestVersion(body as dynamic) as string
    if GetInterface(body, "ifString") = invalid or body = ""
        return ""
    end if

    data = ParseJson(body)
    if GetInterface(data, "ifAssociativeArray") = invalid
        return ""
    end if

    return formatAppVersion(data.version)
end function

function shouldOfferAppUpdate(latest as dynamic, current as dynamic, dismissed as dynamic) as boolean
    if isNewerAppVersion(latest, current) = false
        return false
    end if

    return formatAppVersion(latest) <> formatAppVersion(dismissed)
end function

function buildUpdateDialogTitle() as string
    return "Update available"
end function

function buildUpdateDialogMessage(latest as string) as string
    return "Version " + latest + " is out. Sideloaded apps can't update themselves, so reinstall it with the steps at roku.put.io"
end function

function buildVersionDescription(current as string, latest as dynamic) as string
    if isNewerAppVersion(latest, current)
        return current + "  |  " + formatAppVersion(latest) + " available at roku.put.io"
    end if

    return current
end function
