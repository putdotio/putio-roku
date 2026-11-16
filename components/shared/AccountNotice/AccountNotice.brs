function init()
    m.panel = m.top.findNode("panel")
    m.accent = m.top.findNode("accent")
    m.title = m.top.findNode("title")
    m.message = m.top.findNode("message")

    setDialogNodeColor(m.panel, "surface")
    setDialogNodeColor(m.accent, "primary")
    setDialogLabelColor(m.title, "text")
    setDialogLabelColor(m.message, "textMuted")
    applyTypography(m.title, "label")
    applyTypography(m.message, "small")

    render()
end function

sub render()
    padding = 30
    accentWidth = 6
    titleHeight = 45
    messageGap = 9
    messageLineHeight = 42

    width = m.top.noticeWidth
    textX = accentWidth + padding
    textWidth = width - textX - padding

    m.title.translation = [textX, padding]
    m.title.width = textWidth
    m.title.height = titleHeight
    m.title.text = m.top.titleText

    message = m.top.messageText
    height = padding + titleHeight + padding
    if message <> ""
        m.message.translation = [textX, padding + titleHeight + messageGap]
        m.message.width = textWidth
        m.message.height = 0
        m.message.text = message
        lines = 1
        if m.message.boundingRect().height > messageLineHeight * 1.5
            lines = 2
        end if
        m.message.height = messageLineHeight * lines
        height = height + messageGap + m.message.height
    end if
    m.message.visible = message <> ""

    height = uiCeilToGrid(height)
    m.panel.width = width
    m.panel.height = height
    m.accent.width = accentWidth
    m.accent.height = height
    m.top.noticeHeight = height
end sub
