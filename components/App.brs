function init()
    m.storage = CreateObject("roRegistrySection", "userConfig")
    m.pendingDeepLink = invalid
    m.replaceRoute = false
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
        if m.pendingDeepLink <> invalid
            routePendingDeepLink()
        else
            m.global.route = {
                id: "homeScreen",
                params: {}
            }
        end if
    else
        goToAuthScreen()
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
        clearActiveDialog()
        m.top.dialog = dialog
    end if
end sub

sub clearActiveDialog()
    if m.top.dialog <> invalid
        m.top.dialog.close = true
        m.top.dialog = invalid
    end if
end sub

sub onShowExitAppDialog(obj)
    if obj.getData() = true
        m.dialog = createObject("roSGNode", "Dialog")
        m.dialog.title = "Exit put.io?"
        m.dialog.buttons = ["OK", "Cancel"]
        m.dialog.observeField("buttonSelected", "onExitAppDialogButtonSelected")
        m.top.dialog = m.dialog
    end if
end sub

sub onExitAppDialogButtonSelected(obj)
    if obj.getData() = 0
        m.top.exitApp = true
    else
        m.dialog.close = true
    end if
end sub
