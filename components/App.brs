function init()
  m.storage = CreateObject("roRegistrySection", "user")
  configureRouter()
  checkToken()
end function

sub configureRouter()
  m.routeHistory = []
  m.activeRoute = m.global.route
  m.global.observeField("route", "onNavigateToRoute")
end sub

sub onNavigateToRoute(obj)
  nextRoute = obj.getData()

  currentRouteScreen = m.top.findNode(m.activeRoute.id)
  currentRouteScreen.unobserveField("navigate")
  currentRouteScreen.unobserveField("navigateBack")
  currentRouteScreen.unobserveField("showExitAppDialog")
  currentRouteScreen.unobserveField("showDialog")
  currentRouteScreen.visible = false

  m.activeRoute.params = currentRouteScreen.params
  m.routeHistory.push(m.activeRoute)
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

  if (m.token = "") Then
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
    m.global.route = {
      id: "homeScreen",
      params: {}
    }
  else
    goToAuthScreen()
  end if
end sub

sub onShowDialog(obj)
  m.top.dialog = obj.getData()
end sub

sub onShowExitAppDialog(obj)
  if obj.getData() = true
    m.dialog = createObject("roSGNode", "Dialog")
    m.dialog.title = "Exit Put.io?"
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
