function dialogColor(name as string) as string
    colors = {
        appBackground: "0x161616FF",
        appBackgroundWash: "0x00000000",
        border: "0x343434FF",
        borderHover: "0x505050FF",
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

sub applyDialogTextColors(title, body)
    setDialogNodeColor(title, "text")
    setDialogNodeColor(body, "textMuted")
end sub

function dialogPrimaryButtonTextColor() as string
    return dialogColor("textInverse")
end function

function dialogSecondaryButtonTextColor() as string
    return dialogColor("text")
end function
