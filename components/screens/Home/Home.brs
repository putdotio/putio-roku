function init()
    m.top.observeField("visible", "onVisibleChange")
    m.top.observeField("routeShown", "onRouteShown")
    m.global.observeField("user", "modifyList")
    applyAppOverhangColors(m.top.findNode("overhang"))

    m.list = m.top.findNode("list")
    m.list.observeField("itemSelected", "onListItemSelected")

    m.items = [
        {
            key: "files",
            title: "Your Files",
            iconName: "file_type_folder",
        },
        {
            key: "search",
            title: "Search",
            iconName: "search",
        },
        {
            key: "history",
            title: "History",
            iconName: "history-1",
            isEnabled: false
        },
        {
            key: "settings",
            title: "Settings",
            iconName: "settings",
        }
    ]
    modifyList()
end function

sub onVisibleChange()
    if m.top.visible
        focusHomeList()
    end if
end sub

sub onRouteShown()
    focusHomeList()
end sub

sub focusHomeList()
    if m.list = invalid
        return
    end if

    if m.list.isInFocusChain()
        m.list.setFocus(false)
    end if

    m.list.setFocus(true)
end sub

sub modifyList()
    if m.global.user <> invalid and m.global.user.settings <> invalid and m.global.user.settings.doesExist("history_enabled")
        m.items[2].isEnabled = m.global.user.settings.history_enabled
    end if

    renderList()
end sub

sub renderList()
    content = createObject("roSGNode", "ContentNode")

    for i = 0 to m.items.count() - 1
        item = m.items[i]
        if item.isEnabled = invalid or (item.isEnabled <> invalid and item.isEnabled)
            listItemData = content.createChild("ListItemData")
            listItemData.key = item.key
            listItemData.title = item.title
            listItemData.iconName = item.iconName
        end if
    end for

    m.list.content = content
end sub

sub onListItemSelected(obj)
    key = m.list.content.getChild(obj.getData()).key

    if key = "search"
        m.top.navigate = {
            id: "searchScreen",
            params: {}
        }

    else if key = "files"
        m.top.navigate = {
            id: "filesScreen"
            params: {
                fileId: 0
            }
        }

    else if key = "settings"
        m.top.navigate = {
            id: "settingsScreen",
            params: {},
        }

    else if key = "history"
        m.top.navigate = {
            id: "historyScreen",
            params: {},
        }

    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if shouldTrapModalInput(m.top)
        return true
    end if

    if m.top.visible and press
        normalizedKey = normalizeKey(key)

        if normalizedKey = "back"
            m.top.showExitAppDialog = true
            return true
        else if isOptionsKey(normalizedKey)
            return true
        end if
    end if

    return false
end function
