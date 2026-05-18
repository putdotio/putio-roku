function init()
    m.top.observeField("visible", "onVisibleChange")

    m.codeLabel = m.top.findNode("code")
    m.codeTiles = m.top.findNode("codeTiles")
    m.codeChars = []
    for i = 0 to 5
        m.codeChars.push(m.top.findNode("codeChar" + i.toStr()))
    end for
    m.messageLabel = m.top.findNode("message")
    m.code = ""

    m.timer = createObject("roSGNode", "Timer")
    m.timer.duration = 2
    m.timer.observeField("fire", "onTimerFired")
end function

sub onVisibleChange()
    if m.top.visible
        getAuthCode()
    end if
end sub

sub getAuthCode()
    deviceInfo = createObject("roDeviceInfo")
    m.code = ""
    m.timer.control = "stop"
    m.codeLabel.text = "Loading..."
    m.codeLabel.visible = true
    m.codeTiles.visible = false
    m.messageLabel.text = ""
    m.messageLabel.visible = false
    m.messageLabel.height = 0
    m.getCodeTask = createObject("roSGNode", "HttpTask")
    m.getCodeTask.observeField("response", "onAuthCodeResponse")
    m.getCodeTask.url = "/oauth2/oob/code?app_id=" + m.global.appId + "&client_name=" + deviceInfo.getFriendlyName().EncodeUri()
    m.getCodeTask.control = "RUN"
end sub

sub onAuthCodeResponse(obj)
    m.getCodeTask.unobserveField("response")
    data = parseJSON(obj.getData())

    if data.code <> invalid
        m.code = data.code
        renderAuthCode(data.code)
        checkCodeMatch()
    else
        m.codeLabel.text = "Error!"
        m.codeLabel.visible = true
        m.codeTiles.visible = false
        m.messageLabel.text = "An error occurred while getting the authentication code, please restart the app and try again."
        m.messageLabel.visible = true
        m.messageLabel.height = 72
    end if
end sub

sub renderAuthCode(code as string)
    m.codeLabel.visible = false
    m.codeTiles.visible = true
    m.messageLabel.visible = false
    m.messageLabel.height = 0

    for i = 0 to m.codeChars.count() - 1
        if i < code.len()
            m.codeChars[i].text = code.mid(i, 1)
        else
            m.codeChars[i].text = ""
        end if
    end for
end sub

sub onTimerFired()
    checkCodeMatch()
end sub

sub checkCodeMatch()
    m.checkCodeTask = createObject("roSGNode", "HttpTask")
    m.checkCodeTask.observeField("response", "onCheckCodeMatchResponse")
    m.checkCodeTask.url = ("/oauth2/oob/code/" + m.code)
    m.checkCodeTask.control = "RUN"
end sub

sub onCheckCodeMatchResponse(obj)
    m.checkCodeTask.unobserveField("response")
    data = parseJSON(obj.getData())

    if data.oauth_token <> invalid
        m.top.token = data.oauth_token
    else
        m.timer.control = "start"
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if m.top.visible and press
        normalizedKey = LCase(key)

        if normalizedKey = "back"
            m.top.showExitAppDialog = true
            return true
        else if normalizedKey = "ok" or normalizedKey = "select"
            getAuthCode()
            return true
        else if isOptionsKey(normalizedKey)
            return true
        end if
    end if

    return false
end function
