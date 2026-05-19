function init()
    m.storage = CreateObject("roRegistrySection", "userConfig")
    m.pendingDeepLink = invalid
    m.replaceRoute = false
    m.activeDialog = invalid
    m.hostedDialog = invalid
    m.screenHost = m.top.findNode("screenHost")
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
    m.activeRouteEntry = invalid
    m.global.observeField("route", "onNavigateToRoute")
    mountRoute(m.global.route)
end sub

sub onNavigateToRoute(obj)
    nextRoute = obj.getData()

    navigateToRoute(nextRoute)
end sub

sub navigateToRoute(nextRoute)
    if nextRoute = invalid or nextRoute.id = invalid
        return
    end if

    clearActiveDialog()

    replaceRoute = shouldReplaceRoute(nextRoute)
    if nextRoute.id = "authScreen"
        replaceRoute = true
        m.routeHistory = []
    end if

    previousEntry = m.activeRouteEntry
    if previousEntry <> invalid
        hideRouteEntry(previousEntry)
        if not replaceRoute
            m.routeHistory.push(previousEntry)
        end if
    end if

    m.replaceRoute = false
    showRouteEntry(createRouteEntry(nextRoute))
end sub

sub onNavigateBack()
    prevRoute = m.routeHistory.pop()

    if prevRoute <> invalid
        clearActiveDialog()

        hideRouteEntry(m.activeRouteEntry)
        showRouteEntry(ensureRouteEntry(prevRoute))
    end if
end sub

function shouldReplaceRoute(route)
    return m.replaceRoute = true or route.replace = true
end function

sub mountRoute(route)
    showRouteEntry(createRouteEntry(route))
end sub

function createRouteEntry(route)
    if route = invalid or route.id = invalid
        return invalid
    end if

    screen = createRouteScreen(route.id)
    if screen = invalid
        return invalid
    end if

    screen.id = route.id
    screen.visible = false
    screen.translation = [0, 0]
    if screen.hasField("params")
        screen.params = route.params
    end if

    return {
        route: route,
        screen: screen,
        lastFocus: invalid,
    }
end function

function ensureRouteEntry(routeOrEntry)
    if routeOrEntry = invalid
        return invalid
    end if

    if routeOrEntry.screen <> invalid
        return routeOrEntry
    end if

    return createRouteEntry(routeOrEntry)
end function

sub showRouteEntry(entry)
    entry = ensureRouteEntry(entry)
    if entry = invalid
        return
    end if

    screen = entry.screen
    if screen = invalid
        return
    end if

    observeRouteScreen(entry.route.id, screen)
    setHostedScreen(screen)
    m.activeRouteEntry = entry
    screen.visible = true
    notifyRouteLifecycle(screen, "routeShown")
    restoreRouteFocus(entry)
end sub

sub hideRouteEntry(entry)
    if entry = invalid or entry.screen = invalid
        return
    end if

    screen = entry.screen
    entry.lastFocus = getDeepFocusedNode(screen)
    unobserveRouteScreen(entry.route.id, screen)
    if screen.isInFocusChain()
        screen.setFocus(false)
    end if
    notifyRouteLifecycle(screen, "routeHidden")
    screen.visible = false
    clearHostedScreen(screen)

    m.activeRouteEntry = invalid
end sub

sub setHostedScreen(screen)
    if screen = invalid
        return
    end if

    if m.screenHost.getChildCount() > 0
        m.screenHost.replaceChild(screen, 0)
    else
        m.screenHost.appendChild(screen)
    end if
end sub

sub clearHostedScreen(screen)
    if screen <> invalid and screen.getParent() <> invalid
        m.screenHost.removeChild(screen)
    end if
end sub

sub restoreRouteFocus(entry)
    screen = entry.screen
    if entry.lastFocus <> invalid
        entry.lastFocus.setFocus(true)
    else if screen.isInFocusChain() = false
        screen.setFocus(true)
    end if
end sub

function getDeepFocusedNode(screen)
    if screen = invalid or screen.isInFocusChain() = false
        return invalid
    end if

    focusedNode = screen
    while focusedNode <> invalid and focusedNode.hasFocus() = false and focusedNode.focusedChild <> invalid
        focusedNode = focusedNode.focusedChild
    end while

    if focusedNode <> invalid and focusedNode.hasFocus()
        return focusedNode
    end if

    return invalid
end function

sub notifyRouteLifecycle(screen, fieldName as string)
    if screen = invalid
        return
    end if

    if fieldName = "routeShown" and screen.hasField("routeShown")
        screen.routeShown = true
    else if fieldName = "routeHidden" and screen.hasField("routeHidden")
        screen.routeHidden = true
    end if
end sub

function createRouteScreen(routeId as string)
    componentName = getRouteComponentName(routeId)
    if componentName = ""
        return invalid
    end if

    return createObject("roSGNode", componentName)
end function

function getRouteComponentName(routeId as string) as string
    if routeId = "splashScreen"
        return "SplashScreen"
    else if routeId = "authScreen"
        return "AuthScreen"
    else if routeId = "homeScreen"
        return "HomeScreen"
    else if routeId = "searchScreen"
        return "SearchScreen"
    else if routeId = "historyScreen"
        return "HistoryScreen"
    else if routeId = "filesScreen"
        return "FilesScreen"
    else if routeId = "videoScreen"
        return "VideoScreen"
    else if routeId = "videoPlayerScreen"
        return "VideoPlayerScreen"
    else if routeId = "audioScreen"
        return "AudioScreen"
    else if routeId = "imageScreen"
        return "ImageScreen"
    else if routeId = "settingsScreen"
        return "SettingsScreen"
    end if

    return ""
end function

sub observeRouteScreen(routeId as string, screen)
    observeScreenField(screen, "navigate", "onNavigateToRoute")
    observeScreenField(screen, "navigateBack", "onNavigateBack")
    observeScreenField(screen, "showExitAppDialog", "onShowExitAppDialog")
    observeScreenField(screen, "showDialog", "onShowDialog")

    if routeId = "authScreen"
        observeScreenField(screen, "token", "onTokenRetrieved")
    end if
end sub

sub unobserveRouteScreen(routeId as string, screen)
    unobserveScreenField(screen, "navigate")
    unobserveScreenField(screen, "navigateBack")
    unobserveScreenField(screen, "showExitAppDialog")
    unobserveScreenField(screen, "showDialog")

    if routeId = "authScreen"
        unobserveScreenField(screen, "token")
    end if
end sub

sub observeScreenField(screen, fieldName as string, callbackName as string)
    if screen <> invalid and screen.hasField(fieldName)
        screen.observeField(fieldName, callbackName)
    end if
end sub

sub unobserveScreenField(screen, fieldName as string)
    if screen <> invalid and screen.hasField(fieldName)
        screen.unobserveField(fieldName)
    end if
end sub

sub goToAuthScreen()
    m.routeHistory = []
    m.replaceRoute = true
    m.global.route = {
        id: "authScreen",
        params: {},
    }
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
        m.replaceRoute = true
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
    m.appDialog.close = false
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
        showExitAppDialog()
    end if
end sub

sub showExitAppDialog()
    m.dialog = createObject("roSGNode", "AppDialog")
    m.dialog.title = "Exit put.io?"
    m.dialog.buttons = ["OK", "Cancel"]
    m.dialog.defaultButton = 1
    m.dialog.observeField("buttonSelected", "onExitAppDialogButtonSelected")
    m.dialog.observeField("wasClosed", "onExitAppDialogClosed")
    showAppDialog(m.dialog)
end sub

sub onExitAppDialogButtonSelected(obj)
    if obj.getData() = 0
        m.top.exitApp = true
        clearExitAppDialog()
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
    if press = false
        return false
    end if

    normalizedKey = LCase(key)

    if m.activeDialog = invalid
        return handleRouteKey(normalizedKey)
    end if

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
        dialog = m.activeDialog
        dialog.buttonSelected = dialog.focusedButton
        if m.activeDialog = dialog
            dialog.close = true
        end if
        return true
    end if

    return true
end function

function handleRouteKey(normalizedKey as string) as boolean
    if normalizedKey <> "back"
        return false
    end if

    return navigateBackOrExit()
end function

function navigateBackOrExit() as boolean
    if m.appDialog.visible
        return false
    end if

    if m.activeRouteEntry = invalid or m.activeRouteEntry.route = invalid
        return false
    end if

    routeId = m.activeRouteEntry.route.id
    if routeId = "authScreen" or routeId = "homeScreen"
        showExitAppDialog()
        return true
    end if

    onNavigateBack()
    return true
end function
