function init()
  m.top.observeField("visible", "onVisibleChange")

  m.fileList = m.top.findNode("fileList")
  m.fileList.observeField("itemSelected", "onFileSelected")

  m.parent = {}
  m.files = []
  m.convertingFile = {}
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
  m.fetchFilesTask.url = ("/files/list?parent_id=" + parentId.toStr() + "&mp4_status=1&stream_url=1&mp4_stream_url=1")
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
    if file.need_convert = true
      showConversionDialog(file)
    else
      m.top.navigate = {
        id: "videoScreen",
        params: {
          file: file
        }
      }
    end if
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

''' Video Conversion
sub startConversion()
  m.startConversionTask = createObject("roSGNode", "HttpTask")
  m.startConversionTask.observeField("response", "onStartConversionResponse")
  m.startConversionTask.url = ("/files/" + m.convertingFile.id.toStr() + "/mp4")
  m.startConversionTask.method = "POST"
  m.startConversionTask.control = "RUN"
end sub

sub onStartConversionResponse(obj)
  ' ? "onStartConversionResponse: "; obj.getData()
  m.startConversionTask.unobserveField("response")
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
    m.checkConversionTask = createObject("roSGNode", "HttpTask")
    m.checkConversionTask.observeField("response", "onCheckConversionStatusResponse")
    m.checkConversionTask.url = ("/files/" + m.convertingFile.id.toStr() + "/mp4")
    m.checkConversionTask.method = "GET"
    m.checkConversionTask.control = "RUN"
  end if
end sub

sub onCheckConversionStatusResponse(obj)
  m.checkConversionTask.unobserveField("response")
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
    id: "videoScreen",
    params: {
      file: m.convertingFile
    }
  }
  m.convertingFile = {}
end sub

''' Video Conversion Dialog
sub showConversionDialog(file)
  m.convertingFile = file
  m.conversionDialog = createObject("roSGNode", "Dialog")
  m.conversionDialog.title = "Converting to MP4"
  m.conversionDialog.message = "Status: Starting..."
  m.conversionDialog.observeField("wasClosed", "onConversionDialogClosed")
  m.top.showDialog = m.conversionDialog
  startConversion()
end sub

sub onConversionDialogClosed()
  m.conversionDialog.unobserveField("wasClosed")
  m.shouldCheckConversionStatus = false
  m.convertingFile = {}
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
