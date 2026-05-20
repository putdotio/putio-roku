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
    m.deleteButtonBackground = m.top.findNode("deleteButtonBackground")
    m.deleteButtonLabel = m.top.findNode("deleteButtonLabel")
    m.cancelButtonBackground = m.top.findNode("cancelButtonBackground")
    m.cancelButtonLabel = m.top.findNode("cancelButtonLabel")
    m.focusIndex = 1
    m.isDeleting = false
    applyDialogScrim(m.scrim)
    applyDialogPanelColors(m.panel, m.panelShadow, m.panelBorderTop, m.panelBorderRight, m.panelBorderBottom, m.panelBorderLeft)
    applyDialogTextColors(m.title, invalid)
    setDialogNodeColor(m.divider, "border")
    setDialogNodeColor(m.message, "textMuted")
    setDialogNodeColor(m.fileName, "text")
    updateDeleteDialogLayout(1)
    updateButtonFocus()
end sub

sub onFileChange()
    wrappedFileName = "this file"

    if m.top.file <> invalid and m.top.file.name <> invalid
        wrappedFileName = wrapDialogFileName(m.top.file.name.toStr())
    end if

    m.fileName.text = wrappedFileName
    updateDeleteDialogLayout(countTextLines(wrappedFileName))
    m.focusIndex = 1
    m.isDeleting = false
    updateButtonFocus()
end sub

sub updateDeleteDialogLayout(fileLineCount as integer)
    if fileLineCount < 1
        fileLineCount = 1
    else if fileLineCount > 3
        fileLineCount = 3
    end if

    panelWidth = 1040
    contentWidth = 936
    panelX = Int((1920 - panelWidth) / 2)
    contentX = panelX + 52
    titleY = 52
    titleHeight = 44
    titleBodyGap = 48
    bodyButtonGap = 56
    bottomPadding = 52
    fileNameY = titleY + titleHeight + titleBodyGap
    lineHeight = 44
    fileNameHeight = fileLineCount * lineHeight
    buttonsY = fileNameY + fileNameHeight + bodyButtonGap
    panelHeight = buttonsY + 164 + bottomPadding
    panelY = Int((1080 - panelHeight) / 2)

    m.panel.translation = [panelX, panelY]
    m.panel.width = panelWidth
    m.panel.height = panelHeight
    m.panelShadow.translation = [panelX + 12, panelY + 12]
    m.panelShadow.width = panelWidth
    m.panelShadow.height = panelHeight
    m.panelBorderTop.translation = [panelX, panelY]
    m.panelBorderTop.width = panelWidth
    m.panelBorderRight.translation = [panelX + panelWidth - 1, panelY]
    m.panelBorderRight.height = panelHeight
    m.panelBorderBottom.translation = [panelX, panelY + panelHeight - 1]
    m.panelBorderBottom.width = panelWidth
    m.panelBorderLeft.translation = [panelX, panelY]
    m.panelBorderLeft.height = panelHeight
    m.title.translation = [contentX, panelY + titleY]
    m.title.width = contentWidth
    m.fileName.translation = [contentX, panelY + fileNameY]
    m.fileName.width = contentWidth
    m.fileName.height = fileNameHeight
    m.buttons.translation = [contentX, panelY + buttonsY]
end sub

sub updateButtonFocus()
    deleteFocused = m.focusIndex = 0
    cancelFocused = m.focusIndex = 1

    applyDialogButtonState(m.deleteButtonBackground, m.deleteButtonLabel, deleteFocused, "danger")
    applyDialogButtonState(m.cancelButtonBackground, m.cancelButtonLabel, cancelFocused, "secondary")
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
        m.focusIndex = 1
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
        if m.focusIndex = 0
            m.focusIndex = 1
        else
            m.focusIndex = 0
        end if

        updateButtonFocus()
        return true
    else if normalizedKey = "ok" or normalizedKey = "select"
        if m.focusIndex = 0
            deleteSelectedFile()
        else
            closeDialog()
        end if

        return true
    end if

    return true
end function
