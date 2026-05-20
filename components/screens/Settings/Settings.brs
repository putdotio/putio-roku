function init()
    m.storage = CreateObject("roRegistrySection", "userConfig")

    m.top.observeField("visible", "onVisibleChange")
    applyAppOverhangColors(m.top.findNode("overhang"))

    m.list = m.top.findNode("settingsList")
    m.list.observeField("itemSelected", "onListItemSelected")
    m.playbackTypeUpdateInFlight = false
    m.pendingPlaybackType = invalid
    m.settingsErrorDialog = invalid
    m.appVersion = createObject("roAppInfo").GetVersion()
    m.deviceDescription = getDeviceDescription()

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
        },
        version: {
            title: "Version",
            iconName: "info",
            description: m.appVersion
        },
        device_info: {
            title: "Device",
            iconName: "settings",
            description: m.deviceDescription
        }
    }
    m.itemsOrder = ["show_only_media_files", "show_history", "playback_type", "version", "device_info", "logout"]

    renderList()
end function

function getDeviceDescription() as string
    deviceInfo = CreateObject("roDeviceInfo")
    modelName = deviceInfo.GetModelDisplayName()
    model = deviceInfo.GetModel()
    osVersion = formatOsVersion(deviceInfo.GetOSVersion())

    if modelName = invalid or modelName = ""
        modelName = model
    end if

    return modelName + " (" + model + ")  |  Roku OS " + osVersion
end function

function formatOsVersion(osVersion as object) as string
    if osVersion = invalid
        return "Unknown"
    end if

    version = osVersion.major + "." + osVersion.minor + "." + osVersion.revision
    if osVersion.build <> invalid and osVersion.build <> ""
        version = version + " build " + osVersion.build
    end if

    return version
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

    for i = 0 to m.itemsOrder.count() - 1
        key = m.itemsOrder[i]
        item = m.items[key]
        listItemData = content.createChild("ListItemData")
        listItemData.key = key
        listItemData.title = item.title
        listItemData.iconName = item.iconName
        listItemData.valueAlign = "right"
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
    else if key = "version" or key = "device_info"
        return
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
    if m.playbackTypeUpdateInFlight
        return
    end if

    normalizedPlaybackType = normalizePlaybackTypeSetting(playbackType)
    m.updateConfigTask = createObject("roSGNode", "HttpTask")
    m.updateConfigTask.observeField("response", "onUpdatePlaybackType")
    m.updateConfigTask.url = "/config/playbackType"
    m.updateConfigTask.body = { value: normalizedPlaybackType }
    m.updateConfigTask.method = "PUT"
    m.pendingPlaybackType = normalizedPlaybackType
    m.playbackTypeUpdateInFlight = true
    updatePlaybackTypeValue("Saving " + getPlaybackTypeLabel(normalizedPlaybackType) + "...")
    m.updateConfigTask.control = "RUN"
end sub

sub onUpdatePlaybackType(obj)
    m.updateConfigTask.unobserveField("response")
    data = parseJSON(obj.getData())

    if data = invalid or data.status <> "OK"
        m.playbackTypeUpdateInFlight = false
        m.pendingPlaybackType = invalid
        updatePlaybackTypeValue()
        showSettingsErrorDialog("Video playback type could not be saved. Please try again.")
        return
    end if

    config = m.global.config
    if config = invalid
        config = {}
    end if

    config.playbackType = m.pendingPlaybackType
    m.global.config = config
    m.playbackTypeUpdateInFlight = false
    m.pendingPlaybackType = invalid
    updatePlaybackTypeValue()
end sub

sub updatePlaybackTypeValue(description = invalid)
    m.playbackTypeListItem = m.items.playback_type.node
    if description <> invalid
        m.playbackTypeListItem.description = description
    else
        m.playbackTypeListItem.description = getPlaybackTypeLabel(getPlaybackType())
    end if
end sub

sub showSettingsErrorDialog(message as string)
    m.settingsErrorDialog = createObject("roSGNode", "AppDialog")
    m.settingsErrorDialog.title = "Settings not saved"
    m.settingsErrorDialog.message = message
    m.settingsErrorDialog.buttons = ["OK"]
    m.settingsErrorDialog.observeField("wasClosed", "onSettingsErrorDialogClosed")
    m.top.showDialog = m.settingsErrorDialog
end sub

sub onSettingsErrorDialogClosed()
    if m.settingsErrorDialog <> invalid
        m.settingsErrorDialog.unobserveField("wasClosed")
        m.settingsErrorDialog = invalid
    end if
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

function onKeyEvent(key as string, press as boolean) as boolean
    if m.top.visible and press
        normalizedKey = LCase(key)

        if normalizedKey = "back"
            m.top.navigateBack = true
            return true
        else if isOptionsKey(normalizedKey)
            return true
        end if
    end if

    return false
end function
