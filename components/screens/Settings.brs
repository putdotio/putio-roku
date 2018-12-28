function init()
  m.top.observeField("visible", "onVisibleChange")
end function

sub onVisibleChange()
  if m.top.visible
  end if
end sub

function onKeyEvent(key, press)
  if m.top.visible and key = "back" and press
    m.top.navigate = {
      id: "fileListScreen"
      params: {}
    }
    return true
  end if

  return false
end function
