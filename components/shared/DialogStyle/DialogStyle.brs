function dialogColor(name as string) as string
    colors = {
        appBackground: "0x161616FF",
        appBackgroundWash: "0x00000000",
        border: "0x343434FF",
        borderHover: "0x505050FF",
        buttonFocus: "0x343434FF",
        buttonSurface: "0x232323FF",
        danger: "0xE5484DFF",
        dangerFocused: "0xF2555AFF",
        disabledText: "0x777777FF",
        focus: "0x2E2E2EFF",
        primary: "0xFDCE45FF",
        primaryPressed: "0xFCBE03FF",
        panelBorder: "0x5A5A5AFF",
        scrim: "0x000000B8",
        secondary: "0x232323FF",
        shadow: "0x00000080",
        surface: "0x202020FF",
        text: "0xEDEDEDFF",
        textInverse: "0x000000FF",
        textMuted: "0xA0A0A0FF",
        transparent: "0x00000000",
    }

    if colors.doesExist(name)
        return colors[name]
    end if

    return colors.text
end function

sub setDialogNodeColor(node, colorName as string)
    if node <> invalid
        if node.hasField("color")
            node.color = dialogColor(colorName)
        else if node.hasField("blendColor")
            node.blendColor = dialogColor(colorName)
        end if
    end if
end sub

sub applyAppOverhangColors(overhang)
    if overhang = invalid
        return
    end if

    if overhang.hasField("backgroundColor")
        overhang.backgroundColor = dialogColor("appBackground")
    end if

    if overhang.hasField("titleColor")
        overhang.titleColor = dialogColor("text")
    end if

    if overhang.hasField("optionsTextColor")
        overhang.optionsTextColor = dialogColor("text")
    end if

    if overhang.hasField("optionsFocusedTextColor")
        overhang.optionsFocusedTextColor = dialogColor("text")
    end if

    if overhang.hasField("optionsIconColor")
        overhang.optionsIconColor = dialogColor("text")
    end if

    if overhang.hasField("optionsFocusedIconColor")
        overhang.optionsFocusedIconColor = dialogColor("text")
    end if

    if overhang.hasField("optionsDimColor")
        overhang.optionsDimColor = dialogColor("transparent")
    end if

    if overhang.hasField("optionsIconDimColor")
        overhang.optionsIconDimColor = dialogColor("transparent")
    end if
end sub

sub applyDialogScrim(scrim)
    setDialogNodeColor(scrim, "scrim")
end sub

sub applyDialogPanelColors(panel, shadow, borderTop, borderRight, borderBottom, borderLeft)
    setDialogNodeColor(panel, "surface")
    setDialogNodeColor(shadow, "shadow")
    setDialogNodeColor(borderTop, "panelBorder")
    setDialogNodeColor(borderRight, "panelBorder")
    setDialogNodeColor(borderBottom, "panelBorder")
    setDialogNodeColor(borderLeft, "panelBorder")
    setDialogNodeVisible(borderTop, true)
    setDialogNodeVisible(borderRight, true)
    setDialogNodeVisible(borderBottom, true)
    setDialogNodeVisible(borderLeft, true)
end sub

sub setDialogNodeVisible(node, visible as boolean)
    if node <> invalid and node.hasField("visible")
        node.visible = visible
    end if
end sub

function defaultListItemRowWidth() as integer
    return 1500
end function

function defaultListItemRowHeight() as integer
    return 120
end function

function normalizeListItemRowHeight(rowHeight) as integer
    if rowHeight = invalid or rowHeight <= 0
        return defaultListItemRowHeight()
    end if

    return rowHeight
end function

function normalizeListItemRowWidth(rowWidth) as integer
    if rowWidth = invalid or rowWidth <= 0
        return defaultListItemRowWidth()
    end if

    return rowWidth
end function

function listItemMainTextWidth(rowWidth) as integer
    textWidth = normalizeListItemRowWidth(rowWidth) - 204
    if textWidth < 400
        return 400
    end if

    return textWidth
end function

sub applyListItemLoading(spinner, spinnerAnimation, isLoading)
    if isLoading = true
        setDialogNodeVisible(spinner, true)
        if spinnerAnimation <> invalid and spinnerAnimation.hasField("control")
            spinnerAnimation.control = "start"
        end if
    else
        setDialogNodeVisible(spinner, false)
        if spinnerAnimation <> invalid and spinnerAnimation.hasField("control")
            spinnerAnimation.control = "stop"
        end if
    end if
end sub

sub applyListItemFocusBackground(background, rowWidth = invalid, rowHeight = invalid)
    if background = invalid
        return
    end if

    width = normalizeListItemRowWidth(rowWidth)
    height = normalizeListItemRowHeight(rowHeight)
    radius = listItemFocusCornerRadius(height)
    insetStep = Int(radius / 2)
    if insetStep < 2
        insetStep = 2
    end if

    top = background.findNode("focusTop")
    upper = background.findNode("focusUpper")
    body = background.findNode("focusBody")
    lower = background.findNode("focusLower")
    bottom = background.findNode("focusBottom")

    if top = invalid or upper = invalid or body = invalid or lower = invalid or bottom = invalid
        setDialogNodeColor(background, "focus")
        return
    end if

    setListItemFocusSlice(top, radius, 0, width - (radius * 2), insetStep)
    setListItemFocusSlice(upper, insetStep, insetStep, width - (insetStep * 2), radius - insetStep)
    setListItemFocusSlice(body, 0, radius, width, height - (radius * 2))
    setListItemFocusSlice(lower, insetStep, height - radius, width - (insetStep * 2), radius - insetStep)
    setListItemFocusSlice(bottom, radius, height - insetStep, width - (radius * 2), insetStep)
end sub

function listItemFocusCornerRadius(height as integer) as integer
    if height < 80
        return 8
    end if

    return 12
end function

sub setListItemFocusSlice(node, x as integer, y as integer, width as integer, height as integer)
    if node = invalid
        return
    end if

    if width < 0
        width = 0
    end if
    if height < 0
        height = 0
    end if

    node.translation = [x, y]
    node.width = width
    node.height = height
    setDialogNodeColor(node, "focus")
end sub

sub applyDialogTextColors(title, body)
    setDialogNodeColor(title, "text")
    setDialogNodeColor(body, "textMuted")
end sub

sub setDialogLabelColor(label, colorName as string)
    if label <> invalid and label.hasField("color")
        label.color = dialogColor(colorName)
    end if
end sub

sub applyDialogButtonState(background, label, focused as boolean, variant as string)
    normalizedVariant = LCase(variant)
    backgroundColor = "transparent"
    labelColor = "text"

    if focused
        if normalizedVariant = "primary"
            backgroundColor = "primary"
            labelColor = "textInverse"
        else if normalizedVariant = "danger"
            backgroundColor = "dangerFocused"
            labelColor = "text"
        else
            backgroundColor = "buttonFocus"
        end if
    else if normalizedVariant = "primary"
        backgroundColor = "buttonSurface"
    else if normalizedVariant = "danger"
        labelColor = "dangerFocused"
    end if

    setDialogNodeColor(background, backgroundColor)
    setDialogLabelColor(label, labelColor)
end sub

sub applyDialogButtonDisabled(background, label)
    setDialogNodeColor(background, "secondary")
    setDialogLabelColor(label, "disabledText")
end sub
