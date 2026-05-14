function toBool(str) as boolean
    return str = "true"
end function

function convertSize(file_size) as string
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

function isFileSupported(file) as boolean
    return (file.file_type = "FOLDER" or file.file_type = "VIDEO" or file.file_type = "IMAGE" or file.file_type = "AUDIO")
end function

''' send a callback to override navigation behaviour
function navigateToFile(file, immediateBackFileId = invalid)
    screen = getScreenFromFileType(file.file_type)
    navigateTo(screen, file, immediateBackFileId)
end function

function navigateTo(screen, file, immediateBackFileId)
    m.top.navigate = {
        id: screen,
        params: {
            fileId: file.id,
            fileName: file.name,
            immediateBackFileId: immediateBackFileId,
        }
    }
end function

function getScreenFromFileType(file_type) as string
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
function showFileNotSupportedDialog(callback = invalid)
    m.fileNotSupportedDialogCallback = callback
    m.fileNotSupportedDialog = createObject("roSGNode", "Dialog")
    m.fileNotSupportedDialog.title = "Oops :("
    m.fileNotSupportedDialog.message = "We're unable to show these kind of files on this app (for now)"
    m.fileNotSupportedDialog.observeField("wasClosed", "onFileNotSupportedDialogClosedBase")
    m.top.showDialog = m.fileNotSupportedDialog
end function

function onFileNotSupportedDialogClosedBase()
    m.fileNotSupportedDialog.unobserveField("wasClosed")
    if m.fileNotSupportedDialogCallback <> invalid
        callback = m.fileNotSupportedDialogCallback
        m.fileNotSupportedDialogCallback = invalid
        callback()
    end if
end function

function updateSetting(key, value, callback = invalid)
    m.updateSettingCallback = callback
    m.httpTask = createObject("roSGNode", "HttpTask")
    m.httpTask.observeField("response", "onUpdateSettingBase")
    m.httpTask.url = "/account/settings"

    payload = {}
    payload.addReplace(key, value)
    m.httpTask.body = payload

    m.tempSetting = { key: key, value: value }
    m.httpTask.method = "POST"
    m.httpTask.control = "RUN"
end function

function onUpdateSettingBase(obj)
    data = parseJSON(obj.getData())
    if data <> invalid and data.status <> invalid and data.status = "OK"
        user = m.global.user
        user.settings[m.tempSetting.key] = m.tempSetting.value
        m.global.user = user
    end if

    if m.updateSettingCallback <> invalid
        callback = m.updateSettingCallback
        m.updateSettingCallback = invalid
        callback()
    end if
end function
