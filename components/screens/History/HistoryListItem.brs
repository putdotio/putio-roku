function init()
  m.icon = m.top.findNode("icon")
  m.title = m.top.findNode("title")
  m.description = m.top.findNode("description")
  m.spinner = m.top.findNode("spinner")
  m.spinnerAnimation = m.top.FindNode("spinnerAnimation")
end function

sub itemContentChanged()
  event = m.top.itemContent.event
  isLoading = m.top.itemContent.isLoading
  contentMap = GetMapFromHistoryEventType(event.type)
  m.title.text = contentMap.title(event)
  m.description.text = contentMap.description(event)
  if contentMap.icon <> invalid
    iconFolderPath = "pkg:/images/icons/"
    m.icon.uri = iconFolderPath + contentMap.icon + ".png" 'iconFileName
  end if
  setLoading(isLoading)
end sub

sub setLoading(isLoading)
  if isLoading = true
    m.spinner.visible = "true"
    m.spinnerAnimation.control = "start"
  else
    m.spinner.visible = "false"
    m.spinnerAnimation.control = "stop"
  end if
end sub
