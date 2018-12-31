function init()
  m.top.observeField("visible", "onVisibleChange")
  m.file = {}
  m.convertingFile = {}
  m.fileList = m.top.findNode("fileList")
  m.fileList.observeField("itemSelected", "onFileSelected")
end function

sub onVisibleChange()
  if m.top.visible
    m.fileList.setFocus(true)
    if m.top.params.fileId <> invalid
      fetchFiles(m.top.params.fileId)
    end if
  end if
end sub

sub fetchFiles(parentId)
  m.httpTask = createObject("roSGNode", "HttpTask")
  m.httpTask.observeField("response", "onFetchFilesResponse")
  m.httpTask.url = ("/files/list?parent_id=" + parentId.toStr() + "&mp4_status=1")
  m.httpTask.method = "GET"
  m.httpTask.control = "RUN"
end sub

sub onFetchFilesResponse(obj)
  data = parseJSON(obj.getData())

  if data <> invalid and data.files <> invalid
    renderFileList(data.parent, data.files)
  else
    ? "Error"; data
  end if
end sub

sub renderFileList(parent, files)
  m.file = parent

  overhang = m.top.findNode("overhang")
  overhang.title = parent.name

  content = createObject("roSGNode", "ContentNode")

  forIndex = 0
  focusIndex = 0
  for each file in files
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
    if file.need_convert = true
      onShowConversionDialog(file)
    else
      m.top.navigate = {
        id: "videoPlayerScreen",
        params: {
          file: file
        }
      }
    end if
  else
    onShowFileNotSupportedDialog()
  end if
end sub

sub onShowFileNotSupportedDialog()
  dialog = createObject("roSGNode", "Dialog")
  dialog.title = "Oops :("
  dialog.message = "We're unable to show these kind of files on this app (for now)"
  m.top.showDialog = dialog
end sub

sub onShowConversionDialog(file)
  m.convertingFile = file
  m.conversionDialog = createObject("roSGNode", "Dialog")
  m.conversionDialog.title = "Converting to MP4"
  m.conversionDialog.message = "Status: Starting..."
  m.conversionDialog.observeField("wasClosed", "onConversionDialogClosed")
  m.top.showDialog = m.conversionDialog
  startConversion()
end sub

sub startConversion()
  m.httpTask = createObject("roSGNode", "HttpTask")
  m.httpTask.observeField("response", "onStartConversionResponse")
  m.httpTask.url = ("/files/" + m.convertingFile.id.toStr() + "/mp4")
  m.httpTask.method = "POST"
  m.httpTask.control = "RUN"
end sub

sub onStartConversionResponse(obj)
  ' ? "onStartConversionResponse: "; obj.getData()
  data = parseJSON(obj.getData())
  if data.status <> invalid and data.status = "OK"
    m.shouldCheckConversionStatus = true
    checkConversionStatus()
  else
    m.shouldCheckConversionStatus = false
    m.conversionDialog.message = "Status: ERROR"
  end if
end sub

sub checkConversionStatus()
  if m.shouldCheckConversionStatus = true
    m.httpTask = createObject("roSGNode", "HttpTask")
    m.httpTask.observeField("response", "onCheckConversionStatusResponse")
    m.httpTask.url = ("/files/" + m.convertingFile.id.toStr() + "/mp4")
    m.httpTask.method = "GET"
    m.httpTask.control = "RUN"
  end if
end sub

sub onCheckConversionStatusResponse(obj)
  ' ? "onCheckConversionStatusResponse: "; obj.getData()
  data = parseJSON(obj.getData())

  if data.mp4 <> invalid and data.mp4.status <> invalid
    message = "Status: " + data.mp4.status

    if data.mp4.percent_done <> invalid
      message = message + " (%" + data.mp4.percent_done.toStr() + ")"
    end if

    m.conversionDialog.message = message

    if data.mp4.status = "COMPLETED"
      onConversionFinished()
    else
      sleep(2000)
      checkConversionStatus()
    end if
  else
    m.shouldCheckConversionStatus = false
    m.conversionDialog.message = "Status: ERROR"
  end if
end sub

sub onConversionFinished()
  m.shouldCheckConversionStatus = false
  m.conversionDialog.close = true
  m.top.navigate = {
    id: "videoPlayerScreen",
    params: {
      file: m.convertingFile
    }
  }
  m.convertingFile = {}
end sub

sub onConversionDialogClosed()
  m.shouldCheckConversionStatus = false
  m.convertingFile = {}
end sub

function onKeyEvent(key, press)
  if m.top.visible and press
    if key = "back"
      if m.file.parent_id <> invalid
        m.focusFileId = m.file.id
        fetchFiles(m.file.parent_id)
      else
        m.top.showExitAppDialog = true
      end if
      return true
    else if key="options"
      m.top.navigate = {
        id: "settingsScreen",
        params: {
          file: m.file
        }
      }
      return true
    end if

    return false
  end if

  return false
end function
