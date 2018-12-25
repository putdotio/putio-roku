function init()
  m.label = m.top.findNode("label")
  m.top.observeField("text", "onTextChange")
end function

sub onTextChange(obj)
  m.label.text = obj.getData()
end sub
