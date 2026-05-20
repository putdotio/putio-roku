function init()
    ensureListItemNodes()
end function

sub ensureListItemNodes()
    if m.focusBackground = invalid
        m.focusBackground = m.top.findNode("focusBackground")
        m.icon = m.top.findNode("icon")
        m.title = m.top.findNode("title")
        m.description = m.top.findNode("description")
        m.value = m.top.findNode("value")
        applyListItemFocusBackground(m.focusBackground)
    end if
end sub

sub itemContentChanged()
    ensureListItemNodes()
    if m.top.itemContent = invalid
        return
    end if

    configureLayout()
    configureIcon()
    configureTitle()
    configureDescription()
end sub

sub configureLayout()
    ensureListItemNodes()

    rowWidth = normalizeListItemRowWidth(m.top.itemContent.rowWidth)

    applyListItemFocusBackground(m.focusBackground, rowWidth)

    valueWidth = 520
    valueX = rowWidth - valueWidth - 48
    if valueX < 520
        valueX = 520
        valueWidth = rowWidth - valueX - 48
    end if
    m.value.translation = [valueX, 0]
    m.value.width = valueWidth
end sub

sub configureIcon()
    ensureListItemNodes()
    m.icon.uri = "pkg:/images/icons/" + m.top.itemContent.iconName + ".png"
end sub

sub configureTitle()
    ensureListItemNodes()
    m.title.text = m.top.itemContent.title
end sub

sub configureDescription()
    ensureListItemNodes()

    description = ""
    if m.top.itemContent.description <> invalid
        description = m.top.itemContent.description
    end if

    if m.top.itemContent.valueAlign = "right"
        m.description.text = ""
        m.description.visible = false
        m.value.text = description
        m.value.visible = true
    else
        m.description.text = description
        m.description.visible = true
        m.value.text = ""
        m.value.visible = false
    end if
end sub

sub updateFocus()
    ensureListItemNodes()
    if m.focusBackground <> invalid
        m.focusBackground.visible = false
    end if
end sub
