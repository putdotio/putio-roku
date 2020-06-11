function init()
  m.top.observeField("visible", "onVisibleChange")

  m.keyboard = m.top.findNode("keyboard")
  m.keyboard.observeField("text", "onKeywordChange")

  m.loading = m.top.findNode("loading")
  m.list = m.top.findNode("list")
  m.list.observeField("itemSelected", "onFileSelected")

  m.searchTask = createObject("roSGNode", "HttpTask")
  m.files = []
end function

sub onVisibleChange()
  if m.top.visible
    m.keyboard.setFocus(true)
  end if
end sub

sub onKeywordChange(obj)
  keyword = obj.getData()

  if keyword <> invalid and len(keyword) > 0
    showLoading()
    onSearch(keyword)
  end if
end sub

sub onSearch(keyword)
  m.searchTask.observeField("response", "onSearchResponse")
  m.searchTask.url = "/files/search/" + keyword.encodeUri() + "/page/1"
  m.searchTask.method = "GET"
  m.searchTask.control = "RUN"
end sub

sub onSearchResponse(obj)
  m.searchTask.unobserveField("response")
  data = parseJSON(obj.getData())

  if data.files <> invalid
    m.files = data.files
    configureFileList()
  else
    showErrorDialog(data)
  end if

  hideLoading()
end sub

''' Events
sub onFileSelected(obj)
  file = m.list.content.getChild(obj.getData()).file

  if file.file_type = "FOLDER"
    m.top.navigate = {
      id: "filesScreen",
      params: {
        fileId: file.id,
      }
    }
  else if file.file_type = "VIDEO"
    m.top.navigate = {
      id: "videoScreen",
      params: {
        fileId: file.id,
        fileName: file.name,
      }
    }
  else
  end if
end sub

''' UI
sub showLoading()
  m.loading.visible = "true"
end sub

sub hideLoading()
  m.loading.visible = "false"
end sub

sub configureFileList()
  content = createObject("roSGNode", "ContentNode")

  for each file in m.files
    listItemData = content.createChild("FileListItemData")
    listItemData.file = file
  end for

  m.list.visible = "true"
  m.list.content = content
end sub

''' Error Dialog
sub showErrorDialog(data)
  m.errorDialog = createObject("roSGNode", "ErrorDialog")
  m.errorDialog .error = data
  m.errorDialog .observeField("wasClosed", "onErrorDialogClosed")
  m.top.showDialog = m.errorDialog
end sub

sub onErrorDialogClosed()
  m.fetchFileErrorDialog.unobserveField("wasClosed")
end sub

function onKeyEvent(key, press)
  if m.top.visible and press
    if key = "back"
      m.top.navigateBack = "true"
      return true
    else if key = "right"
      m.list.setFocus(true)
      return true
    else if key = "left"
      m.keyboard.setFocus(true)
      return true
    end if

    return false
  end if

  return false
end function
