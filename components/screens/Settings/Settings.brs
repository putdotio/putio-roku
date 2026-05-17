function init()
    m.storage = CreateObject("roRegistrySection", "userConfig")

    m.top.observeField("visible", "onVisibleChange")
    m.version = m.top.findNode("version")
    m.version.text = m.version.text + createObject("roAppInfo").GetVersion()

    m.list = m.top.findNode("settingsList")
    m.list.observeField("itemSelected", "onListItemSelected")

    m.items = {
        show_only_media_files: {
            title: "Only Show Media Files",
            iconName: "align-left-1",
        },
        show_history: {
            title: "Keep populating the history page with your activities",
            iconName: "history-1",
        },
        playback_type: {
            title: "Video playback type",
            iconName: "file_type_video",
        },
        logout: {
            title: "Log out",
            iconName: "logout"
        }
    }
    m.itemsOrder = ["show_only_media_files", "show_history", "playback_type", "logout"]

    renderList()
end function

sub onVisibleChange()
    if m.top.visible
        m.list.setFocus(true)
        updateShowOnlyMediaValue()
        updateShowHistory()
        updatePlaybackTypeValue()
    end if
end sub

sub renderList()
    content = createObject("roSGNode", "ContentNode")

    for i = 0 to m.items.count() - 1
        key = m.itemsOrder[i]
        item = m.items[key]
        listItemData = content.createChild("ListItemData")
        listItemData.key = key
        listItemData.title = item.title
        listItemData.iconName = item.iconName
        if item.description <> invalid
            listItemData.description = item.description
        end if
        item.node = listItemData
    end for

    m.list.content = content
end sub

sub onListItemSelected(obj)
    key = m.list.content.getChild(obj.getData()).key

    if key = "logout"
        storage = CreateObject("roRegistrySection", "userConfig")
        storage.Delete("token")
        storage.Flush()
        m.top.navigate = {
            id: "authScreen"
            params: {}
        }
    else if key = "show_only_media_files"
        setShowOnlyMedia()
    else if key = "show_history"
        updateSetting("history_enabled", (not m.global.user.settings.history_enabled), onUpdateSetting)
    else if key = "playback_type"
        setPlaybackType(getNextPlaybackType())
    end if
end sub

sub onUpdateSetting()
    updateShowHistory()
end sub

sub updateShowHistory()
    m.showHistory = m.items.show_history.node
    if m.global.user.settings.history_enabled
        m.showHistory.description = "Enabled"
    else
        m.showHistory.description = "Disabled"
    end if
end sub

function getPlaybackType() as string
    return getPlaybackTypeFromConfig(m.global.config)
end function

function getNextPlaybackType() as string
    if getPlaybackType() = "hls"
        return "mp4"
    end if

    return "hls"
end function

sub setPlaybackType(playbackType as string)
    normalizedPlaybackType = normalizePlaybackTypeSetting(playbackType)
    m.updateConfigTask = createObject("roSGNode", "HttpTask")
    m.updateConfigTask.observeField("response", "onUpdatePlaybackType")
    m.updateConfigTask.url = "/config/playbackType"
    m.updateConfigTask.body = { value: normalizedPlaybackType }
    m.updateConfigTask.method = "PUT"
    m.pendingPlaybackType = normalizedPlaybackType
    m.updateConfigTask.control = "RUN"
end sub

sub onUpdatePlaybackType(obj)
    m.updateConfigTask.unobserveField("response")
    data = parseJSON(obj.getData())

    if data = invalid or data.status <> "OK"
        updatePlaybackTypeValue()
        return
    end if

    config = m.global.config
    if config = invalid
        config = {}
    end if

    config.playbackType = m.pendingPlaybackType
    m.global.config = config
    updatePlaybackTypeValue()
end sub

sub updatePlaybackTypeValue()
    m.playbackTypeListItem = m.items.playback_type.node
    m.playbackTypeListItem.description = getPlaybackTypeLabel(getPlaybackType())
end sub

sub setShowOnlyMedia()
    newValue = not toBool(m.storage.read("show_only_media_files"))
    m.storage.write("show_only_media_files", newValue.toStr())
    m.storage.flush()

    updateShowOnlyMediaValue()
end sub

sub updateShowOnlyMediaValue()
    m.showOnlyMediaListItem = m.items.show_only_media_files.node
    if toBool(m.storage.read("show_only_media_files"))
        m.showOnlyMediaListItem.description = "Enabled"
    else
        m.showOnlyMediaListItem.description = "Disabled"
    end if
end sub

function onKeyEvent(key, press)
    if m.top.visible and key = "back" and press
        m.top.navigateBack = "true"
        return true
    end if

    return false
end function
