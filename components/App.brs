function init()
  m.storage = CreateObject("roRegistrySection", "user")
  configureRouter()
  checkToken()
end function

sub configureRouter()
  m.activeRoute = m.global.route
  m.global.observeField("route", "onRouteChanged")
end sub

sub onRouteChanged(obj)
  ? "onRouteChanged "; obj.getData()
  nextRoute = obj.getData()

  currentRouteScreen = m.top.findNode(m.activeRoute.id)
  currentRouteScreen.visible = false

  nextRouteScreen = m.top.findNode(nextRoute.id)
  nextRouteScreen.visible = true
  nextRouteScreen.setFocus(true)

  m.activeRoute = nextRoute
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
  ? "onTokenRetrieved "; obj.getData()
  m.token = obj.getData()
  m.storage.Write("token", m.token)
  m.storage.Flush()
  getUserInfo()
end sub

sub getUserInfo()
  m.httpTask = createObject("roSGNode", "HttpTask")
  m.httpTask.observeField("response", "onUserInfoResponse")
  m.httpTask.url = "/account/info"
  m.httpTask.control = "RUN"
end sub

sub onUserInfoResponse(obj)
  ? "onUserInfoResponse"; obj.getData()
  data = parseJSON(obj.getData())

	if data <> invalid and data.info <> invalid
    m.global.user = data.info
    m.global.route = {
      id: "homeScreen",
      params: {}
    }
  else
    goToAuthScreen()
  end if
end sub
