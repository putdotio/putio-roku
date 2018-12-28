function init()
  m.icon = m.top.findNode("icon")
  m.name = m.top.findNode("name")
  m.description = m.top.findNode("description")
end function

sub itemContentChanged()
  file = m.top.itemContent.file
  setName(file)
  setDescription(file)
  setIcon(file)
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
  }

  if iconMap[fileType] <> invalid
    iconFileName = iconMap[fileType]
  end if

  iconFolderPath = "pkg:/images/icons/"
  m.icon.uri = iconFolderPath + iconFileName
end sub
