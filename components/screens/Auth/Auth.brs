function init()
    m.top.focusable = true
    m.top.observeField("visible", "onVisibleChange")

    m.descriptionLabel = m.top.findNode("description")
    m.codeLabel = m.top.findNode("code")
    m.codeTiles = m.top.findNode("codeTiles")
    m.codeChars = []
    for i = 0 to 5
        m.codeChars.push(m.top.findNode("codeChar" + i.toStr()))
    end for
    m.stepsLabel = m.top.findNode("stepsLabel")
    m.linkLabel = m.top.findNode("linkLabel")
    m.messageLabel = m.top.findNode("message")
    m.refreshButtonBackground = m.top.findNode("refreshButtonBackground")
    m.refreshButtonLabel = m.top.findNode("refreshButtonLabel")
    m.code = ""
    m.isCodeLoading = false
    applyAuthColors()

    m.timer = createObject("roSGNode", "Timer")
    m.timer.duration = 2
    m.timer.observeField("fire", "onTimerFired")
end function

sub applyAuthColors()
    setDialogNodeColor(m.descriptionLabel, "text")
    setDialogNodeColor(m.codeLabel, "text")
    setDialogNodeColor(m.stepsLabel, "textMuted")
    setDialogNodeColor(m.linkLabel, "primary")
    setDialogNodeColor(m.messageLabel, "textMuted")
    setDialogNodeColor(m.refreshButtonLabel, "text")

    for each codeChar in m.codeChars
        setDialogNodeColor(codeChar, "textInverse")
    end for
end sub

sub onVisibleChange()
    if m.top.visible
        m.top.setFocus(true)
        getAuthCode()
    end if
end sub

sub getAuthCode()
    if m.isCodeLoading
        return
    end if

    deviceInfo = createObject("roDeviceInfo")
    m.isCodeLoading = true
    m.code = ""
    m.timer.control = "stop"
    m.codeLabel.text = "Loading..."
    m.codeLabel.visible = true
    m.codeTiles.visible = false
    m.messageLabel.text = ""
    m.messageLabel.visible = false
    m.messageLabel.height = 0
    setRefreshButtonLoading(true)
    m.getCodeTask = createObject("roSGNode", "HttpTask")
    m.getCodeTask.observeField("response", "onAuthCodeResponse")
    m.getCodeTask.url = "/oauth2/oob/code?app_id=" + m.global.appId + "&client_name=" + deviceInfo.getFriendlyName().EncodeUri()
    m.getCodeTask.control = "RUN"
end sub

sub onAuthCodeResponse(obj)
    m.getCodeTask.unobserveField("response")
    m.isCodeLoading = false
    setRefreshButtonLoading(false)
    data = parseJSON(obj.getData())

    if data <> invalid and data.code <> invalid
        m.code = data.code
        m.codeLabel.text = data.code
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

sub setRefreshButtonLoading(isLoading as boolean)
    if m.refreshButtonLabel <> invalid
        if isLoading
            m.refreshButtonLabel.text = "Getting code..."
        else
            m.refreshButtonLabel.text = "Get new code"
        end if
    end if

    setRefreshButtonBackgroundColor(isLoading)
end sub

sub setRefreshButtonBackgroundColor(isLoading as boolean)
    if m.refreshButtonBackground = invalid
        return
    end if

    if isLoading
        m.refreshButtonBackground.uri = "pkg:/images/auth-refresh-button-loading.png"
    else
        m.refreshButtonBackground.uri = "pkg:/images/auth-refresh-button.png"
    end if
end sub

sub onTimerFired()
    checkCodeMatch()
end sub

sub checkCodeMatch()
    if m.code = ""
        return
    end if

    m.checkCodeTask = createObject("roSGNode", "HttpTask")
    m.checkCodeTask.observeField("response", "onCheckCodeMatchResponse")
    m.checkCodeTask.url = ("/oauth2/oob/code/" + m.code)
    m.checkCodeTask.control = "RUN"
end sub

sub onCheckCodeMatchResponse(obj)
    m.checkCodeTask.unobserveField("response")
    data = parseJSON(obj.getData())

    if data <> invalid and data.oauth_token <> invalid
        m.top.token = data.oauth_token
    else
        m.timer.control = "start"
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if shouldTrapModalInput(m.top)
        return true
    end if

    if m.top.visible and press
        normalizedKey = normalizeKey(key)

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
