function init()
  m.top.token = ""
  m.top.observeField("visible", "onVisibleChange")
  m.shouldCheckCodeMatch = false
end function

sub onVisibleChange()
  m.code = ""
  m.label = m.top.findNode("code")

  if m.top.visible
    getAuthCode()
  end if
end sub

sub getAuthCode()
	deviceInfo = createObject("roDeviceInfo")
  m.httpTask = createObject("roSGNode", "HttpTask")
  m.httpTask.observeField("response", "onAuthCodeResponse")
  m.httpTask.url = "/oauth2/oob/code?app_id=" + m.global.appId + "&client_name=" + deviceInfo.getFriendlyName().EncodeUri()
  m.httpTask.control = "RUN"
end sub

sub onAuthCodeResponse(obj)
  ' ? "onAuthCodeResponse "; obj.getData()
  data = parseJSON(obj.getData())
  m.code = data.code
  m.label.text = m.code
  m.shouldCheckCodeMatch = true
  checkCodeMatch()
end sub

sub checkCodeMatch()
  if m.shouldCheckCodeMatch = true
    sleep(3000)
    m.httpTask = createObject("roSGNode", "HttpTask")
    m.httpTask.observeField("response", "onCheckCodeMatchResponse")
    m.httpTask.url = ("/oauth2/oob/code/" + m.code)
    m.httpTask.control = "RUN"
  end if
end sub

sub onCheckCodeMatchResponse(obj)
  ' ? "onCheckCodeMatchResponse "; obj.getData()
  data = parseJSON(obj.getData())
  token = data.oauth_token

  if token <> invalid
    m.top.token = token
  else
    checkCodeMatch()
  end if
end sub

function onKeyEvent(key, press)
  if m.top.visible and press
    if key = "back"
      m.shouldCheckCodeMatch = false
      m.top.showExitAppDialog = true
      return true
    end if

    return false
  end if

  return false
end function
