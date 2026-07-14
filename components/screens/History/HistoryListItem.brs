function init()
    ensureHistoryListItemNodes()
end function

sub ensureHistoryListItemNodes()
    if m.focusBackground = invalid
        m.focusBackground = m.top.findNode("focusBackground")
        m.icon = m.top.findNode("icon")
        m.title = m.top.findNode("title")
        m.description = m.top.findNode("description")
        m.spinner = m.top.findNode("spinner")
        m.spinnerAnimation = m.top.FindNode("spinnerAnimation")
        setDialogNodeColor(m.title, "text")
        setDialogNodeColor(m.description, "textMuted")
    end if

    applyListItemFocusBackground(m.focusBackground)
end sub

sub itemContentChanged()
    ensureHistoryListItemNodes()
    if m.top.itemContent = invalid
        return
    end if

    event = m.top.itemContent.event
    isLoading = m.top.itemContent.isLoading
    contentMap = GetMapFromHistoryEventType(event.type)
    configureLayout()
    m.title.text = contentMap.title(event)
    m.description.text = contentMap.description(event)
    if contentMap.icon <> invalid
        iconFolderPath = "pkg:/images/icons/"
        m.icon.uri = iconFolderPath + contentMap.icon + ".png" 'iconFileName
    end if
    applyListItemLoading(m.spinner, m.spinnerAnimation, isLoading)
end sub

sub updateFocus()
    ensureHistoryListItemNodes()
    if m.focusBackground <> invalid
        m.focusBackground.visible = false
    end if
end sub

sub configureLayout()
    ensureHistoryListItemNodes()

    rowWidth = normalizeListItemRowWidth(m.top.itemContent.rowWidth)
    applyListItemFocusBackground(m.focusBackground, rowWidth)

    m.title.width = listItemMainTextWidth(rowWidth)
end sub
