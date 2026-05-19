sub init()
    m.top.focusable = true
    m.focusIndex = 0
    m.backdrop = m.top.findNode("backdrop")
    m.panelFill = m.top.findNode("panelFill")
    m.panelShadow = m.top.findNode("panelShadow")
    m.panelBorderTop = m.top.findNode("panelBorderTop")
    m.panelBorderRight = m.top.findNode("panelBorderRight")
    m.panelBorderBottom = m.top.findNode("panelBorderBottom")
    m.panelBorderLeft = m.top.findNode("panelBorderLeft")
    m.title = m.top.findNode("title")
    m.divider = m.top.findNode("divider")
    m.continueBackground = m.top.findNode("continueBackground")
    m.beginningBackground = m.top.findNode("beginningBackground")
    m.continueAccent = m.top.findNode("continueAccent")
    m.beginningAccent = m.top.findNode("beginningAccent")
    m.continueLabel = m.top.findNode("continueLabel")
    m.beginningLabel = m.top.findNode("beginningLabel")
    m.fileName = m.top.findNode("fileName")
    m.progressRemaining = m.top.findNode("progressRemaining")
    m.progressElapsed = m.top.findNode("progressElapsed")
    applyDialogScrim(m.backdrop)
    applyDialogPanelColors(m.panelFill, m.panelShadow, m.panelBorderTop, m.panelBorderRight, m.panelBorderBottom, m.panelBorderLeft)
    applyDialogTextColors(m.title, m.fileName)
    setDialogNodeColor(m.divider, "border")
    setDialogNodeColor(m.progressRemaining, "border")
    setDialogNodeColor(m.progressElapsed, "primary")
    updateLabels()
    updateFocus()
end sub

sub updateLabels()
    startFromLabel = getDurationString(m.top.startFrom)

    if m.top.fileName <> invalid and m.top.fileName <> ""
        m.fileName.text = wrapPromptFileName(m.top.fileName)
    else
        m.fileName.text = ""
    end if

    m.continueLabel.text = "Continue playing from " + startFromLabel
    updateProgressPreview()
end sub

sub updateProgressPreview()
    previewStartFrom = getFocusedStartFrom()
    progressWidth = 0
    progressTrackWidth = 724

    if m.top.duration > 0 and previewStartFrom > 0
        progressWidth = fix((previewStartFrom / m.top.duration) * progressTrackWidth)
    end if

    if progressWidth < 0
        progressWidth = 0
    else if progressWidth > progressTrackWidth
        progressWidth = progressTrackWidth
    end if

    m.progressElapsed.width = progressWidth
end sub

function getFocusedStartFrom() as integer
    if m.focusIndex = 0
        return m.top.startFrom
    end if

    return 0
end function

sub onFocusedButtonChange()
    if m.top.focusedButton = invalid
        return
    end if

    if m.top.focusedButton = 1
        m.focusIndex = 1
    else
        m.focusIndex = 0
    end if

    updateFocus()
end sub

function wrapPromptFileName(fileName as string) as string
    maxLineLength = 58
    wrapped = ""

    for i = 1 to Len(fileName)
        char = Mid(fileName, i, 1)
        wrapped = wrapped + char

        if i mod maxLineLength = 0 and i < Len(fileName)
            wrapped = wrapped + Chr(10)
        end if
    end for

    return wrapped
end function

sub updateFocus()
    if m.focusIndex = 0
        m.continueAccent.visible = false
        m.beginningAccent.visible = false
        applyDialogButtonState(m.continueBackground, m.continueLabel, true, "primary")
        applyDialogButtonState(m.beginningBackground, m.beginningLabel, false, "primary")
    else
        m.continueAccent.visible = false
        m.beginningAccent.visible = false
        applyDialogButtonState(m.continueBackground, m.continueLabel, false, "primary")
        applyDialogButtonState(m.beginningBackground, m.beginningLabel, true, "primary")
    end if

    updateProgressPreview()
end sub

sub selectFocusedButton()
    if m.focusIndex = 0
        m.top.selectedStartFrom = m.top.startFrom
    else
        m.top.selectedStartFrom = 0
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if m.top.visible and press
        normalizedKey = LCase(key)

        if normalizedKey = "back"
            m.top.dismissed = true
        else if normalizedKey = "up" or normalizedKey = "down"
            if m.focusIndex = 0
                m.focusIndex = 1
            else
                m.focusIndex = 0
            end if
            m.top.focusedButton = m.focusIndex
            updateFocus()
        else if normalizedKey = "ok" or normalizedKey = "select"
            selectFocusedButton()
        else
            return false
        end if

        return true
    end if

    return false
end function

function getDurationString(seconds as integer) as string
    if seconds < 0
        seconds = 0
    end if

    hours = fix(seconds / 3600)
    minutes = fix((seconds mod 3600) / 60)
    remainingSeconds = seconds mod 60

    minutesText = minutes.toStr()
    secondsText = remainingSeconds.toStr()

    if Len(minutesText) = 1
        minutesText = "0" + minutesText
    end if
    if Len(secondsText) = 1
        secondsText = "0" + secondsText
    end if

    if hours > 0
        return hours.toStr() + ":" + minutesText + ":" + secondsText
    end if

    return minutesText + ":" + secondsText
end function
