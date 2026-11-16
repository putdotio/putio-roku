function init()
    m.top.focusable = true
    m.top.observeField("visible", "onVisibleChange")

    m.background = m.top.findNode("background")
    m.title = m.top.findNode("title")
    m.stageReel = m.top.findNode("stageReel")
    m.stageSlide = m.top.findNode("stageSlide")
    m.stageSlideInterpolator = m.top.findNode("stageSlideInterpolator")
    m.phoneTitle = m.top.findNode("phoneTitle")
    m.phoneCaption = m.top.findNode("phoneCaption")
    m.qrCard = m.top.findNode("qrCard")
    m.qrCardBackground = m.top.findNode("qrCardBackground")
    m.qrCode = m.top.findNode("qrCode")
    m.dividerTop = m.top.findNode("dividerTop")
    m.dividerBottom = m.top.findNode("dividerBottom")
    m.orLabel = m.top.findNode("orLabel")
    m.browserColumn = m.top.findNode("browserColumn")
    m.browserTitle = m.top.findNode("browserTitle")
    m.instructionLead = m.top.findNode("instructionLead")
    m.instructionUrl = m.top.findNode("instructionUrl")
    m.instructionTail = m.top.findNode("instructionTail")
    m.statusSpinner = m.top.findNode("statusSpinner")
    m.statusLabel = m.top.findNode("statusLabel")
    m.spinnerSpin = m.top.findNode("spinnerSpin")
    m.codeTiles = m.top.findNode("codeTiles")
    m.newCodeBackground = m.top.findNode("newCodeBackground")
    m.newCodeIcon = m.top.findNode("newCodeIcon")
    m.newCodeLabel = m.top.findNode("newCodeLabel")

    m.code = ""
    m.qrUri = ""
    m.phase = "requesting"
    m.failureMessage = ""
    m.isPreview = false
    m.stageIndex = 0

    buildStageReel()
    buildCodeTiles()
    applyAuthStyle()

    m.qrCode.observeField("loadStatus", "onQrLoadStatus")
    m.stageSlide.observeField("state", "onStageSlideState")

    m.pollTimer = createObject("roSGNode", "Timer")
    m.pollTimer.duration = 2
    m.pollTimer.observeField("fire", "onPollTimerFired")

    m.stageTimer = createObject("roSGNode", "Timer")
    m.stageTimer.duration = 3
    m.stageTimer.repeat = true
    m.stageTimer.observeField("fire", "onStageTimerFired")

    renderPhase()
end function

function authStageFrames() as object
    return [
        { kaomoji: "fetch", caption: "Your files, in the cloud." },
        { kaomoji: "stream", caption: "Stream them on your TV." },
        { kaomoji: "offline", caption: "Pick up where you left off." },
    ]
end function

function authStageFrameHeight() as integer
    return 132
end function

sub buildStageReel()
    frames = authStageFrames()
    frames.push(frames[0])
    for i = 0 to frames.count() - 1
        frame = createObject("roSGNode", "Group")
        frame.translation = [0, i * authStageFrameHeight()]

        kaomoji = frame.createChild("Poster")
        kaomoji.width = 960
        kaomoji.height = 96
        kaomoji.uri = "pkg:/images/auth/auth-kaomoji-" + frames[i].kaomoji + ".png"
        setDialogNodeColor(kaomoji, "text")

        caption = frame.createChild("Label")
        caption.translation = [0, 96]
        caption.width = 960
        caption.height = 36
        caption.horizAlign = "center"
        caption.vertAlign = "center"
        caption.text = frames[i].caption
        setDialogNodeColor(caption, "primary")
        applyTypography(caption, "caption")

        m.stageReel.appendChild(frame)
    end for
end sub

sub buildCodeTiles()
    m.codeChars = []
    for i = 0 to 5
        tile = m.codeTiles.createChild("Group")

        background = tile.createChild("Poster")
        background.width = 96
        background.height = 120
        background.uri = "pkg:/images/auth/auth-rounded-18.9.png"
        setDialogNodeColor(background, "focus")

        character = tile.createChild("Label")
        character.id = "codeChar" + i.toStr()
        character.width = 96
        character.height = 120
        character.horizAlign = "center"
        character.vertAlign = "center"
        character.font = authFont("medium", 60, "h1")
        m.codeChars.push(character)
    end for
end sub

function authFont(face as string, size as integer, fallbackRole as string) as object
    if buildConfigBrandFontsAvailable()
        font = createObject("roSGNode", "Font")
        font.uri = brandFontUri(face)
        font.size = size
        return font
    end if

    return typographyRoles()[fallbackRole].system
end function

sub applyAuthStyle()
    setDialogNodeColor(m.background, "appBackground")
    setDialogNodeColor(m.title, "text")
    setDialogNodeColor(m.phoneTitle, "text")
    setDialogNodeColor(m.browserTitle, "text")
    setDialogNodeColor(m.phoneCaption, "textMuted")
    setDialogNodeColor(m.instructionLead, "textMuted")
    setDialogNodeColor(m.instructionUrl, "primary")
    setDialogNodeColor(m.instructionTail, "textMuted")
    setDialogNodeColor(m.orLabel, "textMuted")
    setDialogNodeColor(m.dividerTop, "border")
    setDialogNodeColor(m.dividerBottom, "border")
    setDialogNodeColor(m.qrCardBackground, "textOnVideo")
    setDialogNodeColor(m.statusSpinner, "textMuted")

    m.title.font = authFont("medium", 51, "h1")
    columnTitleFont = authFont("medium", 30, "label")
    m.phoneTitle.font = columnTitleFont
    m.browserTitle.font = columnTitleFont
    applyTypography(m.phoneCaption, "caption")
    applyTypography(m.instructionLead, "caption")
    applyTypography(m.instructionTail, "caption")
    applyTypography(m.statusLabel, "caption")
    applyTypography(m.orLabel, "caption")
    m.instructionUrl.font = authFont("medium", 27, "label")
    m.newCodeLabel.font = authFont("medium", 27, "label")
end sub

sub onVisibleChange()
    if m.top.visible
        m.top.setFocus(true)
        if not m.isPreview
            m.stageTimer.control = "start"
            getAuthCode()
        end if
    else
        stopAuthTimers()
    end if
end sub

sub stopAuthTimers()
    m.pollTimer.control = "stop"
    m.stageTimer.control = "stop"
    m.spinnerSpin.control = "stop"
end sub

sub onPreviewChange()
    preview = m.top.preview
    if preview = invalid
        return
    end if

    m.isPreview = true
    stopAuthTimers()
    m.phase = preview.phase
    m.code = ""
    if preview.code <> invalid
        m.code = preview.code
    end if
    m.failureMessage = ""
    if preview.failureMessage <> invalid
        m.failureMessage = preview.failureMessage
    end if
    setQrUri("")
    if preview.qrUri <> invalid
        setQrUri(preview.qrUri)
    end if
    renderPhase()
end sub

sub getAuthCode()
    if m.phase = "requesting" and m.getCodeTask <> invalid
        return
    end if

    m.pollTimer.control = "stop"
    if m.checkCodeTask <> invalid
        m.checkCodeTask.unobserveField("response")
        m.checkCodeTask = invalid
    end if

    m.phase = "requesting"
    m.code = ""
    setQrUri("")
    renderPhase()

    deviceInfo = createObject("roDeviceInfo")
    m.getCodeTask = createObject("roSGNode", "HttpTask")
    m.getCodeTask.observeField("response", "onAuthCodeResponse")
    m.getCodeTask.url = "/oauth2/oob/code?app_id=" + m.global.appId + "&client_name=" + deviceInfo.getFriendlyName().EncodeUri()
    m.getCodeTask.control = "RUN"
end sub

sub onAuthCodeResponse(obj)
    m.getCodeTask.unobserveField("response")
    m.getCodeTask = invalid
    data = parseJSON(obj.getData())

    if data <> invalid and data.code <> invalid
        m.code = data.code
        m.phase = "awaiting"
        if data.qr_code_url <> invalid
            setQrUri(data.qr_code_url)
        end if
        renderPhase()
        checkCodeMatch()
    else
        m.phase = "failed"
        if data <> invalid and data.error_type <> invalid and data.error_type = "NETWORK_ERROR"
            m.failureMessage = "Can’t connect to put.io right now. Check the network, then get a new code."
        else
            m.failureMessage = "put.io couldn’t issue a code right now. Try again in a moment."
        end if
        renderPhase()
    end if
end sub

sub setQrUri(uri as string)
    m.qrUri = uri
    m.qrCode.visible = false
    m.qrCode.uri = uri
end sub

sub onQrLoadStatus()
    m.qrCode.visible = m.qrUri <> "" and m.qrCode.loadStatus = "ready"
end sub

sub renderPhase()
    dimmed = m.phase <> "awaiting"
    if dimmed
        m.qrCard.opacity = 0.35
    else
        m.qrCard.opacity = 1.0
    end if

    for i = 0 to m.codeChars.count() - 1
        if i < m.code.len()
            m.codeChars[i].text = m.code.mid(i, 1)
        else
            m.codeChars[i].text = ""
        end if
        if dimmed
            setDialogNodeColor(m.codeChars[i], "textMuted")
        else
            setDialogNodeColor(m.codeChars[i], "text")
        end if
    end for

    renderStatus()
    renderNewCodeButton(m.phase <> "requesting")
end sub

sub renderStatus()
    waiting = m.phase = "requesting" or m.phase = "awaiting"
    m.statusSpinner.visible = waiting
    if waiting and not m.isPreview
        m.spinnerSpin.control = "start"
    else
        m.spinnerSpin.control = "stop"
    end if

    if m.phase = "requesting"
        setStatusText("Getting a code", "textMuted", false)
    else if m.phase = "awaiting"
        setStatusText("Waiting for authentication…", "textMuted", false)
    else if m.phase = "expired"
        setStatusText("This code expired.", "text", false)
    else
        setStatusText(m.failureMessage, "text", true)
    end if
end sub

sub setStatusText(text as string, colorName as string, wraps as boolean)
    m.statusLabel.wrap = wraps
    if wraps
        m.statusLabel.width = 720
    else
        m.statusLabel.width = 0
    end if
    m.statusLabel.text = text
    setDialogNodeColor(m.statusLabel, colorName)
end sub

sub renderNewCodeButton(enabled as boolean)
    m.newCodeBackground.visible = enabled
    if enabled
        setDialogNodeColor(m.newCodeBackground, "text")
        setDialogNodeColor(m.newCodeLabel, "appBackground")
        setDialogNodeColor(m.newCodeIcon, "appBackground")
    else
        setDialogNodeColor(m.newCodeLabel, "disabledText")
        setDialogNodeColor(m.newCodeIcon, "disabledText")
    end if
end sub

sub onPollTimerFired()
    checkCodeMatch()
end sub

sub checkCodeMatch()
    if m.code = "" or m.phase <> "awaiting"
        return
    end if

    m.checkCodeTask = createObject("roSGNode", "HttpTask")
    m.checkCodeTask.observeField("response", "onCheckCodeMatchResponse")
    m.checkCodeTask.url = ("/oauth2/oob/code/" + m.code)
    m.checkCodeTask.control = "RUN"
end sub

sub onCheckCodeMatchResponse(obj)
    m.checkCodeTask.unobserveField("response")
    m.checkCodeTask = invalid
    data = parseJSON(obj.getData())

    if data <> invalid and data.oauth_token <> invalid
        m.top.token = data.oauth_token
    else if data <> invalid and data.status_code <> invalid and data.status_code = 404
        m.phase = "expired"
        setQrUri("")
        renderPhase()
    else if m.top.visible
        m.pollTimer.control = "start"
    end if
end sub

sub onStageTimerFired()
    m.stageIndex = m.stageIndex + 1
    height = authStageFrameHeight()
    m.stageSlideInterpolator.keyValue = [[0, - (m.stageIndex - 1) * height], [0, -m.stageIndex * height]]
    m.stageSlide.control = "start"
end sub

sub onStageSlideState()
    if m.stageSlide.state = "stopped" and m.stageIndex >= authStageFrames().count()
        m.stageIndex = 0
        m.stageReel.translation = [0, 0]
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
            if not m.isPreview
                getAuthCode()
            end if
            return true
        else if isOptionsKey(normalizedKey)
            return true
        end if
    end if

    return false
end function
