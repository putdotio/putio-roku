function init()
    m.top.observeField("visible", "onVisibleChange")
    m.video = m.top.findNode("video")
    m.video.retrievingBar.filledBarBlendColor = "0xFFCF00FF"
    m.video.trickPlayBar.filledBarBlendColor = "0xFFCF00FF"
    m.video.trickPlayBar.currentTimeMarkerBlendColor = "0xFFFFFFFF"
    m.video.trickPlayBar.thumbBlendColor = "0xFFFFFFFF"
    m.video.bufferingBar.filledBarBlendColor = "0xFFCF00FF"
end function

sub onVisibleChange()
    if m.top.visible
        m.video.notificationInterval = 10
        m.video.observeField("state", "onPlayerStateChanged")
        m.video.observeField("position", "onPlayerPositionChanged")
        setupPlayer()
    else
        m.video.unobserveField("state")
        m.video.unobserveField("position")
    end if
end sub

sub setupPlayer()
    file = m.top.params.file
    subtitle = m.top.params.subtitle
    videoContent = createObject("RoSGNode", "ContentNode")

    if file.is_mp4_available = true
        videoContent.url = file.mp4_stream_url
    else
        videoContent.url = file.stream_url
    end if

    videoContent.title = file.name
    videoContent.streamformat = "mp4"

    if subtitle <> invalid and subtitle.url <> invalid and subtitle.url <> ""
        subtitleTrack = createSubtitleTrack(subtitle)
        videoContent.subtitletracks = [subtitleTrack]
        videoContent.subtitleconfig = {
            TrackName: subtitleTrack.TrackName
        }
    end if

    m.video.content = videoContent

    fetchStartFrom()
end sub

function createSubtitleTrack(subtitle)
    return {
        Language: getSubtitleLanguageCode(subtitle),
        TrackName: subtitle.url,
        Description: subtitle.name
    }
end function

function getSubtitleLanguageCode(subtitle) as string
    if subtitle.language_code <> invalid and subtitle.language_code <> ""
        return subtitle.language_code
    end if

    if subtitle.language <> invalid and subtitle.language <> ""
        return subtitle.language
    end if

    return "und"
end function

sub fetchStartFrom()
    m.fetchStartFromTask = createObject("roSGNode", "HttpTask")
    m.fetchStartFromTask.observeField("response", "onFetchStartFromResponse")
    m.fetchStartFromTask.url = ("/files/" + m.top.params.file.id.toStr() + "/start-from")
    m.fetchStartFromTask.method = "GET"
    m.fetchStartFromTask.control = "RUN"
end sub

sub onFetchStartFromResponse(obj)
    m.fetchStartFromTask.unobserveField("response")
    data = parseJSON(obj.getData())

    if data <> invalid and data.start_from <> invalid and data.start_from > 0
        m.fetchedStartFrom = data.start_from
        showChooseStartFromDialog()
    else
        startPlayback(0)
    end if
end sub

sub startPlayback(time)
    m.video.control = "play"
    m.video.seek = time
    m.video.setFocus(true)
end sub

sub showChooseStartFromDialog()
    m.chooseStartFromDialog = createObject("roSGNode", "Dialog")
    m.chooseStartFromDialog.title = "Where would you like to start?"
    m.chooseStartFromDialog.message = "Last saved timestamp for this video is " + getDurationString(m.fetchedStartFrom) + " of " + getDurationString(m.top.params.file.video_metadata.duration)
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
    m.chooseStartFromDialog.close = "true"

    if obj.getData() = 0
        startPlayback(m.fetchedStartFrom)
    else
        startPlayback(0)
    end if
end sub

sub onChooseStartFromDialogClosed()
    m.chooseStartFromDialog.unobserveField("wasClosed")

    if m.video.control <> "play"
        startPlayback(0)
    end if
end sub

sub onPlayerStateChanged(obj)
    state = obj.getData()

    if state = "error"
        onError()
    else if state = "finished"
        onGoBack()
    end if
end sub

sub onError()
    m.errorDialog = createObject("roSGNode", "Dialog")
    m.errorDialog.title = "Video Error"
    m.errorDialog.message = m.video.errorMsg + chr(10) + "Code: " + m.video.errorCode.toStr()
    m.errorDialog.observeField("wasClosed", "onErrorDialogClosed")
    m.top.showDialog = m.errorDialog
end sub

sub onErrorDialogClosed()
    onGoBack()
end sub

sub onPlayerPositionChanged(obj)
    if m.global.user.settings.start_from = true
        saveVideoTime(obj.getData())
    end if
end sub

sub saveVideoTime(time)
    if time > 0
        m.setStartFromTask = createObject("roSGNode", "HttpTask")
        m.setStartFromTask.url = ("/files/" + m.top.params.file.id.toStr() + "/start-from/set")
        m.setStartFromTask.method = "POST"
        m.setStartFromTask.body = { time: time }
        m.setStartFromTask.control = "RUN"
    end if
end sub

sub onGoBack()
    m.video.control = "stop"
    m.top.navigateBack = "true"
end sub

function onKeyEvent(key, press)
    if m.top.visible and press and key = "back"
        onGoBack()
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
