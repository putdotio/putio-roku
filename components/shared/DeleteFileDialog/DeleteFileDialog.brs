sub init()
  m.top.observeField("visible", "onVisibleChange")
  m.top.buttons = ["Yes, delete file", "Cancel"]
  m.top.observeField("buttonSelected", "onButtonSelected")
  m.deleteFileTask = createObject("roSGNode", "HttpTask")
end sub

sub onFileChange()
  m.top.title = "Confirmation"
  m.top.message = "Are you sure you want to delete " + m.top.file.name + "?"
end sub


sub onButtonSelected(obj)
  if obj.getData() = 0
    m.top.completed = "true"
  else
  end if

  m.top.close = "true"
end sub

sub startDeleteFileTask()
end sub

sub onDeleteFileTaskCompleted()
end sub
