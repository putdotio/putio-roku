sub init()
    title = m.top.findNode("title")
    setDialogNodeColor(title, "text")
    applyTypography(title, "h2")
end sub

sub itemContentChanged()
    if m.top.itemContent = invalid
        return
    end if

    title = m.top.findNode("title")
    title.text = m.top.itemContent.title
end sub
