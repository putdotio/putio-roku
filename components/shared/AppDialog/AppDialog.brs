sub init()
    initAppDialog()
end sub

sub initAppDialog()
    m.top.focusable = true
    m.scrim = m.top.findNode("scrim")
    m.panelGroup = m.top.findNode("panelGroup")
    m.panelShadow = m.top.findNode("panelShadow")
    m.panel = m.top.findNode("panel")
    m.panelBorderTop = m.top.findNode("panelBorderTop")
    m.panelBorderRight = m.top.findNode("panelBorderRight")
    m.panelBorderBottom = m.top.findNode("panelBorderBottom")
    m.panelBorderLeft = m.top.findNode("panelBorderLeft")
    m.titleLabel = m.top.findNode("titleLabel")
    m.divider = m.top.findNode("divider")
    m.messageLabels = [
        m.top.findNode("messageLine0"),
        m.top.findNode("messageLine1"),
        m.top.findNode("messageLine2"),
    ]
    m.buttonsGroup = m.top.findNode("buttonsGroup")
    m.buttonNodes = [
        {
            node: m.top.findNode("button0"),
            background: m.top.findNode("button0Background"),
            label: m.top.findNode("button0Label"),
        },
        {
            node: m.top.findNode("button1"),
            background: m.top.findNode("button1Background"),
            label: m.top.findNode("button1Label"),
        },
    ]
    m.focusIndex = 0
    applyDialogScrim(m.scrim)
    applyDialogPanelColors(m.panel, m.panelShadow, m.panelBorderTop, m.panelBorderRight, m.panelBorderBottom, m.panelBorderLeft)
    applyDialogTextColors(m.titleLabel, invalid)
    setDialogNodeColor(m.divider, "border")
    for each label in m.messageLabels
        setDialogNodeColor(label, "textMuted")
    end for
    updateDialogContent()
    updateDialogButtons()
end sub

sub onDialogContentChange()
    updateDialogContent()
end sub

sub onButtonsChange()
    updateDialogButtons()
end sub

sub onDefaultButtonChange()
    updateDialogButtons()
end sub

sub onFocusedButtonChange()
    m.focusIndex = m.top.focusedButton
    updateDialogButtonFocus()
end sub

sub onCloseChange()
    if m.top.close = true
        closeAppDialog()
    end if
end sub

sub updateDialogContent()
    if m.titleLabel = invalid
        return
    end if

    m.titleLabel.text = m.top.title
    updateDialogButtons()
end sub

sub updateDialogButtons()
    if m.buttonNodes = invalid
        return
    end if

    buttons = m.top.buttons
    if buttons = invalid or buttons.count() = 0
        buttons = ["OK"]
    end if

    maxButtons = m.buttonNodes.count()
    visibleButtonCount = buttons.count()
    if visibleButtonCount > maxButtons
        visibleButtonCount = maxButtons
    end if

    m.focusIndex = m.top.defaultButton
    if m.focusIndex < 0 or m.focusIndex >= visibleButtonCount
        m.focusIndex = 0
    end if
    m.top.focusedButton = m.focusIndex

    for i = 0 to maxButtons - 1
        button = m.buttonNodes[i]
        if i < visibleButtonCount
            button.node.visible = true
            button.label.text = buttons[i]
        else
            button.node.visible = false
            button.label.text = ""
        end if
    end for

    updateDialogLayout(visibleButtonCount)
    updateDialogButtonFocus()
end sub

sub updateDialogLayout(buttonCount as integer)
    rowHeight = 76
    rowGap = 16
    topPadding = 52
    titleHeight = 44
    titleBodyGap = 48
    bodyButtonGap = 56
    titleButtonGap = 40
    bottomPadding = 52
    hasMessage = m.top.message <> ""
    bodyY = topPadding + titleHeight + titleBodyGap

    if hasMessage
        if Len(m.top.message) > 34
            panelWidth = 1040
            contentWidth = 936
            messageLineLength = 40
        else
            panelWidth = 900
            contentWidth = 804
            messageLineLength = 34
        end if

        messageLines = wrapAppDialogMessageLines(m.top.message, messageLineLength)
        messageLineCount = messageLines.count()
        messageHeight = (messageLineCount * 44) + ((messageLineCount - 1) * 4)
        buttonsY = bodyY + messageHeight + bodyButtonGap
    else
        panelWidth = 900
        contentWidth = 804
        messageLines = []
        buttonsY = topPadding + titleHeight + titleButtonGap
    end if

    panelHeight = buttonsY + (buttonCount * rowHeight) + bottomPadding
    if buttonCount > 1
        panelHeight = panelHeight + ((buttonCount - 1) * rowGap)
    end if

    panelX = Int((1920 - panelWidth) / 2)
    panelY = Int((1080 - panelHeight) / 2)

    m.panel.width = panelWidth
    m.panel.height = panelHeight
    m.panelShadow.width = panelWidth
    m.panelShadow.height = panelHeight
    m.panelBorderTop.width = panelWidth
    m.panelBorderRight.translation = [panelWidth - 1, 0]
    m.panelBorderRight.height = panelHeight
    m.panelBorderBottom.translation = [0, panelHeight - 1]
    m.panelBorderBottom.width = panelWidth
    m.panelBorderLeft.height = panelHeight
    m.panelGroup.translation = [panelX, panelY]
    m.titleLabel.translation = [48, topPadding]
    m.titleLabel.width = contentWidth
    updateDialogMessageLabels(messageLines, contentWidth, bodyY)
    m.buttonsGroup.translation = [48, buttonsY]

    for i = 0 to m.buttonNodes.count() - 1
        button = m.buttonNodes[i]
        button.node.translation = [0, i * (rowHeight + rowGap)]
        button.background.width = contentWidth
        button.background.height = rowHeight
        button.label.width = contentWidth
        button.label.height = rowHeight
    end for
end sub

sub updateDialogButtonFocus()
    if m.buttonNodes = invalid
        return
    end if

    for i = 0 to m.buttonNodes.count() - 1
        button = m.buttonNodes[i]
        focused = button.node.visible and i = m.focusIndex
        button.background.visible = button.node.visible

        if i = 0
            if focused
                setDialogNodeColor(button.background, "primary")
            else
                setDialogNodeColor(button.background, "primaryPressed")
            end if
            button.label.color = dialogPrimaryButtonTextColor()
        else
            if focused
                setDialogNodeColor(button.background, "focus")
                button.label.color = dialogSecondaryButtonTextColor()
            else
                setDialogNodeColor(button.background, "secondary")
                button.label.color = dialogSecondaryButtonTextColor()
            end if
        end if
    end for
end sub

sub closeAppDialog()
    m.top.visible = false
    m.top.wasClosed = true
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if press = false or m.top.visible = false
        return false
    end if

    normalizedKey = LCase(key)

    if normalizedKey = "back"
        closeAppDialog()
        return true
    else if normalizedKey = "up" or normalizedKey = "down"
        buttonCount = getVisibleDialogButtonCount()
        if buttonCount > 1
            if m.focusIndex = 0
                m.focusIndex = 1
            else
                m.focusIndex = 0
            end if
            m.top.focusedButton = m.focusIndex
            updateDialogButtonFocus()
        end if
        return true
    else if normalizedKey = "ok" or normalizedKey = "select"
        m.top.buttonSelected = m.focusIndex
        closeAppDialog()
        return true
    end if

    return true
end function

sub updateDialogMessageLabels(lines as object, contentWidth as integer, bodyY as integer)
    for i = 0 to m.messageLabels.count() - 1
        label = m.messageLabels[i]
        label.width = contentWidth
        label.height = 44
        label.translation = [48, bodyY + (i * 48)]

        if i < lines.count()
            label.text = lines[i]
            label.visible = true
        else
            label.text = ""
            label.visible = false
        end if
    end for
end sub

function wrapAppDialogMessageLines(message as string, maxLineLength as integer) as object
    lines = []

    if message = invalid or message = ""
        return lines
    end if

    remaining = message

    while Len(remaining) > maxLineLength and lines.count() < 2
        wrapIndex = maxLineLength

        for i = maxLineLength to 1 step -1
            if Mid(remaining, i, 1) = " "
                wrapIndex = i
                exit for
            end if
        end for

        if wrapIndex < 24
            wrapIndex = maxLineLength
        end if

        lines.push(Left(remaining, wrapIndex - 1))
        remaining = Mid(remaining, wrapIndex + 1)
    end while

    lines.push(remaining)

    return lines
end function

function getVisibleDialogButtonCount() as integer
    count = 0

    for i = 0 to m.buttonNodes.count() - 1
        if m.buttonNodes[i].node.visible
            count = count + 1
        end if
    end for

    return count
end function
