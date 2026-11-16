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
    return "Version " + latest + " is out. Installing it takes a few seconds, then the app restarts."
end function

function buildUpdateDialogButtons() as object
    return ["Install now", "Later"]
end function

function getUpdatePackageUrl(version as string) as string
    return "https://roku.put.io/releases/v2/" + version + ".zip"
end function

function getDevInstallerUrl() as string
    return "http://127.0.0.1/plugin_install"
end function

function buildInstallerBodyHead(boundary as string) as string
    crlf = chr(13) + chr(10)
    quote = chr(34)
    head = "--" + boundary + crlf
    head = head + "Content-Disposition: form-data; name=" + quote + "mysubmit" + quote + crlf + crlf
    head = head + "Install" + crlf
    head = head + "--" + boundary + crlf
    head = head + "Content-Disposition: form-data; name=" + quote + "archive" + quote + "; filename=" + quote + "putio.zip" + quote + crlf
    head = head + "Content-Type: application/zip" + crlf + crlf
    return head
end function

function buildInstallerBodyTail(boundary as string) as string
    crlf = chr(13) + chr(10)
    return crlf + "--" + boundary + "--" + crlf
end function

function readInstallerStatus(responseCode as integer, body as dynamic) as string
    if responseCode = 401
        return "badPassword"
    end if

    if responseCode = 200 and GetInterface(body, "ifString") <> invalid and body.instr("Install Success") >= 0
        return "installed"
    end if

    return "failed"
end function

function buildUpdatePasswordTitle() as string
    return "Developer password"
end function

function buildUpdatePasswordMessage(retry as boolean) as object
    if retry
        return ["That password didn't work. Enter the one you set when you turned on developer mode."]
    end if

    return ["Enter the password you set when you turned on developer mode. This Roku keeps it for later updates."]
end function

function buildUpdateInstallingTitle() as string
    return "Installing update"
end function

function buildUpdateInstallingMessage(latest as string) as string
    return "Installing version " + latest + ". The app restarts when it's done."
end function

function buildUpdateFailedTitle() as string
    return "Update failed"
end function

function buildUpdateFailedMessage(latest as string) as string
    return "Version " + latest + " didn't install. Try again from Settings, or reinstall it with the steps at roku.put.io"
end function

function buildVersionDescription(current as string, latest as dynamic) as string
    if isNewerAppVersion(latest, current)
        return current + "  |  " + formatAppVersion(latest) + " available"
    end if

    return current
end function
