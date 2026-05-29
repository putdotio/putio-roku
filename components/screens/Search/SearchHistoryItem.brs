sub init()
    setDialogNodeColor(m.top.findNode("title"), "text")
end sub

sub itemContentChanged()
    if m.top.itemContent = invalid
        return
    end if

    title = m.top.findNode("title")
    title.text = m.top.itemContent.title
end sub
