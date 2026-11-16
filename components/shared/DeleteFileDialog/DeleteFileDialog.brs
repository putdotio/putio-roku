sub init()
    m.scrim = m.top.findNode("scrim")
    m.panelShadow = m.top.findNode("panelShadow")
    m.panel = m.top.findNode("panel")
    m.panelBorderTop = m.top.findNode("panelBorderTop")
    m.panelBorderRight = m.top.findNode("panelBorderRight")
    m.panelBorderBottom = m.top.findNode("panelBorderBottom")
    m.panelBorderLeft = m.top.findNode("panelBorderLeft")
    m.title = m.top.findNode("title")
    m.divider = m.top.findNode("divider")
    m.message = m.top.findNode("message")
    m.fileName = m.top.findNode("fileName")
    m.buttons = m.top.findNode("buttons")
    m.playWithButton = m.top.findNode("playWithButton")
    m.playWithButtonBackground = m.top.findNode("playWithButtonBackground")
    m.playWithButtonLabel = m.top.findNode("playWithButtonLabel")
    m.deleteButton = m.top.findNode("deleteButton")
    m.cancelButton = m.top.findNode("cancelButton")
    m.deleteButtonBackground = m.top.findNode("deleteButtonBackground")
    m.deleteButtonLabel = m.top.findNode("deleteButtonLabel")
    m.cancelButtonBackground = m.top.findNode("cancelButtonBackground")
    m.cancelButtonLabel = m.top.findNode("cancelButtonLabel")
    m.buttonActions = ["delete", "cancel"]
    m.focusIndex = 1
    m.isDeleting = false
    applyDialogScrim(m.scrim)
    applyDialogPanelColors(m.panel, m.panelShadow, m.panelBorderTop, m.panelBorderRight, m.panelBorderBottom, m.panelBorderLeft)
    applyDialogTextColors(m.title, invalid)
    setDialogNodeColor(m.divider, "border")
    setDialogNodeColor(m.message, "textMuted")
    applyTypography(m.title, "h1")
    applyTypography(m.message, "small")
    applyTypography(m.fileName, "small")
    applyTypography(m.playWithButtonLabel, "h2")
    applyTypography(m.deleteButtonLabel, "h2")
    applyTypography(m.cancelButtonLabel, "h2")
    setDialogNodeColor(m.fileName, "text")
    updateDeleteDialogLayout(1)
    updateButtonFocus()
end sub

sub onFileChange()
    wrappedFileName = "this file"

    if m.top.file <> invalid and m.top.file.name <> invalid
        wrappedFileName = wrapDialogFileName(m.top.file.name.toStr())
    end if

    if hasPlayWithAction()
        m.buttonActions = ["play_with", "delete", "cancel"]
        m.title.text = "File options"
        m.playWithButtonLabel.text = m.top.playWithLabel
    else
        m.buttonActions = ["delete", "cancel"]
        m.title.text = "Delete file?"
        m.playWithButtonLabel.text = ""
    end if
    m.playWithButton.visible = hasPlayWithAction()

    m.fileName.text = wrappedFileName
    updateDeleteDialogLayout(countTextLines(wrappedFileName))
    m.focusIndex = m.buttonActions.count() - 1
    m.isDeleting = false
    updateButtonFocus()
end sub

function hasPlayWithAction() as boolean
    return m.top.playWithLabel <> invalid and m.top.playWithLabel <> ""
end function

sub updateDeleteDialogLayout(fileLineCount as integer)
    if fileLineCount < 1
        fileLineCount = 1
    else if fileLineCount > 3
        fileLineCount = 3
    end if

    panelWidth = 1044
    contentWidth = 936
    panelX = uiCenterX(panelWidth)
    contentX = panelX + uiSnap(Int((panelWidth - contentWidth) / 2))
    titleY = 51
    titleHeight = 45
    titleBodyGap = 48
    bodyButtonGap = 57
    bottomPadding = 51
    rowHeight = 78
    rowGap = 18
    buttonCount = m.buttonActions.count()
    buttonsHeight = (buttonCount * rowHeight) + ((buttonCount - 1) * rowGap)
    fileNameY = titleY + titleHeight + titleBodyGap
    lineHeight = 45
    fileNameHeight = fileLineCount * lineHeight
    buttonsY = fileNameY + fileNameHeight + bodyButtonGap
    panelHeight = buttonsY + buttonsHeight + bottomPadding
    panelY = uiCenterY(panelHeight)
    borderWidth = uiBorderWidth()

    m.panel.translation = [panelX, panelY]
    m.panel.width = panelWidth
    m.panel.height = panelHeight
    m.panelShadow.translation = [panelX + uiShadowOffset(), panelY + uiShadowOffset()]
    m.panelShadow.width = panelWidth
    m.panelShadow.height = panelHeight
    m.panelBorderTop.translation = [panelX, panelY]
    m.panelBorderTop.width = panelWidth
    m.panelBorderTop.height = borderWidth
    m.panelBorderRight.translation = [panelX + panelWidth - borderWidth, panelY]
    m.panelBorderRight.width = borderWidth
    m.panelBorderRight.height = panelHeight
    m.panelBorderBottom.translation = [panelX, panelY + panelHeight - borderWidth]
    m.panelBorderBottom.width = panelWidth
    m.panelBorderBottom.height = borderWidth
    m.panelBorderLeft.translation = [panelX, panelY]
    m.panelBorderLeft.width = borderWidth
    m.panelBorderLeft.height = panelHeight
    m.title.translation = [contentX, panelY + titleY]
    m.title.width = contentWidth
    m.title.height = titleHeight
    m.fileName.translation = [contentX, panelY + fileNameY]
    m.fileName.width = contentWidth
    m.fileName.height = fileNameHeight
    m.buttons.translation = [contentX, panelY + buttonsY]
    m.playWithButtonBackground.width = contentWidth
    m.playWithButtonBackground.height = rowHeight
    m.playWithButtonLabel.width = contentWidth
    m.playWithButtonLabel.height = rowHeight
    m.deleteButtonBackground.width = contentWidth
    m.deleteButtonBackground.height = rowHeight
    m.deleteButtonLabel.width = contentWidth
    m.deleteButtonLabel.height = rowHeight
    m.cancelButtonBackground.width = contentWidth
    m.cancelButtonBackground.height = rowHeight
    m.cancelButtonLabel.width = contentWidth
    m.cancelButtonLabel.height = rowHeight
    for i = 0 to buttonCount - 1
        getDeleteDialogButtonNode(m.buttonActions[i]).translation = [0, i * (rowHeight + rowGap)]
    end for
end sub

function getDeleteDialogButtonNode(action as string) as object
    if action = "play_with"
        return m.playWithButton
    else if action = "delete"
        return m.deleteButton
    end if

    return m.cancelButton
end function

sub updateButtonFocus()
    focusedAction = m.buttonActions[m.focusIndex]

    applyDialogButtonState(m.playWithButtonBackground, m.playWithButtonLabel, focusedAction = "play_with", "primary")
    applyDialogButtonState(m.deleteButtonBackground, m.deleteButtonLabel, focusedAction = "delete", "danger")
    applyDialogButtonState(m.cancelButtonBackground, m.cancelButtonLabel, focusedAction = "cancel", "secondary")
end sub

sub closeDialog()
    if m.deleteFileTask <> invalid
        m.deleteFileTask.unobserveField("response")
        m.deleteFileTask = invalid
    end if

    m.top.visible = false
    m.top.wasClosed = true
end sub

sub deleteSelectedFile()
    if m.top.file = invalid or m.top.file.id = invalid
        return
    end if

    m.isDeleting = true
    m.fileName.text = "Deleting..."
    updateDeleteDialogLayout(1)
    applyDialogButtonDisabled(m.playWithButtonBackground, m.playWithButtonLabel)
    applyDialogButtonDisabled(m.deleteButtonBackground, m.deleteButtonLabel)
    applyDialogButtonDisabled(m.cancelButtonBackground, m.cancelButtonLabel)

    m.deleteFileTask = createObject("roSGNode", "HttpTask")
    m.deleteFileTask.observeField("response", "onDeleteFileResponse")
    m.deleteFileTask.url = "/files/delete"
    m.deleteFileTask.method = "POST"
    m.deleteFileTask.body = { file_ids: [m.top.file.id] }
    m.deleteFileTask.control = "RUN"
end sub

sub onDeleteFileResponse(obj)
    m.deleteFileTask.unobserveField("response")
    m.deleteFileTask = invalid

    data = parseJSON(obj.getData())

    if data <> invalid and data.status <> invalid and data.status = "OK"
        m.top.completed = true
        closeDialog()
    else
        m.isDeleting = false
        m.fileName.text = "An error occurred, please try again."
        updateDeleteDialogLayout(1)
        m.focusIndex = m.buttonActions.count() - 1
        updateButtonFocus()
    end if
end sub

function wrapDialogFileName(fileName as string) as string
    maxLineLength = 42
    wrapped = ""
    remaining = fileName

    while Len(remaining) > maxLineLength
        wrapIndex = findFileNameWrapIndex(remaining, maxLineLength)

        if wrapped <> ""
            wrapped = wrapped + Chr(10)
        end if

        wrapped = wrapped + Left(remaining, wrapIndex)
        remaining = Mid(remaining, wrapIndex + 1)
    end while

    if wrapped <> ""
        wrapped = wrapped + Chr(10)
    end if

    return wrapped + remaining
end function

function findFileNameWrapIndex(fileName as string, maxLineLength as integer) as integer
    wrapIndex = maxLineLength

    for i = maxLineLength to 1 step -1
        char = Mid(fileName, i, 1)

        if char = "_" or char = "-" or char = "." or char = " "
            wrapIndex = i
            exit for
        end if
    end for

    if wrapIndex < 30
        wrapIndex = maxLineLength
    end if

    return wrapIndex
end function

function countTextLines(text as string) as integer
    if text = invalid or text = ""
        return 1
    end if

    count = 1
    for i = 1 to Len(text)
        if Asc(Mid(text, i, 1)) = 10
            count = count + 1
        end if
    end for

    return count
end function

function onKeyEvent(key as string, press as boolean) as boolean
    if press = false or m.top.visible = false
        return false
    end if

    if m.isDeleting
        return true
    end if

    normalizedKey = normalizeKey(key)

    if normalizedKey = "back"
        closeDialog()
        return true
    else if normalizedKey = "up" or normalizedKey = "down"
        buttonCount = m.buttonActions.count()
        if normalizedKey = "up"
            m.focusIndex = (m.focusIndex + buttonCount - 1) mod buttonCount
        else
            m.focusIndex = (m.focusIndex + 1) mod buttonCount
        end if

        updateButtonFocus()
        return true
    else if normalizedKey = "ok" or normalizedKey = "select"
        focusedAction = m.buttonActions[m.focusIndex]
        if focusedAction = "delete"
            deleteSelectedFile()
        else if focusedAction = "play_with"
            closeDialog()
            m.top.playWithSelected = true
        else
            closeDialog()
        end if

        return true
    end if

    return true
end function
