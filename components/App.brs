function init()
  m.storage = CreateObject("roRegistrySection", "user")

  m.loadingScreen = m.top.findNode("loadingScreen")
  m.authScreen = m.top.findNode("authScreen")
  m.homeScreen = m.top.findNode("homeScreen")

  m.loadingScreen.setFocus(true)
  checkToken()
end function

sub goToAuthScreen()
  m.loadingScreen.visible = false
  m.authScreen.visible = true
  m.authScreen.setFocus(true)
  m.authScreen.observeField("token", "onTokenRetrieved")
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
    m.loadingScreen.visible = false
    m.authScreen.visible = false
    m.homeScreen.visible = true
    m.homeScreen.setFocus(true)
  else
    goToAuthScreen()
  end if
end sub
