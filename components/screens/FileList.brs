function init()
  m.top.observeField("visible", "onVisibleChange")
  m.fileList = m.top.findNode("fileList")
  m.fileList.observeField("itemSelected", "onFileSelected")
end function

sub onVisibleChange()
  if m.top.visible
    fetchFiles(m.top.params.fileId.toStr())
  end if
end sub

sub fetchFiles(parentId)
  m.httpTask = createObject("roSGNode", "HttpTask")
  m.httpTask.observeField("response", "onFetchFilesResponse")
  m.httpTask.url = ("/files/list?parent_id=" + parentId)
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
  header = m.top.findNode("header")
  header.text = parent.name

  content = createObject("roSGNode", "ContentNode")

  for each file in files
    node = createObject("roSGNode", "FileListItem")
    node.title = file.name
    node.file = file
    content.appendChild(node)
  end for

  m.fileList.content = content
  m.fileList.visible = true
  m.fileList.setFocus(true)
end sub

sub onFileSelected(obj)
  file = m.fileList.content.getChild(obj.getData()).file
  fetchFiles(file.id.toStr())
end sub
