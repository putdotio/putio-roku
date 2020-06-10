function init()
  m.icon = m.top.findNode("icon")
  m.title = m.top.findNode("title")
  m.description = m.top.findNode("description")
end function

sub itemContentChanged()
  configureIcon()
  configureTitle()
  configureDescription()
end sub

sub configureIcon()
  m.icon.uri = "pkg:/images/icons/" + m.top.itemContent.iconName + ".png"
end sub

sub configureTitle()
  m.title.text = m.top.itemContent.title
end sub

sub configureDescription()
  if m.top.itemContent.description <> invalid
    m.description.text = m.top.itemContent.description
  end if
end sub
