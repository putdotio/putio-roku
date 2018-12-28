function init()
  m.icon = m.top.findNode("icon")
  m.name = m.top.findNode("name")
  m.description = m.top.findNode("description")
  m.watchedEye = m.top.findNode("watchedEye")
  m.spinner = m.top.findNode("spinner")
  m.spinnerAnimation = m.top.FindNode("spinnerAnimation")
end function

sub itemContentChanged()
  file = m.top.itemContent.file
  isLoading = m.top.itemContent.isLoading
  setName(file)
  setDescription(file)
  setIcon(file)
  setLoading(isLoading)
  setWatchedEye(file)
end sub

sub setName(file)
  m.name.text = file.name
end sub

sub setDescription(file)
  m.description.text = file.name
end sub

sub setIcon(file)
  fileType = file.file_type
  iconFileName = "file_type_other.png"
  iconMap = {
    FOLDER: "file_type_folder.png"
    VIDEO: "file_type_video.png"
    AUDIO: "file_type_audio.png"
    IMAGE: "file_type_image.png"
    TEXT: "file_type_text.png"
  }

  if iconMap[fileType] <> invalid
    iconFileName = iconMap[fileType]
  end if

  iconFolderPath = "pkg:/images/icons/"
  m.icon.uri = iconFolderPath + iconFileName
end sub

sub setWatchedEye(file)
  if file.start_from <> invalid and file.start_from > 0
    m.watchedEye.visible = true
  else
    m.watchedEye.visible = false
  end if
end sub

sub setLoading(isLoading)
  if isLoading = true
    m.spinner.visible = true
    m.spinnerAnimation.control = "start"
  else
    m.spinner.visible = false
    m.spinnerAnimation.control = "stop"
  end if
end sub
