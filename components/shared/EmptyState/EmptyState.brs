function init()
    m.layout = m.top.findNode("layout")
    m.heading = m.top.findNode("heading")
    m.body = m.top.findNode("body")

    setDialogLabelColor(m.heading, "text")
    setDialogLabelColor(m.body, "textMuted")

    render()
end function

sub render()
    width = m.top.contentWidth
    if width = invalid or width <= 0
        width = 900
    end if

    m.layout.itemSpacings = [16]
    m.heading.width = width
    m.heading.text = m.top.headingText

    bodyText = m.top.bodyText
    if bodyText = invalid
        bodyText = ""
    end if

    m.body.width = width
    m.body.text = bodyText
    m.body.visible = bodyText <> ""
end sub
