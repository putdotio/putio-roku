function init()
    m.storage = CreateObject("roRegistrySection", "userConfig")
    m.pendingDeepLink = invalid
    m.replaceRoute = false
    m.activeDialog = invalid
    m.hostedDialog = invalid
    m.appDialog = m.top.findNode("appDialog")
    m.appDialog.observeField("buttonSelected", "onAppDialogButtonSelected")
    m.appDialog.observeField("wasClosed", "onAppDialogClosed")
    m.top.observeField("deepLink", "onDeepLink")
    configureRouter()
    queueDeepLink(m.top.deepLink)
    checkToken()
end function

sub configureRouter()
    m.routeHistory = []
    m.activeRoute = m.global.route
    m.global.observeField("route", "onNavigateToRoute")
end sub

sub onNavigateToRoute(obj)
    nextRoute = obj.getData()

    clearActiveDialog()

    currentRouteScreen = m.top.findNode(m.activeRoute.id)
    currentRouteScreen.unobserveField("navigate")
    currentRouteScreen.unobserveField("navigateBack")
    currentRouteScreen.unobserveField("showExitAppDialog")
    currentRouteScreen.unobserveField("showDialog")
    currentRouteScreen.visible = false

    if m.replaceRoute or nextRoute.replace = true
        m.replaceRoute = false
    else
        m.activeRoute.params = currentRouteScreen.params
        m.routeHistory.push(m.activeRoute)
    end if
    m.activeRoute = nextRoute

    nextRouteScreen = m.top.findNode(nextRoute.id)
    nextRouteScreen.params = nextRoute.params
    nextRouteScreen.observeField("navigate", "onNavigateToRoute")
    nextRouteScreen.observeField("navigateBack", "onNavigateBack")
    nextRouteScreen.observeField("showExitAppDialog", "onShowExitAppDialog")
    nextRouteScreen.observeField("showDialog", "onShowDialog")
    nextRouteScreen.visible = true
    nextRouteScreen.setFocus(true)
end sub

sub onNavigateBack()
    prevRoute = m.routeHistory.pop()

    if prevRoute <> invalid
        clearActiveDialog()

        currentRouteScreen = m.top.findNode(m.activeRoute.id)
        currentRouteScreen.unobserveField("navigate")
        currentRouteScreen.unobserveField("navigateBack")
        currentRouteScreen.unobserveField("showExitAppDialog")
        currentRouteScreen.unobserveField("showDialog")
        currentRouteScreen.visible = false

        m.activeRoute = prevRoute

        prevRouteScreenScreen = m.top.findNode(prevRoute.id)
        prevRouteScreenScreen.params = prevRoute.params
        prevRouteScreenScreen.observeField("navigate", "onNavigateToRoute")
        prevRouteScreenScreen.observeField("navigateBack", "onNavigateBack")
        prevRouteScreenScreen.observeField("showExitAppDialog", "onShowExitAppDialog")
        prevRouteScreenScreen.observeField("showDialog", "onShowDialog")
        prevRouteScreenScreen.visible = true
        prevRouteScreenScreen.setFocus(true)
    end if
end sub

sub goToAuthScreen()
    m.global.route = {
        id: "authScreen",
        params: {},
    }
    authScreen = m.top.findNode("authScreen")
    authScreen.observeField("token", "onTokenRetrieved")
end sub

sub checkToken()
    if m.storage.Exists("token")
        m.token = m.storage.Read("token")
    else
        m.token = ""
    end if

    if (m.token = "") then
        goToAuthScreen()
    else
        getUserInfo()
    end if
end sub

sub onTokenRetrieved(obj)
    m.token = obj.getData()
    m.storage.Write("token", m.token)
    m.storage.Flush()
    getUserInfo()
end sub

sub getUserInfo()
    m.httpTask = createObject("roSGNode", "HttpTask")
    m.httpTask.observeField("response", "onUserInfoResponse")
    m.httpTask.url = "/account/info?download_token=1"
    m.httpTask.control = "RUN"
end sub

sub onUserInfoResponse(obj)
    m.httpTask.unobserveField("response")
    data = parseJSON(obj.getData())

    if data <> invalid and data.info <> invalid
        m.routeHistory = []
        m.global.user = data.info
        getUserConfig()
    else
        goToAuthScreen()
    end if
end sub

sub getUserConfig()
    m.configTask = createObject("roSGNode", "HttpTask")
    m.configTask.observeField("response", "onUserConfigResponse")
    m.configTask.url = "/config"
    m.configTask.control = "RUN"
end sub

sub onUserConfigResponse(obj)
    m.configTask.unobserveField("response")
    data = parseJSON(obj.getData())

    if data <> invalid and data.config <> invalid
        m.global.config = normalizeAppConfig(data.config)
    end if

    routeAfterBootstrap()
end sub

function normalizeAppConfig(config) as object
    normalizedConfig = m.global.config
    if normalizedConfig = invalid
        normalizedConfig = {}
    end if

    normalizedConfig.playbackType = getPlaybackTypeFromConfig(config)
    return normalizedConfig
end function

sub routeAfterBootstrap()
    if m.pendingDeepLink <> invalid
        routePendingDeepLink()
    else
        m.global.route = {
            id: "homeScreen",
            params: {}
        }
    end if
end sub

sub onDeepLink(obj)
    queueDeepLink(obj.getData())

    if isAuthenticated() and m.pendingDeepLink <> invalid
        routePendingDeepLink()
    end if
end sub

sub queueDeepLink(args)
    deepLink = normalizeVideoDeepLink(args)

    if deepLink <> invalid
        m.pendingDeepLink = deepLink
    end if
end sub

function normalizeVideoDeepLink(args)
    if args = invalid
        return invalid
    end if

    contentId = readDeepLinkValue(args, "contentID")
    if contentId = invalid
        contentId = readDeepLinkValue(args, "contentId")
    end if

    mediaType = readDeepLinkValue(args, "mediaType")
    if mediaType = invalid
        return invalid
    end if

    normalizedMediaType = LCase(mediaType.toStr())
    if normalizedMediaType <> "movie" and normalizedMediaType <> "episode" and normalizedMediaType <> "video" and normalizedMediaType <> "shortformvideo"
        return invalid
    end if

    if contentId = invalid
        return invalid
    end if

    fileId = contentId.toStr().toInt()
    if fileId <= 0
        return invalid
    end if

    startFrom = readDeepLinkValue(args, "startFrom")
    startFromChoice = invalid
    if startFrom <> invalid
        normalizedStartFrom = LCase(startFrom.toStr())
        if normalizedStartFrom = "continue" or normalizedStartFrom = "beginning"
            startFromChoice = normalizedStartFrom
        end if
    end if

    return {
        fileId: fileId,
        startFromChoice: startFromChoice,
    }
end function

function readDeepLinkValue(args, key)
    if args <> invalid and args.doesExist(key)
        return args[key]
    end if

    return invalid
end function

function isAuthenticated()
    return m.global.user <> invalid and m.global.user.id <> invalid
end function

sub routePendingDeepLink()
    deepLink = m.pendingDeepLink
    m.pendingDeepLink = invalid

    if deepLink = invalid
        return
    end if

    clearActiveDialog()
    m.routeHistory = [
        {
            id: "homeScreen",
            params: {}
        }
    ]
    m.replaceRoute = true
    m.global.route = {
        id: "videoScreen",
        params: {
            fileId: deepLink.fileId,
            fileName: "",
            startFromChoice: deepLink.startFromChoice,
        },
    }
end sub

sub onShowDialog(obj)
    dialog = obj.getData()

    if dialog = invalid
        clearActiveDialog()
    else
        showAppDialog(dialog)
    end if
end sub

sub showAppDialog(dialog)
    clearActiveDialog()

    m.hostedDialog = dialog
    m.hostedDialog.observeField("title", "onHostedDialogChanged")
    m.hostedDialog.observeField("message", "onHostedDialogChanged")
    m.hostedDialog.observeField("buttons", "onHostedDialogChanged")
    syncHostedDialog()

    m.activeDialog = m.appDialog
    m.appDialog.visible = true
    m.appDialog.setFocus(true)
end sub

sub onHostedDialogChanged()
    syncHostedDialog()
end sub

sub syncHostedDialog()
    if m.hostedDialog = invalid
        return
    end if

    m.appDialog.title = m.hostedDialog.title
    m.appDialog.message = m.hostedDialog.message
    m.appDialog.buttons = m.hostedDialog.buttons
    m.appDialog.defaultButton = m.hostedDialog.defaultButton
end sub

sub clearActiveDialog()
    if m.hostedDialog <> invalid
        m.hostedDialog.unobserveField("title")
        m.hostedDialog.unobserveField("message")
        m.hostedDialog.unobserveField("buttons")
        m.hostedDialog = invalid
    end if

    m.activeDialog = invalid
    m.appDialog.visible = false

    if m.top.dialog <> invalid
        m.top.dialog.close = true
        m.top.dialog = invalid
    end if
end sub

sub onAppDialogButtonSelected(obj)
    if m.hostedDialog <> invalid
        m.hostedDialog.buttonSelected = obj.getData()
    end if
end sub

sub onAppDialogClosed()
    if m.hostedDialog <> invalid
        hostedDialog = m.hostedDialog
        clearActiveDialog()
        hostedDialog.wasClosed = true
    end if
end sub

sub onShowExitAppDialog(obj)
    if obj.getData() = true
        m.dialog = createObject("roSGNode", "AppDialog")
        m.dialog.title = "Exit put.io?"
        m.dialog.buttons = ["OK", "Cancel"]
        m.dialog.defaultButton = 1
        m.dialog.observeField("buttonSelected", "onExitAppDialogButtonSelected")
        m.dialog.observeField("wasClosed", "onExitAppDialogClosed")
        showAppDialog(m.dialog)
    end if
end sub

sub onExitAppDialogButtonSelected(obj)
    if obj.getData() = 0
        m.top.exitApp = true
    else
        clearExitAppDialog()
    end if
end sub

sub onExitAppDialogClosed()
    clearExitAppDialog()
end sub

sub clearExitAppDialog()
    if m.dialog <> invalid
        m.dialog.unobserveField("buttonSelected")
        m.dialog.unobserveField("wasClosed")
        if m.hostedDialog = m.dialog
            clearActiveDialog()
        end if
        m.dialog = invalid
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if press = false or m.activeDialog = invalid
        return false
    end if

    normalizedKey = LCase(key)

    if normalizedKey = "back"
        m.activeDialog.close = true
        return true
    else if normalizedKey = "up" or normalizedKey = "down"
        buttons = m.activeDialog.buttons
        if buttons <> invalid and buttons.count() > 1
            if m.activeDialog.focusedButton = 0
                m.activeDialog.focusedButton = 1
            else
                m.activeDialog.focusedButton = 0
            end if
        end if
        return true
    else if normalizedKey = "ok" or normalizedKey = "select"
        m.activeDialog.buttonSelected = m.activeDialog.focusedButton
        m.activeDialog.close = true
        return true
    end if

    return true
end function
