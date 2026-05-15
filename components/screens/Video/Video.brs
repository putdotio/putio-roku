function init()
    m.top.observeField("visible", "onVisibleChange")

    m.file = {}
    m.subtitles = []
    m.fetchFileTask = createObject("roSGNode", "HttpTask")
    m.fetchSubtitlesTask = createObject("roSGNode", "HttpTask")
    m.fetchStartFromTask = createObject("roSGNode", "HttpTask")
end function

sub onVisibleChange()
    if m.top.visible
        onMount()
    else
        cancelHttpTasks()
    end if
end sub

sub onMount()
    setTitle(m.top.params.fileName)
    showLoading()

    if m.file.id <> m.top.params.fileId
        fetchFile(m.top.params.fileId)
    else
        handleFetchedFile()
    end if
end sub

sub cancelHttpTasks()
    m.fetchFileTask.unobserveField("response")
    m.fetchSubtitlesTask.unobserveField("response")
    m.fetchStartFromTask.unobserveField("response")
end sub

''' API
sub fetchFile(fileId)
    m.fetchFileTask.observeField("response", "onFetchFileResponse")
    m.fetchFileTask.url = ("/files/list?parent_id=" + fileId.toStr() + "&mp4_status_parent=1&stream_url_parent=1&mp4_stream_url_parent=1&video_metadata_parent=1")
    m.fetchFileTask.method = "GET"
    m.fetchFileTask.control = "RUN"
end sub

sub onFetchFileResponse(obj)
    m.fetchFileTask.unobserveField("response")
    data = parseJSON(obj.getData())

    if data <> invalid and data.parent <> invalid
        m.file = data.parent
        setTitle(m.file.name)
        handleFetchedFile()
    else
        hideLoading()
        showFetchFileErrorDialog(data)
    end if
end sub

sub handleFetchedFile()
    if m.file.need_convert
        hideLoading()
        showVideoConversionDialog()
        return
    end if

    fetchSubtitles()
end sub

sub fetchSubtitles()
    m.subtitles = []
    m.fetchSubtitlesTask.observeField("response", "onFetchSubtitlesResponse")
    m.fetchSubtitlesTask.url = ("/files/" + m.file.id.toStr() + "/subtitles")
    m.fetchSubtitlesTask.method = "GET"
    m.fetchSubtitlesTask.control = "RUN"
end sub

sub onFetchSubtitlesResponse(obj)
    m.fetchSubtitlesTask.unobserveField("response")
    data = parseJSON(obj.getData())

    if data <> invalid and data.subtitles <> invalid
        m.subtitles = data.subtitles
    end if

    fetchStartFrom()
end sub

sub fetchStartFrom()
    m.fetchStartFromTask.observeField("response", "onFetchStartFromResponse")
    m.fetchStartFromTask.url = ("/files/" + m.file.id.toStr() + "/start-from")
    m.fetchStartFromTask.method = "GET"
    m.fetchStartFromTask.control = "RUN"
end sub

sub onFetchStartFromResponse(obj)
    m.fetchStartFromTask.unobserveField("response")
    data = parseJSON(obj.getData())
    hideLoading()

    if data <> invalid and data.start_from <> invalid and data.start_from > 0
        m.fetchedStartFrom = data.start_from
        if m.top.params.startFromChoice = "beginning"
            navigateToVideoPlayer(0)
        else if m.top.params.startFromChoice = "continue"
            navigateToVideoPlayer(m.fetchedStartFrom)
        else
            showChooseStartFromDialog()
        end if
    else
        navigateToVideoPlayer(0)
    end if
end sub

''' UI
sub setTitle(title)
    m.top.findNode("overhang").title = title
end sub

sub showLoading()
    m.top.findNode("loading").visible = "true"
end sub

sub hideLoading()
    m.top.findNode("loading").visible = "false"
end sub

''' Error Dialog
sub showFetchFileErrorDialog(data)
    m.fetchFileErrorDialog = createObject("roSGNode", "ErrorDialog")
    m.fetchFileErrorDialog.error = data
    m.fetchFileErrorDialog.observeField("wasClosed", "onFetchFileErrorDialogClosed")
    m.top.showDialog = m.fetchFileErrorDialog
end sub

sub onFetchFileErrorDialogClosed()
    m.fetchFileErrorDialog.unobserveField("wasClosed")
    m.top.navigateBack = "true"
end sub

''' Video Conversion Dialog
sub showVideoConversionDialog()
    m.videoConversionDialog = createObject("roSGNode", "VideoConversionDialog")
    m.videoConversionDialog.fileId = m.top.params.fileId
    m.videoConversionDialog.observeField("completed", "onVideoConversionCompleted")
    m.videoConversionDialog.observeField("wasClosed", "onVideoConversionDialogClosed")
    m.top.showDialog = m.videoConversionDialog
end sub

sub onVideoConversionDialogClosed()
    m.videoConversionDialog.unobserveField("wasClosed")

    if m.file.need_convert
        m.top.navigateBack = "true"
    end if
end sub

sub onVideoConversionCompleted()
    m.file = m.videoConversionDialog.convertedFile
    setTitle(m.file.name)
    handleFetchedFile()
end sub

''' Start From Dialog
sub showChooseStartFromDialog()
    m.didChooseStartFrom = false
    m.chooseStartFromDialog = createObject("roSGNode", "Dialog")
    m.chooseStartFromDialog.title = "Where would you like to start?"
    m.chooseStartFromDialog.message = "Last saved timestamp for this video is " + getDurationString(m.fetchedStartFrom) + " of " + getDurationString(m.file.video_metadata.duration)
    m.chooseStartFromDialog.buttons = [
        "Continue watching",
        "Start from the beginning"
    ]

    m.chooseStartFromDialog.observeField("buttonSelected", "onChooseStartFromDialogButtonSelected")
    m.chooseStartFromDialog.observeField("wasClosed", "onChooseStartFromDialogClosed")
    m.top.showDialog = m.chooseStartFromDialog
end sub

sub onChooseStartFromDialogButtonSelected(obj)
    m.chooseStartFromDialog.unobserveField("buttonSelected")
    m.didChooseStartFrom = true

    if obj.getData() = 0
        m.selectedStartFrom = m.fetchedStartFrom
    else
        m.selectedStartFrom = 0
    end if

    m.chooseStartFromDialog.close = true
    m.top.showDialog = invalid
    navigateToVideoPlayer(m.selectedStartFrom)
end sub

sub onChooseStartFromDialogClosed()
    m.chooseStartFromDialog.unobserveField("wasClosed")

    if m.didChooseStartFrom <> true
        m.top.navigateBack = "true"
    end if
end sub

sub navigateToVideoPlayer(startFrom)
    m.top.navigate = {
        id: "videoPlayerScreen",
        replace: true,
        params: {
            file: m.file,
            subtitles: m.subtitles,
            startFrom: startFrom
        }
    }
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if m.top.visible and press and key = "back"
        m.top.navigateBack = "true"
        return true
    end if

    return false
end function

sub getDurationString(seconds) as string
    datetime = CreateObject("roDateTime")
    datetime.FromSeconds(seconds)

    hours = datetime.GetHours().ToStr()
    minutes = datetime.GetMinutes().ToStr()
    seconds = datetime.GetSeconds().ToStr()

    if Len(hours) = 1 then
        hours = "0" + hours
    end if
    if Len(minutes) = 1 then
        minutes = "0" + minutes
    end if
    if Len(seconds) = 1 then
        seconds = "0" + seconds
    end if

    if hours <> "00"
        return hours + ":" + minutes + ":" + seconds
    else
        return minutes + ":" + seconds
    end if
end sub
