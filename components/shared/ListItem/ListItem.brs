function init()
    m.focusBackground = m.top.findNode("focusBackground")
    m.focusBackgroundParts = [
        m.top.findNode("focusBackgroundOuter"),
        m.top.findNode("focusBackgroundWide"),
        m.top.findNode("focusBackgroundMiddle"),
        m.top.findNode("focusBackgroundCore")
    ]
    m.icon = m.top.findNode("icon")
    m.title = m.top.findNode("title")
    m.description = m.top.findNode("description")
    m.value = m.top.findNode("value")
    for each backgroundPart in m.focusBackgroundParts
        setDialogNodeColor(backgroundPart, "focus")
    end for
end function

sub itemContentChanged()
    configureLayout()
    configureIcon()
    configureTitle()
    configureDescription()
end sub

sub configureLayout()
    rowWidth = m.top.itemContent.rowWidth
    if rowWidth <= 0
        rowWidth = 1500
    end if

    m.focusBackgroundParts[0].translation = [24, 0]
    m.focusBackgroundParts[0].width = rowWidth - 48
    m.focusBackgroundParts[1].translation = [12, 6]
    m.focusBackgroundParts[1].width = rowWidth - 24
    m.focusBackgroundParts[2].translation = [6, 12]
    m.focusBackgroundParts[2].width = rowWidth - 12
    m.focusBackgroundParts[3].translation = [0, 24]
    m.focusBackgroundParts[3].width = rowWidth

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
    m.icon.uri = "pkg:/images/icons/" + m.top.itemContent.iconName + ".png"
end sub

sub configureTitle()
    m.title.text = m.top.itemContent.title
end sub

sub configureDescription()
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
    m.focusBackground.visible = m.top.itemHasFocus
end sub
