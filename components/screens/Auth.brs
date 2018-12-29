function init()
  m.top.token = ""
  m.top.observeField("visible", "onVisibleChange")
end function

sub onVisibleChange()
  m.code = ""
  m.label = m.top.findNode("code")

  if m.top.visible
    getAuthCode()
  end if
end sub

sub getAuthCode()
  m.httpTask = createObject("roSGNode", "HttpTask")
  m.httpTask.observeField("response", "onAuthCodeResponse")
  m.httpTask.url = "/oauth2/oob/code?app_id=961" ' @TODO: app id
  m.httpTask.control = "RUN"
end sub

sub onAuthCodeResponse(obj)
  ' ? "onAuthCodeResponse "; obj.getData()
  data = parseJSON(obj.getData())
  m.code = data.code
  m.label.text = m.code
  checkCodeMatch()
end sub

sub checkCodeMatch()
  sleep(3000)
  m.httpTask = createObject("roSGNode", "HttpTask")
  m.httpTask.observeField("response", "onCheckCodeMatchResponse")
  m.httpTask.url = ("/oauth2/oob/code/" + m.code)
  m.httpTask.control = "RUN"
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
