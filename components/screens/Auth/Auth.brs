function init()
    m.top.observeField("visible", "onVisibleChange")

    m.codeLabel = m.top.findNode("code")
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
        m.codeLabel.text = data.code
        checkCodeMatch()
    else
        m.codeLabel.text = "Error!"
        m.messageLabel.text = "An error occurred while getting the authentication code, please restart the app and try again."
    end if
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

function onKeyEvent(key, press)
    if m.top.visible and press and key = "back"
        m.top.showExitAppDialog = true
        return true
    end if

    return false
end function
