function init()
  m.top.observeField("visible", "onVisibleChange")

  m.fileList = m.top.findNode("fileList")
  m.fileList.observeField("itemSelected", "onFileSelected")

  m.parent = {}
  m.files = []
end function

sub onVisibleChange()
  if m.top.visible
    m.fileList.setFocus(true)

    if m.top.params.fileId = 0
      fetchFiles(0)
    end if
  end if
end sub

sub fetchFiles(parentId)
  if m.fetchFilesTask <> invalid
    m.fetchFilesTask.unobserveField("response")
  end if

  m.fetchFilesTask = createObject("roSGNode", "HttpTask")
  m.fetchFilesTask.observeField("response", "onFetchFilesResponse")
  m.fetchFilesTask.url = ("/files/list?parent_id=" + parentId.toStr())
  m.fetchFilesTask.method = "GET"
  m.fetchFilesTask.control = "RUN"
end sub

sub onFetchFilesResponse(obj)
  data = parseJSON(obj.getData())

  if data <> invalid and data.files <> invalid
    m.parent = data.parent
    m.files = data.files
    renderFileList()
  else
    showFetchFilesErrorDialog(data)
  end if
end sub

''' Error Dialog
sub showFetchFilesErrorDialog(data)
  m.fetchFilesErrorDialog = createObject("roSGNode", "Dialog")
  m.fetchFilesErrorDialog.title = "Oops :("
  m.fetchFilesErrorDialog.message = "An error occurred, please try again."
  m.fetchFilesErrorDialog.observeField("wasClosed", "onFetchFilesErrorDialogClosed")
  m.top.showDialog = dialog
end sub

sub onFetchFilesErrorDialogClosed()
  m.fetchFilesErrorDialog.unobserveField("wasClosed")
  m.fileList.setFocus(true)
end sub

''' FileList Render
sub renderFileList()
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

  m.fileList.content = content

  if not focusIndex = 0
    m.fileList.jumpToItem = focusIndex
  end if
 end sub

sub onFileSelected(obj)
  fileListItem = m.fileList.content.getChild(obj.getData())
  file = fileListItem.file

  if file.file_type = "FOLDER"
    fileListItem.isLoading = true
    fetchFiles(file.id)
  else if file.file_type = "VIDEO"
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

''' Key Handler
function onKeyEvent(key, press)
  if m.top.visible and press
    if key = "back"
      if m.parent.parent_id <> invalid
        m.focusFileId = m.parent.id
        fetchFiles(m.parent.parent_id)
      else
        m.top.showExitAppDialog = true
      end if

      return true
    else if key="options"
      m.top.navigate = {
        id: "settingsScreen",
        params: {},
      }

      return true
    end if

    return false
  end if

  return false
end function
