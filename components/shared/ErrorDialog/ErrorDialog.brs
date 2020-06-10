sub init()
  m.top.title = "Oops, an error occurred"
  m.top.message = ""
end sub

sub onErrorChange(obj)
  error_type = obj.getData().error_type
  error_message = obj.getData().error_message

  if error_type <> invalid and error_message <> invalid
    if error_type = "NotFound"
      m.top.message = "File not found"
    else
      m.top.message = error_message
    end if
  else
    m.top.message = "Please restart your device and try again."
  end if
end sub
