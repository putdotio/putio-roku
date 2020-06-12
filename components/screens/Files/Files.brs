function init()
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

  if file.file_type = "FOLDER"
    fileListItem.isLoading = true
    fetchFiles(file.id)
  else if file.file_type = "VIDEO"
    m.top.params = {
      fileId: m.parent.id,
      focusFileId: file.id,
    }

    m.top.navigate = {
      id: "videoScreen",
      params: {
        fileId: file.id,
        fileName: file.name,
      }
    }
  else
    showFileNotSupportedDialog()
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

''' File Not Supported Dialog
sub showFileNotSupportedDialog()
  m.fileNotSupportedDialog = createObject("roSGNode", "Dialog")
  m.fileNotSupportedDialog.title = "Oops :("
  m.fileNotSupportedDialog.message = "We're unable to show these kind of files on this app (for now)"
  m.fileNotSupportedDialog.observeField("wasClosed", "onFileNotSupportedDialogClosed")
  m.top.showDialog = m.fileNotSupportedDialog
end sub

sub onFileNotSupportedDialogClosed()
  m.fileNotSupportedDialog.unobserveField("wasClosed")
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
      if m.breadcrumbs.count() > 0
        m.focusFileId = m.parent.id
        breadcrumb = m.breadcrumbs.pop()
        fetchFiles(breadcrumb[0])
      else
        m.top.navigateBack = "true"
      end if

      return true

    else if key="options"
      showDeleteFileDialog()
      return true
    end if

    return false
  end if

  return false
end function
