sub init()
  m.top.buttons = ["Yes, delete file", "Cancel"]
  m.top.observeField("buttonSelected", "onButtonSelected")
end sub

sub onFileChange()
  m.top.title = "Confirmation"
  m.top.message = "Are you sure you want to delete " + m.top.file.name + "?"
end sub

sub onButtonSelected(obj)
  if obj.getData() = 0
    deleteSelectedFile()
  else
    m.top.close = "true"
  end if
end sub

sub deleteSelectedFile()
  m.top.buttons = []
  m.top.message = "Deleting..."

  m.deleteFileTask = createObject("roSGNode", "HttpTask")
  m.deleteFileTask.observeField("response", "onDeleteFileResponse")
  m.deleteFileTask.url = "/files/delete"
  m.deleteFileTask.method = "POST"
  m.deleteFileTask.body = { file_ids: [m.top.file.id] }
  m.deleteFileTask.control = "RUN"
end sub

sub onDeleteFileResponse(obj)
  m.deleteFileTask.unobserveField("response")
  data = parseJSON(obj.getData())

  if data.status <> invalid and data.status = "OK"
    m.top.completed = "true"
    m.top.close = "true"
  else
    m.top.message = "An error ocurred, please try again."
  end if
end sub
