function init()
  m.storage = CreateObject("roRegistrySection", "user")
  if m.storage.Exists("token")
    m.token = m.storage.Read("token")
  else
    m.token = ""
  end if

  ? m.token

  m.loadingScreen = m.top.findNode("loadingScreen")
  m.authScreen = m.top.findNode("authScreen")
  m.homeScreen = m.top.findNode("homeScreen")
  m.loadingScreen.setFocus(true)

  if (m.token = "") Then
    m.loadingScreen.visible = false
    m.authScreen.visible = true
    m.authScreen.setFocus(true)
    m.authScreen.observeField("token", "onTokenRetrieved")
  else
    authenticate(m.token)
  end if
end function

sub onTokenRetrieved(obj)
  ? "onTokenRetrieved "; obj.getData()
  m.token = obj.getData()
  authenticate(m.token)
end sub

sub authenticate(token)
  m.storage.Write("token", token)
  m.storage.Flush()

  m.loadingScreen.visible = false
  m.homeScreen.visible = true
  m.homeScreen.setFocus(true)
end sub
