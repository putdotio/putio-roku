function init()
    ensureFileListItemNodes()
end function

sub ensureFileListItemNodes()
    if m.focusBackground = invalid
        m.focusBackground = m.top.findNode("focusBackground")
        m.icon = m.top.findNode("icon")
        m.title = m.top.findNode("title")
        m.description = m.top.findNode("description")
        m.watchedEye = m.top.findNode("watchedEye")
        m.spinner = m.top.findNode("spinner")
        m.spinnerAnimation = m.top.FindNode("spinnerAnimation")
    end if

    applyListItemFocusBackground(m.focusBackground)
end sub

sub itemContentChanged()
    ensureFileListItemNodes()
    if m.top.itemContent = invalid
        return
    end if

    file = m.top.itemContent.file
    isLoading = m.top.itemContent.isLoading
    configureLayout()
    setIcon(file)
    setTitle(file)
    setDescription(file)
    applyListItemLoading(m.spinner, m.spinnerAnimation, isLoading)
    setWatchedEye(file)
end sub

sub updateFocus()
    ensureFileListItemNodes()
    if m.focusBackground <> invalid
        m.focusBackground.visible = m.top.itemHasFocus
    end if
end sub

sub configureLayout()
    ensureFileListItemNodes()

    rowWidth = normalizeListItemRowWidth(m.top.itemContent.rowWidth)
    applyListItemFocusBackground(m.focusBackground, rowWidth)

    m.title.width = listItemMainTextWidth(rowWidth)
end sub

sub setTitle(file)
    m.title.text = file.name
end sub

sub setDescription(file)
    size = convertSize(file.size)
    date = convertDate(file.created_at)
    m.description.text = size + " - " + date
end sub

sub setIcon(file)
    fileType = file.file_type
    iconFileName = "file_type_other.png"
    iconMap = {
        FOLDER: "file_type_folder.png"
        VIDEO: "file_type_video.png"
        AUDIO: "file_type_audio.png"
        IMAGE: "file_type_image.png"
        TEXT: "file_type_text.png"
    }

    if iconMap[fileType] <> invalid
        iconFileName = iconMap[fileType]
    end if

    iconFolderPath = "pkg:/images/icons/"
    m.icon.uri = iconFolderPath + iconFileName
end sub

sub setWatchedEye(file)
    if file.start_from <> invalid and file.start_from > 0
        m.watchedEye.visible = "true"
    else
        m.watchedEye.visible = "false"
    end if
end sub
