function init()
    m.top.observeField("visible", "onVisibleChange")

    m.file = {}
    m.subtitles = []
    m.phase = "idle"
    m.fetchedStartFrom = 0
    m.fetchFileTask = createObject("roSGNode", "HttpTask")
    m.fetchSubtitlesTask = createObject("roSGNode", "HttpTask")
    m.fetchStartFromTask = createObject("roSGNode", "HttpTask")
    m.continueWatchingPrompt = m.top.findNode("continueWatchingPrompt")
    m.continueWatchingPrompt.observeField("selectedStartFrom", "onContinueWatchingPromptSelected")
    m.continueWatchingPrompt.observeField("dismissed", "onContinueWatchingPromptDismissed")
    m.conversionStatus = m.top.findNode("conversionStatus")
    m.conversionStatus.observeField("completed", "onVideoConversionCompleted")
    m.conversionStatus.observeField("dismissed", "onVideoConversionDismissed")
end function

sub onVisibleChange()
    if m.top.visible
        onMount()
    else
        cancelHttpTasks()
    end if
end sub

sub onMount()
    hideOverlays()
    setTitle(m.top.params.fileName)
    showLoading()

    if m.file.id <> m.top.params.fileId
        m.file = {}
        m.subtitles = []
        fetchFile(m.top.params.fileId)
    else
        handleFetchedFile()
    end if
end sub

sub cancelHttpTasks()
    m.fetchFileTask.unobserveField("response")
    m.fetchSubtitlesTask.unobserveField("response")
    m.fetchStartFromTask.unobserveField("response")
    m.conversionStatus.control = "stop"
end sub

''' API
sub fetchFile(fileId)
    m.phase = "loadingFile"
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
    if shouldShowConversionFlow(m.file)
        hideLoading()
        showVideoConversionStatus()
        return
    end if

    fetchSubtitles()
end sub

sub fetchSubtitles()
    m.phase = "loadingSubtitles"
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
    m.phase = "loadingStartFrom"
    m.fetchStartFromTask.observeField("response", "onFetchStartFromResponse")
    m.fetchStartFromTask.url = ("/files/" + m.file.id.toStr() + "/start-from")
    m.fetchStartFromTask.method = "GET"
    m.fetchStartFromTask.control = "RUN"
end sub

sub onFetchStartFromResponse(obj)
    m.fetchStartFromTask.unobserveField("response")
    data = parseJSON(obj.getData())
    hideLoading()

    if data <> invalid and data.start_from <> invalid and shouldResumeFrom(data.start_from)
        m.fetchedStartFrom = data.start_from
        if m.top.params.startFromChoice = "beginning"
            navigateToVideoPlayer(0)
        else if m.top.params.startFromChoice = "continue"
            navigateToVideoPlayer(m.fetchedStartFrom)
        else
            showContinueWatchingPrompt()
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

sub hideOverlays()
    m.continueWatchingPrompt.visible = false
    m.conversionStatus.visible = false
    m.conversionStatus.control = "stop"
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

''' Video Conversion
sub showVideoConversionStatus()
    m.phase = "conversion"
    m.conversionStatus.control = "stop"
    m.conversionStatus.fileName = m.file.name
    m.conversionStatus.fileId = m.file.id
    m.conversionStatus.visible = true
    m.conversionStatus.setFocus(true)
    m.conversionStatus.control = "start"
end sub

sub onVideoConversionDismissed()
    if m.phase = "conversion"
        m.conversionStatus.visible = false
        m.top.navigateBack = true
    end if
end sub

sub onVideoConversionCompleted()
    if m.phase <> "conversion"
        return
    end if

    m.conversionStatus.visible = false
    m.file = m.conversionStatus.completedFile
    setTitle(m.file.name)
    handleFetchedFile()
end sub

''' Resume Prompt
sub showContinueWatchingPrompt()
    m.phase = "resumePrompt"
    m.continueWatchingPrompt.fileName = m.file.name
    m.continueWatchingPrompt.duration = getFileDuration(m.file)
    m.continueWatchingPrompt.startFrom = m.fetchedStartFrom
    m.continueWatchingPrompt.visible = true
    m.continueWatchingPrompt.setFocus(true)
end sub

sub onContinueWatchingPromptSelected(obj)
    if m.phase <> "resumePrompt"
        return
    end if

    m.continueWatchingPrompt.visible = false
    navigateToVideoPlayer(obj.getData())
end sub

sub onContinueWatchingPromptDismissed()
    if m.phase = "resumePrompt"
        m.continueWatchingPrompt.visible = false
        m.top.navigateBack = true
    end if
end sub

sub navigateToVideoPlayer(startFrom)
    m.phase = "launchingPlayer"
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
        if m.continueWatchingPrompt.visible
            m.continueWatchingPrompt.visible = false
        else if m.conversionStatus.visible
            m.conversionStatus.control = "stop"
            m.conversionStatus.visible = false
        end if

        m.top.navigateBack = "true"
        return true
    end if

    return false
end function

function shouldShowConversionFlow(file as object) as boolean
    return file.need_convert = true and hasMp4Stream(file) = false
end function

function hasMp4Stream(file as object) as boolean
    return file.is_mp4_available = true and file.mp4_stream_url <> invalid and file.mp4_stream_url <> ""
end function

function shouldResumeFrom(startFrom as integer) as boolean
    if startFrom <= 0
        return false
    end if

    duration = getFileDuration(m.file)
    if duration > 0 and startFrom >= int(duration * 0.95)
        return false
    end if

    return true
end function

function getFileDuration(file as object) as integer
    if file.video_metadata <> invalid and file.video_metadata.duration <> invalid
        return file.video_metadata.duration
    end if

    return 0
end function
