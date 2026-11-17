function init()
    m.storage = CreateObject("roRegistrySection", "userConfig")

    m.top.observeField("visible", "onVisibleChange")

    m.list = m.top.findNode("settingsList")
    applySettingsListLayout(m.list)
    m.list.observeField("itemSelected", "onListItemSelected")
    m.playbackMethodUpdateInFlight = false
    m.pendingPlaybackMethod = invalid
    m.settingsErrorDialog = invalid
    m.appVersion = createObject("roAppInfo").GetVersion()
    m.deviceDescription = getDeviceDescription()

    m.items = {
        show_only_media_files: {
            title: "Only Show Media Files",
            iconName: "media-filter",
        },
        show_history: {
            title: "Keep populating the history page with your activities",
            iconName: "history",
        },
        playback_method: {
            title: "Playback method",
            iconName: "file-video",
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
    m.itemsOrder = ["show_only_media_files", "show_history", "playback_method", "version", "device_info", "logout"]

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
        updatePlaybackMethodValue()
        updateVersionValue()
        m.global.observeFieldScoped("latestAppVersion", "updateVersionValue")
    else
        m.global.unobserveFieldScoped("latestAppVersion")
    end if
end sub

sub updateVersionValue()
    m.items.version.node.description = buildVersionDescription(m.appVersion, m.global.latestAppVersion)
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
    else if key = "playback_method"
        setPlaybackMethod(getOtherPlaybackMethod(getPlaybackMethod()))
    else if key = "version"
        if isNewerAppVersion(m.global.latestAppVersion, m.appVersion)
            m.global.appUpdateRequested = true
        end if
    else if key = "device_info"
        return
    end if
end sub

sub onUpdateSetting()
    updateShowHistory()
end sub

sub updateShowHistory()
    m.showHistory = m.items.show_history.node
    if m.global.user.settings.history_enabled
        m.showHistory.toggle = "on"
    else
        m.showHistory.toggle = "off"
    end if
end sub

function getPlaybackMethod() as string
    return getPlaybackMethodFromConfig(m.global.config)
end function

sub setPlaybackMethod(method as string)
    if m.playbackMethodUpdateInFlight
        return
    end if

    normalizedMethod = normalizePlaybackMethod(method)
    m.updateConfigTask = createObject("roSGNode", "HttpTask")
    m.updateConfigTask.observeField("response", "onUpdatePlaybackMethod")
    m.updateConfigTask.url = "/config/streaming_method"
    m.updateConfigTask.body = { value: normalizedMethod }
    m.updateConfigTask.method = "PUT"
    m.pendingPlaybackMethod = normalizedMethod
    m.playbackMethodUpdateInFlight = true
    updatePlaybackMethodValue("Saving…", normalizedMethod)
    m.updateConfigTask.control = "RUN"
end sub

sub onUpdatePlaybackMethod(obj)
    m.updateConfigTask.unobserveField("response")
    data = parseJSON(obj.getData())

    if data = invalid or data.status <> "OK"
        m.playbackMethodUpdateInFlight = false
        m.pendingPlaybackMethod = invalid
        updatePlaybackMethodValue()
        showSettingsErrorDialog("Playback method could not be saved. Please try again.")
        return
    end if

    config = m.global.config
    if config = invalid
        config = {}
    end if

    config.streaming_method = m.pendingPlaybackMethod
    m.global.config = config
    m.playbackMethodUpdateInFlight = false
    m.pendingPlaybackMethod = invalid
    updatePlaybackMethodValue()
end sub

sub updatePlaybackMethodValue(description = invalid, method = invalid)
    if method = invalid
        method = getPlaybackMethod()
    end if

    listItem = m.items.playback_method.node
    if description <> invalid
        listItem.description = description
    else
        listItem.description = getPlaybackMethodLabel(method)
    end if
    listItem.hint = getPlaybackMethodHint(method)
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
        m.showOnlyMediaListItem.toggle = "on"
    else
        m.showOnlyMediaListItem.toggle = "off"
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if shouldTrapModalInput(m.top)
        return true
    end if

    if m.top.visible and press
        normalizedKey = normalizeKey(key)

        if normalizedKey = "back"
            m.top.navigateBack = true
            return true
        else if isOptionsKey(normalizedKey)
            return true
        end if
    end if

    return false
end function
