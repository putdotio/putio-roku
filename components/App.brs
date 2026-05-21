function init()
    m.storage = CreateObject("roRegistrySection", "userConfig")
    m.pendingDeepLink = invalid
    m.replaceRoute = false
    m.activeDialog = invalid
    m.activeDialogKind = ""
    m.hostedDialog = invalid
    m.hostedDialogSourceScreen = invalid
    m.clearingHostedDialogField = false
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
    m.routeStack = []
    m.activeRouteEntry = invalid
    m.routeEntrySequence = 0
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

    clearActiveDialog(false)

    resetStack = shouldResetRouteStack(nextRoute)
    replaceRoute = shouldReplaceRoute(nextRoute)

    previousEntry = m.activeRouteEntry
    if previousEntry <> invalid
        if resetStack
            clearRouteStack()
        else if replaceRoute
            m.routeStack.pop()
            disposeRouteEntry(previousEntry)
        else
            hideRouteEntry(previousEntry)
        end if
    end if

    m.replaceRoute = false
    pushRouteEntry(createRouteEntry(nextRoute))
end sub

sub onNavigateBack()
    if m.routeStack.count() <= 1
        return
    end if

    clearActiveDialog(false)

    currentEntry = m.routeStack.pop()
    disposeRouteEntry(currentEntry)

    previousEntry = m.routeStack.peek()
    showRouteEntry(previousEntry)
end sub

function shouldReplaceRoute(route)
    return route.replace = true
end function

function shouldResetRouteStack(route)
    return m.replaceRoute = true or route.id = "authScreen"
end function

sub mountRoute(route)
    pushRouteEntry(createRouteEntry(route))
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
    m.routeEntrySequence = m.routeEntrySequence + 1
    if screen.hasField("routeEntryId") = false
        screen.addFields({
            routeEntryId: 0
        })
    end if
    screen.routeEntryId = m.routeEntrySequence
    screen.visible = false
    screen.translation = [0, 0]
    if screen.hasField("params")
        screen.params = route.params
    end if
    observeRouteScreen(route.id, screen)

    return {
        entryId: m.routeEntrySequence,
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
    if screen.isInFocusChain()
        screen.setFocus(false)
    end if
    notifyRouteLifecycle(screen, "routeHidden")
    screen.visible = false
    clearHostedScreen(screen)

    m.activeRouteEntry = invalid
end sub

sub pushRouteEntry(entry)
    if entry = invalid
        return
    end if

    m.routeStack.push(entry)
    showRouteEntry(entry)
end sub

sub disposeRouteEntry(entry)
    if entry = invalid or entry.screen = invalid
        return
    end if

    screen = entry.screen
    unobserveRouteScreen(entry.route.id, screen)
    if screen.isInFocusChain()
        screen.setFocus(false)
    end if
    notifyRouteLifecycle(screen, "routeHidden")
    screen.visible = false
    clearHostedScreen(screen)

    if isActiveRouteEntry(entry)
        m.activeRouteEntry = invalid
    end if
end sub

sub clearRouteStack()
    for each entry in m.routeStack
        disposeRouteEntry(entry)
    end for

    m.routeStack = []
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
    if screen <> invalid
        parent = screen.getParent()
        if parent <> invalid
            parent.removeChild(screen)
        end if
    end if
end sub

sub restoreRouteFocus(entry)
    screen = entry.screen
    if canRestoreRouteFocus(entry.lastFocus, screen)
        focusRouteNode(entry.lastFocus)
    else if screen.isInFocusChain() = false
        focusRouteNode(screen)
    end if
end sub

sub focusRouteNode(node)
    if node = invalid
        return
    end if

    if node.isInFocusChain()
        node.setFocus(false)
    end if

    node.setFocus(true)
end sub

function canRestoreRouteFocus(node, screen) as boolean
    if node = invalid or screen = invalid
        return false
    end if

    currentNode = node
    while currentNode <> invalid
        if currentNode.hasField("visible") and currentNode.visible = false
            return false
        end if

        if isSameRouteNode(currentNode, screen)
            return true
        end if

        currentNode = currentNode.getParent()
    end while

    return false
end function

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

function isActiveRouteEntry(entry) as boolean
    if m.activeRouteEntry = invalid or entry = invalid
        return false
    end if

    return m.activeRouteEntry.entryId = entry.entryId
end function

function isSameRouteNode(leftNode, rightNode) as boolean
    if leftNode = invalid or rightNode = invalid
        return false
    end if

    if leftNode.hasField("routeEntryId") and rightNode.hasField("routeEntryId")
        return leftNode.routeEntryId <> 0 and leftNode.routeEntryId = rightNode.routeEntryId
    end if

    if leftNode.hasField("id") = false or rightNode.hasField("id") = false
        return false
    end if

    return leftNode.id <> "" and leftNode.id = rightNode.id
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
    else
        print "App config unavailable; using default playback config"
        m.global.config = normalizeAppConfig(invalid)
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
    deepLink = normalizeMediaDeepLink(args)

    if deepLink <> invalid
        m.pendingDeepLink = deepLink
    end if
end sub

function normalizeMediaDeepLink(args)
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
    if normalizedMediaType <> "movie" and normalizedMediaType <> "episode" and normalizedMediaType <> "video" and normalizedMediaType <> "shortformvideo" and normalizedMediaType <> "image"
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
        mediaType: normalizedMediaType,
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
    clearRouteStack()
    homeEntry = createRouteEntry({
        id: "homeScreen",
        params: {}
    })
    if homeEntry <> invalid
        pushRouteEntry(homeEntry)
    end if
    m.replaceRoute = false
    m.global.route = createDeepLinkRoute(deepLink)
end sub

function createDeepLinkRoute(deepLink)
    if deepLink.mediaType = "image"
        return {
            id: "imageScreen",
            params: {
                fileId: deepLink.fileId,
                fileName: "",
            },
        }
    end if

    return {
        id: "videoScreen",
        params: {
            fileId: deepLink.fileId,
            fileName: "",
            startFromChoice: deepLink.startFromChoice,
        },
    }
end function

sub onShowDialog(obj)
    dialog = obj.getData()

    if dialog = invalid
        if m.clearingHostedDialogField
            m.clearingHostedDialogField = false
            return
        end if

        clearActiveDialog()
        return
    end if

    if m.hostedDialog <> invalid and m.hostedDialog.isSameNode(dialog)
        return
    end if

    if m.lastHandledDialog <> invalid and m.lastHandledDialog.isSameNode(dialog)
        if activeRouteShowDialogIs(dialog) = false
            return
        end if
    end if

    m.lastHandledDialog = dialog
    showAppDialog(dialog, activeRouteScreen())
end sub

function activeRouteScreen()
    if m.activeRouteEntry = invalid
        return invalid
    end if

    return m.activeRouteEntry.screen
end function

function activeRouteShowDialogIs(dialog) as boolean
    screen = activeRouteScreen()
    if screen = invalid or screen.hasField("showDialog") = false or screen.showDialog = invalid
        return false
    end if

    return screen.showDialog.isSameNode(dialog)
end function

sub showAppDialog(dialog, sourceScreen)
    clearActiveDialog(false)

    m.activeDialogKind = "hosted"
    m.hostedDialog = dialog
    m.hostedDialogSourceScreen = sourceScreen
    m.hostedDialog.observeField("title", "onHostedDialogChanged")
    m.hostedDialog.observeField("message", "onHostedDialogChanged")
    m.hostedDialog.observeField("buttons", "onHostedDialogChanged")
    syncHostedDialog()
    openAppDialog()
    clearHostedDialogSourceField()
end sub

sub openAppDialog()
    m.activeDialog = m.appDialog
    m.appDialog.close = false
    attachAppDialogToActiveRoute()
    m.appDialog.visible = true
    suspendRouteFocus()
    m.appDialog.setFocus(true)
end sub

sub attachAppDialogToActiveRoute()
    if m.activeRouteEntry = invalid or m.activeRouteEntry.screen = invalid
        return
    end if

    targetParent = m.activeRouteEntry.screen
    currentParent = m.appDialog.getParent()

    if currentParent <> invalid
        currentParent.removeChild(m.appDialog)
    end if

    targetParent.appendChild(m.appDialog)
end sub

sub suspendRouteFocus()
    if m.activeRouteEntry = invalid or m.activeRouteEntry.screen = invalid
        return
    end if

    screen = m.activeRouteEntry.screen
    m.activeRouteEntry.lastFocus = getDeepFocusedNode(screen)

    if m.activeRouteEntry.lastFocus <> invalid
        m.activeRouteEntry.lastFocus.setFocus(false)
    end if

    if screen.isInFocusChain()
        screen.setFocus(false)
    end if

    if m.screenHost.isInFocusChain()
        m.screenHost.setFocus(false)
    end if
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

sub clearActiveDialog(restoreFocusAfterClose = true)
    hadActiveDialog = m.activeDialog <> invalid or m.appDialog.visible

    if m.hostedDialog <> invalid
        m.hostedDialog.unobserveField("title")
        m.hostedDialog.unobserveField("message")
        m.hostedDialog.unobserveField("buttons")
        m.hostedDialog = invalid
    end if
    m.hostedDialogSourceScreen = invalid

    m.activeDialog = invalid
    m.activeDialogKind = ""
    m.appDialog.visible = false
    parkAppDialog()

    if m.top.dialog <> invalid
        m.top.dialog.close = true
        m.top.dialog = invalid
    end if

    if restoreFocusAfterClose and hadActiveDialog and m.activeRouteEntry <> invalid and m.activeRouteEntry.screen <> invalid and m.activeRouteEntry.screen.visible
        restoreRouteFocus(m.activeRouteEntry)
    end if
end sub

sub clearHostedDialogSourceField()
    if m.hostedDialogSourceScreen = invalid or m.hostedDialogSourceScreen.hasField("showDialog") = false
        return
    end if

    if m.hostedDialogSourceScreen.showDialog = invalid
        return
    end if

    m.clearingHostedDialogField = true
    m.hostedDialogSourceScreen.showDialog = invalid
end sub

sub parkAppDialog()
    currentParent = m.appDialog.getParent()

    if currentParent <> invalid
        currentParent.removeChild(m.appDialog)
    end if

    m.top.appendChild(m.appDialog)
end sub

sub onAppDialogButtonSelected(obj)
    if m.activeDialogKind = "exitApp"
        onExitAppDialogButtonSelected(obj.getData())
    else if m.hostedDialog <> invalid
        m.hostedDialog.buttonSelected = obj.getData()
    end if
end sub

sub onAppDialogClosed()
    if m.activeDialogKind = "exitApp"
        clearActiveDialog()
    else if m.hostedDialog <> invalid
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
    clearActiveDialog(false)
    m.activeDialogKind = "exitApp"
    m.appDialog.title = "Exit put.io?"
    m.appDialog.message = ""
    m.appDialog.buttons = ["OK", "Cancel"]
    m.appDialog.defaultButton = 1
    openAppDialog()
end sub

sub onExitAppDialogButtonSelected(buttonIndex as integer)
    if buttonIndex = 0
        m.top.exitApp = true
        clearActiveDialog()
    else
        clearActiveDialog()
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if m.activeDialog = invalid
        if press = false
            return false
        end if

        return handleRouteKey(normalizeKey(key))
    end if

    if press = false
        return true
    end if

    if m.activeDialog.isInFocusChain() = false
        m.activeDialog.setFocus(true)
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
