function init()
  m.storage = CreateObject("roRegistrySection", "userConfig")

  m.top.observeField("visible", "onVisibleChange")

  m.parent = {}
  m.files = []
  m.breadcrumbs = []

  m.fileList = m.top.findNode("fileList")
  m.fileList.observeField("itemSelected", "onFileSelected")

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
  m.top.findNode("loading").visible = "true"
end sub

sub hideLoading()
  m.top.findNode("loading").visible = "false"
end sub

sub showFileList()
  overhang = m.top.findNode("overhang")
  overhang.title = m.parent.name

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

  m.fileList.visible = "true"
  m.fileList.content = content

  if not focusIndex = 0
    m.fileList.jumpToItem = focusIndex
  end if

  hideLoading()
 end sub

sub hideFileList()
  m.fileList.visible = "false"
end sub

sub onFileSelected(obj)
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
  focusedFile = m.files[m.fileList.itemFocused]

  if focusedFile <> invalid
    m.deleteFileDialog = createObject("roSGNode", "DeleteFileDialog")
    m.deleteFileDialog.file = focusedFile
    m.deleteFileDialog.observeField("completed", "onFileDeleted")
    m.top.showDialog = m.deleteFileDialog
  end if
end sub

sub onFileDeleted()
  fetchWithLoader(m.parent.id)
end sub

''' Key Handler
function onKeyEvent(key, press)
  if m.top.visible and press
    if key = "back"
      if m.top.params.immediateBackFileId = m.parent.id or m.breadcrumbs.count() = 0
        m.top.navigateBack = "true"
      else
        m.focusFileId = m.parent.id
        breadcrumb = m.breadcrumbs.pop()
        fetchFiles(breadcrumb[0])
      end if

      return true

    else if key = "options"
      showDeleteFileDialog()
      return true
    end if

    return false
  end if

  return false
end function
