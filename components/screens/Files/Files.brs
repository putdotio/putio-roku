function init()
    m.storage = CreateObject("roRegistrySection", "userConfig")

    m.top.observeField("visible", "onVisibleChange")
    applyAppOverhangColors(m.top.findNode("overhang"))

    m.parent = {}
    m.files = []
    m.breadcrumbs = []
    m.focusedFileIndex = 0

    m.fileList = m.top.findNode("fileList")
    m.fileList.observeField("itemSelected", "onFileSelected")
    m.fileList.observeField("itemFocused", "onFileFocused")
    m.emptyState = m.top.findNode("emptyState")

    m.deleteFileDialog = m.top.findNode("deleteFileDialog")
    m.deleteFileDialog.observeField("completed", "onFileDeleted")
    m.deleteFileDialog.observeField("wasClosed", "onDeleteFileDialogClosed")

    m.fetchFilesTask = createObject("roSGNode", "HttpTask")
end function

sub onVisibleChange()
    if m.top.visible
        m.fileList.setFocus(true)

        if m.parent.id <> m.top.params.fileId
            fetchWithLoader(m.top.params.fileId)
        end if
    else
        m.fetchFilesTask.unobserveField("response")
    end if
end sub

sub fetchWithLoader(fileId)
    hideFileList()
    hideEmptyState()
    showLoading()
    fetchFiles(fileId)
end sub

sub fetchFiles(parentId)
    m.fetchFilesTask = createObject("roSGNode", "HttpTask")
    m.fetchFilesTask.observeField("response", "onFetchFilesResponse")
    m.fetchFilesTask.url = ("/files/list?parent_id=" + parentId.toStr() + "&breadcrumbs=1")
    if toBool(m.storage.read("show_only_media_files"))
        m.fetchFilesTask.url = (m.fetchFilesTask.url + "&file_type=FOLDER,AUDIO,VIDEO,IMAGE")
    end if
    m.fetchFilesTask.method = "GET"
    m.fetchFilesTask.control = "RUN"
end sub

sub onFetchFilesResponse(obj)
    m.fetchFilesTask.unobserveField("response")
    data = parseJSON(obj.getData())

    if data <> invalid and data.files <> invalid
        m.parent = data.parent
        m.files = data.files
        m.breadcrumbs = data.breadcrumbs
        showFileList()
    else
        showFetchFilesErrorDialog(data)
    end if
end sub

''' UI
sub showLoading()
    hideEmptyState()
    m.top.findNode("loading").visible = "true"
end sub

sub hideLoading()
    m.top.findNode("loading").visible = "false"
end sub

sub showFileList()
    m.top.findNode("customTitle").text = m.parent.name

    content = createObject("roSGNode", "ContentNode")

    forIndex = 0
    focusIndex = 0
    for each file in m.files
        listItemData = content.createChild("FileListItemData")
        listItemData.file = file

        if file.id = m.top.params.focusFileId or file.id = m.focusFileId
            focusIndex = forIndex
        end if

        forIndex = forIndex + 1
    end for

    m.fileList.content = content
    m.focusedFileIndex = focusIndex
    if forIndex = 0
        hideFileList()
        showEmptyState()
        hideLoading()
        return
    end if

    hideEmptyState()
    m.fileList.visible = "true"

    if not focusIndex = 0
        m.fileList.jumpToItem = focusIndex
    end if

    hideLoading()

    if m.top.visible
        m.fileList.setFocus(true)
    end if
end sub

sub hideFileList()
    m.fileList.visible = "false"
end sub

sub showEmptyState()
    if toBool(m.storage.read("show_only_media_files"))
        m.emptyState.headingText = "No media files here"
        m.emptyState.bodyText = "Turn off the media-only filter in Settings to see every file."
    else
        m.emptyState.headingText = "This folder is empty."
        m.emptyState.bodyText = "Upload files to this folder from put.io and they will appear here."
    end if

    m.emptyState.visible = "true"
end sub

sub hideEmptyState()
    m.emptyState.visible = "false"
end sub

sub onFileSelected(obj)
    m.focusedFileIndex = obj.getData()
    fileListItem = m.fileList.content.getChild(obj.getData())
    file = fileListItem.file

    if isFileSupported(file)
        m.top.params = {
            fileId: m.parent.id,
            focusFileId: file.id,
            immediateBackFileId: m.top.params.immediateBackFileId,
        }

        if file.file_type = "FOLDER"
            fileListItem.isLoading = true
            fetchFiles(file.id)
        else
            navigateToFile(file)
        end if
    else
        showFileNotSupportedDialog(onFileNotSupportedDialogClosed)
    end if
end sub

sub onFileFocused(obj)
    focusedIndex = normalizeFocusedIndex(obj.getData())

    if focusedIndex = invalid
        return
    end if

    if focusedIndex < 0
        return
    end if

    if focusedIndex >= m.files.count()
        return
    end if

    m.focusedFileIndex = focusedIndex
end sub

function normalizeFocusedIndex(value)
    focusedIndex = value

    if type(focusedIndex) = "roArray"
        if focusedIndex.count() > 0
            focusedIndex = focusedIndex[0]
        end if
    end if

    focusedIndexType = type(focusedIndex)
    if focusedIndexType = "Integer" or focusedIndexType = "roInt"
        return focusedIndex
    end if

    return invalid
end function

''' Error Dialog
sub showFetchFilesErrorDialog(data)
    m.fetchFilesErrorDialog = createObject("roSGNode", "ErrorDialog")
    m.fetchFilesErrorDialog.error = data
    m.fetchFilesErrorDialog.observeField("wasClosed", "onFetchFilesErrorDialogClosed")
    m.top.showDialog = m.fetchFilesErrorDialog
end sub

sub onFetchFilesErrorDialogClosed()
    m.fetchFilesErrorDialog.unobserveField("wasClosed")
    m.fileList.setFocus(true)
end sub

sub onFileNotSupportedDialogClosed()
    m.fileList.setFocus(true)
end sub

''' Delete File Dialog
sub showDeleteFileDialog()
    focusedFile = getFocusedFile()

    if focusedFile <> invalid
        m.deleteFileDialog.file = focusedFile
        m.deleteFileDialog.visible = true
        m.deleteFileDialog.setFocus(true)
    end if
end sub

function getFocusedFile()
    focusedIndex = normalizeFocusedIndex(m.focusedFileIndex)

    if focusedIndex = invalid
        focusedIndex = normalizeFocusedIndex(m.fileList.itemFocused)
    end if

    if focusedIndex = invalid
        return invalid
    end if

    if focusedIndex < 0
        return invalid
    end if

    if focusedIndex >= m.files.count()
        return invalid
    end if

    return m.files[focusedIndex]
end function

sub onFileDeleted()
    fetchWithLoader(m.parent.id)
end sub

sub onDeleteFileDialogClosed()
    if m.fileList.visible
        m.fileList.setFocus(true)
    end if
end sub

''' Key Handler
function onKeyEvent(key as string, press as boolean) as boolean
    if shouldTrapModalInput(m.top, [m.deleteFileDialog])
        return true
    end if

    if m.top.visible and press
        normalizedKey = normalizeKey(key)

        if normalizedKey = "back"
            if m.top.params.immediateBackFileId = m.parent.id or m.breadcrumbs.count() = 0
                m.top.navigateBack = true
            else
                m.focusFileId = m.parent.id
                breadcrumb = m.breadcrumbs.pop()
                fetchFiles(breadcrumb[0])
            end if

            return true

        else if isOptionsKey(normalizedKey)
            showDeleteFileDialog()
            return true
        end if

        return false
    end if

    return false
end function
