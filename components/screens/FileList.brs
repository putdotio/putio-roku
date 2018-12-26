function init()
  m.top.observeField("visible", "onVisibleChange")
  m.file = {}
  m.fileList = m.top.findNode("fileList")
  m.fileList.observeField("itemSelected", "onFileSelected")
end function

sub onVisibleChange()
  if m.top.visible
    m.fileList.setFocus(true)
    fetchFiles(m.top.params.fileId)
  end if
end sub

sub fetchFiles(parentId)
  m.httpTask = createObject("roSGNode", "HttpTask")
  m.httpTask.observeField("response", "onFetchFilesResponse")
  m.httpTask.url = ("/files/list?parent_id=" + parentId.toStr())
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

  screenTitle = m.top.findNode("screenTitle")
  screenTitle.text = parent.name

  content = createObject("roSGNode", "ContentNode")

  forIndex = 0
  focusIndex = 0
  for each file in files
    node = createObject("roSGNode", "FileListItem")
    node.title = file.name
    node.file = file

    if file.id = m.top.params.focusFileId or file.id = m.focusFileId
      focusIndex = forIndex
    end if

    content.appendChild(node)
    forIndex = forIndex + 1
  end for

  m.fileList.content = content

  if not focusIndex = 0
    m.fileList.jumpToItem = focusIndex
  end if
 end sub

sub onFileSelected(obj)
  file = m.fileList.content.getChild(obj.getData()).file
  fileType = file.file_type

  if fileType = "FOLDER"
    fetchFiles(file.id)
  else if fileType = "VIDEO"
    m.top.navigate = {
      id: "playerVideoScreen",
      params: {
        file: file
      }
    }
  end if
end sub

function onKeyEvent(key, press)
  if m.top.visible and key = "back" and press
    if m.file.parent_id <> invalid
      m.focusFileId = m.file.id
      fetchFiles(m.file.parent_id)
      return true
    end if

    return false
  end if

  return false
end function
