function init()
  m.icon = m.top.findNode("icon")
  m.title = m.top.findNode("title")
  m.description = m.top.findNode("description")
end function

sub itemContentChanged()
  setIcon()
  setTitle()
  setDescription()
end sub

sub setIcon()
  if m.top.itemContent.iconUri <> invalid
    m.icon.uri = m.top.itemContent.iconUri
  end if
end sub

sub setTitle()
  m.title.text = m.top.itemContent.title
end sub

sub setDescription()
  if m.top.itemContent.description <> invalid
    m.description.text = m.top.itemContent.description
  end if
end sub
