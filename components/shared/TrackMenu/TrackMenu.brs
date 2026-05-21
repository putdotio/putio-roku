sub init()
    m.scrim = m.top.findNode("scrim")
    m.panel = m.top.findNode("trackMenuPanel")
    m.panelShadow = m.top.findNode("panelShadow")
    m.panelFill = m.top.findNode("panelFill")
    m.panelBorderTop = m.top.findNode("panelBorderTop")
    m.panelBorderRight = m.top.findNode("panelBorderRight")
    m.panelBorderBottom = m.top.findNode("panelBorderBottom")
    m.panelBorderLeft = m.top.findNode("panelBorderLeft")
    m.titleLabel = m.top.findNode("trackMenuTitle")
    m.rows = m.top.findNode("trackRows")
    m.topSeparator = m.top.findNode("topSeparator")
    m.bottomSeparator = m.top.findNode("bottomSeparator")
    m.visibleRowCount = 8
    m.rowHeight = 63
    m.rowGap = 9
    applyDialogScrim(m.scrim)
    applyDialogPanelColors(m.panelFill, m.panelShadow, m.panelBorderTop, m.panelBorderRight, m.panelBorderBottom, m.panelBorderLeft)
    applyDialogTextColors(m.titleLabel, invalid)
    setDialogNodeColor(m.topSeparator, "border")
    setDialogNodeColor(m.bottomSeparator, "border")
    m.rowNodes = createTrackMenuRows()
    renderTrackMenu()
end sub

function createTrackMenuRows() as object
    rows = []

    for i = 0 to m.visibleRowCount - 1
        index = i.toStr()
        row = m.rows.findNode("trackMenuRow" + index)
        background = m.rows.findNode("trackMenuRow" + index + "Background")
        label = m.rows.findNode("trackMenuRow" + index + "Label")
        check = m.rows.findNode("trackMenuRow" + index + "Check")
        setDialogNodeColor(background, "focus")
        setDialogNodeColor(label, "text")
        setDialogNodeColor(check, "primary")

        rows.push({
            node: row,
            background: background,
            label: label,
            check: check
        })
    end for

    return rows
end function

sub renderTrackMenu()
    if m.titleLabel = invalid
        return
    end if

    items = m.top.items
    if items = invalid
        items = []
    end if

    focusedIndex = m.top.focusedIndex
    if focusedIndex < 0
        focusedIndex = 0
    else if items.count() > 0 and focusedIndex >= items.count()
        focusedIndex = items.count() - 1
    end if

    rowCount = getTrackMenuVisibleRowCount(items.count())
    scrollOffset = getTrackMenuScrollOffset(items.count(), focusedIndex, rowCount)
    updateTrackMenuLayout(rowCount)
    m.scrim.visible = m.top.showScrim
    m.titleLabel.text = m.top.title
    m.topSeparator.visible = scrollOffset > 0
    m.bottomSeparator.visible = items.count() > scrollOffset + rowCount

    for i = 0 to m.rowNodes.count() - 1
        row = m.rowNodes[i]
        itemIndex = scrollOffset + i
        row.node.translation = [0, i * (m.rowHeight + m.rowGap)]

        if itemIndex < items.count()
            item = items[itemIndex]
            focused = itemIndex = focusedIndex
            selected = item.selected = true

            row.node.visible = true
            row.label.text = getTrackMenuItemLabel(item)
            row.check.visible = selected

            if focused
                row.background.visible = true
                row.label.color = dialogColor("text")
                row.check.color = dialogColor("primary")
            else
                row.background.visible = false
                row.label.color = dialogColor("text")
                row.check.color = dialogColor("primary")
            end if
        else
            row.node.visible = false
            row.label.text = ""
            row.background.visible = false
            row.check.visible = false
        end if
    end for
end sub

sub updateTrackMenuLayout(rowCount as integer)
    panelWidth = 822
    rowWidth = 726
    contentX = 48
    borderWidth = uiBorderWidth()
    rowAreaHeight = rowCount * m.rowHeight
    if rowCount > 1
        rowAreaHeight = rowAreaHeight + ((rowCount - 1) * m.rowGap)
    end if

    rowsY = 108
    panelHeight = rowsY + rowAreaHeight + 45
    panelY = uiCenterY(panelHeight)

    m.panel.translation = [uiCenterX(panelWidth), panelY]
    m.panelShadow.width = panelWidth
    m.panelShadow.height = panelHeight
    m.panelShadow.translation = [uiShadowOffset(), uiShadowOffset()]
    m.panelFill.width = panelWidth
    m.panelFill.height = panelHeight
    m.panelBorderTop.width = panelWidth
    m.panelBorderTop.height = borderWidth
    m.panelBorderRight.translation = [panelWidth - borderWidth, 0]
    m.panelBorderRight.width = borderWidth
    m.panelBorderRight.height = panelHeight
    m.panelBorderBottom.translation = [0, panelHeight - borderWidth]
    m.panelBorderBottom.width = panelWidth
    m.panelBorderBottom.height = borderWidth
    m.panelBorderLeft.width = borderWidth
    m.panelBorderLeft.height = panelHeight
    m.titleLabel.translation = [contentX, 45]
    m.titleLabel.width = rowWidth
    m.rows.translation = [contentX, rowsY]
    m.topSeparator.translation = [contentX, rowsY - 12]
    m.topSeparator.width = rowWidth
    m.bottomSeparator.translation = [contentX, rowsY + rowAreaHeight + 12]
    m.bottomSeparator.width = rowWidth

    for each row in m.rowNodes
        row.background.width = rowWidth
        row.background.height = m.rowHeight
        row.label.translation = [24, 12]
        row.label.width = 600
        row.label.height = m.rowHeight
        row.check.translation = [660, 9]
        row.check.width = 45
        row.check.height = m.rowHeight
    end for
end sub

function getTrackMenuVisibleRowCount(itemCount as integer) as integer
    if itemCount < m.visibleRowCount
        return itemCount
    end if

    return m.visibleRowCount
end function

function getTrackMenuScrollOffset(itemCount as integer, focusedIndex as integer, rowCount as integer) as integer
    if itemCount <= rowCount
        return 0
    end if

    offset = focusedIndex - rowCount + 1
    if offset < 0
        offset = 0
    end if

    maxOffset = itemCount - rowCount
    if offset > maxOffset
        offset = maxOffset
    end if

    return offset
end function

function getTrackMenuItemLabel(item as object) as string
    if item = invalid or item.label = invalid or item.label = ""
        return "Unknown"
    end if

    return item.label.toStr()
end function
