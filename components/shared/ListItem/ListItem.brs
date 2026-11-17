function init()
    ensureListItemNodes()
end function

sub ensureListItemNodes()
    if m.focusBackground = invalid
        m.focusBackground = m.top.findNode("focusBackground")
        m.icon = m.top.findNode("icon")
        m.title = m.top.findNode("title")
        m.description = m.top.findNode("description")
        m.hint = m.top.findNode("hint")
        m.value = m.top.findNode("value")
        m.toggle = m.top.findNode("toggle")
        applyListItemFocusBackground(m.focusBackground)
        setDialogNodeColor(m.title, "text")
        setDialogNodeColor(m.description, "textMuted")
        setDialogNodeColor(m.value, "textMuted")
        setDialogNodeColor(m.hint, "textMuted")
        applyTypography(m.title, "h2")
        applyTypography(m.description, "small")
        applyTypography(m.value, "small")
        applyTypography(m.hint, "caption")
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
    configureHint()
    fitValueToTitle()
    configureToggle()
end sub

sub configureToggle()
    toggle = m.top.itemContent.toggle
    if toggle <> "on" and toggle <> "off"
        m.toggle.visible = false
        return
    end if

    rowWidth = normalizeListItemRowWidth(m.top.itemContent.rowWidth)
    toggleY = uiSnap(Int((uiListRowHeight() - m.toggle.height) / 2))
    m.toggle.translation = [rowWidth - 48 - m.toggle.width, toggleY]
    m.toggle.uri = "pkg:/images/generated/switch-" + toggle + ".png"
    m.value.visible = false
    m.toggle.visible = true
end sub

sub configureLayout()
    ensureListItemNodes()

    rowWidth = normalizeListItemRowWidth(m.top.itemContent.rowWidth)

    applyListItemFocusBackground(m.focusBackground, rowWidth)

    valueWidth = 520
    if hasListItemHint()
        valueWidth = 264
    end if
    valueX = rowWidth - valueWidth - 48
    if valueX < 520
        valueX = 520
        valueWidth = rowWidth - valueX - 48
    end if
    m.value.translation = [valueX, 0]
    m.value.width = valueWidth

    inlineContent = m.top.findNode("inlineContent")
    textX = Int(inlineContent.translation[0] + m.icon.width + inlineContent.itemSpacings[0])
    hintGap = 36
    m.hint.width = valueX - textX - hintGap
end sub

sub fitValueToTitle()
    if hasListItemHint()
        return
    end if

    rowWidth = normalizeListItemRowWidth(m.top.itemContent.rowWidth)
    inlineContent = m.top.findNode("inlineContent")
    textX = Int(inlineContent.translation[0] + m.icon.width + inlineContent.itemSpacings[0])
    valueGap = 36
    valueX = textX + Int(m.title.boundingRect().width) + valueGap
    m.value.translation = [valueX, 0]
    m.value.width = rowWidth - valueX - 48
end sub

function hasListItemHint() as boolean
    hint = m.top.itemContent.hint
    return hint <> invalid and hint <> ""
end function

sub configureHint()
    ensureListItemNodes()

    ' A LayoutGroup still sizes a hidden empty Label, which lifts a hint-less title off
    ' the row's center, so the hint joins the text group only when there is one.
    textContent = m.top.findNode("textContent")
    if hasListItemHint()
        m.hint.text = m.top.itemContent.hint
        m.hint.visible = true
        if textContent.getChildCount() < 2
            textContent.appendChild(m.hint)
        end if
    else
        m.hint.text = ""
        m.hint.visible = false
        if textContent.getChildCount() > 1
            textContent.removeChild(m.hint)
        end if
    end if
end sub

sub configureIcon()
    ensureListItemNodes()
    m.icon.uri = "pkg:/images/icons/" + m.top.itemContent.iconName + ".png"

    iconColor = m.top.itemContent.iconColor
    if iconColor = invalid or iconColor = ""
        iconColor = "primary"
    end if
    setDialogNodeColor(m.icon, iconColor)
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
