sub itemContentChanged()
    if m.top.itemContent = invalid
        return
    end if

    title = m.top.findNode("title")
    title.text = m.top.itemContent.title
end sub
