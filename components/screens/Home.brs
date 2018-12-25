function init()
  m.top.observeField("visible", "onVisibleChange")
end function

sub onVisibleChange()
  if m.top.visible
    m.top.navigate = {
      id: "fileListScreen",
      params: {
        fileId: 0
      }
    }
  end if
end sub
