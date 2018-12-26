function init()
  m.top.observeField("visible", "onVisibleChange")
  m.buttonPlay = m.top.findNode("buttonPlay")
  m.buttonPlay.observeField("buttonSelected", "onPlay")
end function

sub onVisibleChange()
  if m.top.visible
    file = m.top.params.file

    screenTitle = m.top.findNode("screenTitle")
    screenTitle.text = file.name

    poster = m.top.findNode("poster")
    poster.uri = file.screenshot

    m.buttonPlay.setFocus(true)
  end if
end sub

sub onPlay()
  m.top.navigate = {
    id: "playerVideoScreen",
    params: {
      file: m.top.params.file,
    }
  }
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
