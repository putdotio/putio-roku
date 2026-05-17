sub init()
    m.top.focusable = true
    m.focusIndex = 0
    m.continueBackground = m.top.findNode("continueBackground")
    m.beginningBackground = m.top.findNode("beginningBackground")
    m.continueLabel = m.top.findNode("continueLabel")
    m.beginningLabel = m.top.findNode("beginningLabel")
    m.title = m.top.findNode("title")
    m.progressElapsed = m.top.findNode("progressElapsed")
    updateLabels()
    updateFocus()
end sub

sub updateLabels()
    startFromLabel = getDurationString(m.top.startFrom)

    if m.top.fileName <> invalid and m.top.fileName <> ""
        m.title.text = m.top.fileName
    else
        m.title.text = "Continue playing"
    end if

    m.continueLabel.text = "Continue playing from " + startFromLabel
    updateProgress()
end sub

sub updateProgress()
    progressWidth = 0

    if m.top.duration > 0 and m.top.startFrom > 0
        progressWidth = fix((m.top.startFrom / m.top.duration) * 688)
    end if

    if progressWidth < 0
        progressWidth = 0
    else if progressWidth > 688
        progressWidth = 688
    end if

    m.progressElapsed.width = progressWidth
end sub

sub updateFocus()
    if m.focusIndex = 0
        m.continueBackground.color = "0x3A3A3AFF"
        m.beginningBackground.color = "0x14141400"
        m.continueLabel.color = "0xFFFFFFFF"
        m.beginningLabel.color = "0xD6D6D6FF"
    else
        m.continueBackground.color = "0x14141400"
        m.beginningBackground.color = "0x3A3A3AFF"
        m.continueLabel.color = "0xD6D6D6FF"
        m.beginningLabel.color = "0xFFFFFFFF"
    end if
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
