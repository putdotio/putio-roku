function toBool(str) as Boolean
  return str = "true"
end function

function convertSize(file_size) as String
  ' Size
  u = 0
  s = 1024
  b = file_size
  sizes = ["B", "KB", "MB", "GB", "TB"]

  while b >= s or -b >= s
    b = b / s
    u = u + 1
  end while

  if u > 4
    u = 4
  end if

  size = Fix(b).toStr() + " " + sizes[u]
  return size
end function

function convertDate(datetime)
  ' Date
  date = CreateObject("roDateTime")
  date.FromISO8601String(datetime)
  return date.AsDateString("short-month-no-weekday")
end function

function isFileSupported(file) as Boolean
  return (file.file_type = "FOLDER" or file.file_type = "VIDEO" or file.file_type = "IMAGE" or file.file_type = "AUDIO")
end function

''' send a callback to override navigation behaviour
function navigateToFile(file)
  screen = getScreenFromFileType(file.file_type)
  navigateTo(screen, file)
end function

function navigateTo(screen, file)
  m.top.navigate = {
    id: screen,
    params: {
      fileId: file.id,
      fileName: file.name,
    }
  }
end function

function getScreenFromFileType(file_type) as String
  screenMap = {
    FOLDER: "filesScreen",
    VIDEO: "videoScreen",
    IMAGE: "imageScreen",
    AUDIO: "audioScreen"
  }
  if screenMap.doesExist(file_type)
    return screenMap[file_type]
  end if
  return invalid
end function

''' File Not Supported Dialog
function showFileNotSupportedDialog()
  m.fileNotSupportedDialog = createObject("roSGNode", "Dialog")
  m.fileNotSupportedDialog.title = "Oops :("
  m.fileNotSupportedDialog.message = "We're unable to show these kind of files on this app (for now)"
  m.fileNotSupportedDialog.observeField("wasClosed", "onFileNotSupportedDialogClosedBase")
  m.fileNotSupportedDialog.observeField("wasClosed", "onFileNotSupportedDialogClosed")
  m.top.showDialog = m.fileNotSupportedDialog
end function

function onFileNotSupportedDialogClosedBase()
  m.fileNotSupportedDialog.unobserveField("wasClosed")
end function