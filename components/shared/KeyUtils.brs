function normalizeKey(key as string) as string
    if key = invalid
        return ""
    end if

    return LCase(key)
end function

function isBackKey(key as string) as boolean
    return normalizeKey(key) = "back"
end function

function isSelectKey(key as string) as boolean
    normalizedKey = normalizeKey(key)
    return normalizedKey = "ok" or normalizedKey = "select"
end function

function isVerticalNavigationKey(key as string) as boolean
    normalizedKey = normalizeKey(key)
    return normalizedKey = "up" or normalizedKey = "down"
end function

function isOptionsKey(key as string) as boolean
    normalizedKey = normalizeKey(key)
    return normalizedKey = "options" or normalizedKey = "info"
end function

function isVisibleNode(node) as boolean
    return node <> invalid and node.visible = true
end function

function hasAnyVisibleNode(nodes as object) as boolean
    if nodes = invalid
        return false
    end if

    for each node in nodes
        if isVisibleNode(node)
            return true
        end if
    end for

    return false
end function

function isAppDialogOpen(screen) as boolean
    if screen = invalid
        return false
    end if

    dialog = screen.findNode("appDialog")
    return isVisibleNode(dialog)
end function

function shouldTrapModalInput(screen, localModals = invalid) as boolean
    return isAppDialogOpen(screen) or hasAnyVisibleNode(localModals)
end function
