function init()
  m.top.observeField("visible", "onVisibleChange")
end function

sub onVisibleChange()
  if m.top.visible
    file = m.top.params.file
    screenTitle = m.top.findNode("screenTitle")
    screenTitle.text = file.name
  end if
end sub

function onKeyEvent(key, press)
  if m.top.visible and key = "back" and press
    m.top.navigate = {
      id: "fileListScreen",
      params: {
        fileId: m.top.params.file.parent_id,
        focusFileId: m.top.params.file.id,
      }
    }

    return true
  end if

  return false
end function
