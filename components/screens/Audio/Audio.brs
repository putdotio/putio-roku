function init()
    m.top.observeField("visible", "onVisibleChange")
    applyAppOverhangColors(m.top.findNode("overhang"))

    m.audio = m.top.findNode("audio")
    m.overhang = m.top.findNode("overhang")
    m.loading = m.top.findNode("loading")
    m.audioPlayer = m.top.findNode("audioPlayer")
    m.rewindButton = m.top.findNode("rewind")
    m.fastForwardButton = m.top.findNode("fastForward")
    m.playButton = m.top.findNode("play")
    m.controls = m.top.findNode("controls")
    m.progress = m.top.findNode("progress")
    m.progressBar = m.top.findNode("progressBar")

    m.position = m.top.findNode("position")
    m.duration = m.top.findNode("duration")

    translationWidth = (getParentWidth() - m.playButton.width * 4) / 2
    translationHeight = (getParentHeight() - m.playButton.height) / 2
    m.audioPlayer.translation = [translationWidth, translationHeight]
    m.progress.translation = [(getParentWidth() - m.progressBar.width * 1.34) / 2, translationHeight + 2 * m.playButton.height]

    m.focusOrder = [
        {
            component: m.playButton,
            normalUri: "pkg:/images/icons/play-4.png",
            activeUri: "pkg:/images/icons/pause-4.png",
            callback: playOrPause,
        },
        {
            component: m.fastForwardButton,
            normalUri: "pkg:/images/icons/goforward15.png",
            activeUri: "pkg:/images/icons/goforward15.png",
            callback: fastforward,
        },
        {
            component: m.rewindButton,
            normalUri: "pkg:/images/icons/goback15.png",
            activeUri: "pkg:/images/icons/goback15.png",
            callback: rewind,
        },
    ]
    m.focusIndex = 0
    updateControlIcons()
end function

sub onVisibleChange()
    if m.top.visible
        m.top.findNode("customTitle").text = m.top.params.fileName
        m.audio.observeField("state", "onAudioStateChange")
        m.audio.observeField("position", "onPositionChange")
        m.audio.observeField("duration", "onDurationChange")

        setupPlayer()

        m.focusIndex = 0
        m.playButton.setFocus(true)
        onAudioStateChange() ' to update play button's icon

        m.loading.visible = "true"
    else
        m.audio.control = "stop"
        m.audio.unobserveField("state")
        m.audio.unobserveField("position")
        m.audio.unobserveField("duration")

        resetControlFocus()
    end if
end sub

sub setupPlayer()
    audioContent = createObject("RoSGNode", "ContentNode")

    audioContent.url = (m.global.apiURL + "/files/" + m.top.params.fileId.toStr() + "/stream.mp3?oauth_token=" + m.global.user.download_token.toStr() + "")

    audioContent.title = m.top.params.fileName

    m.audio.content = audioContent
    m.audio.control = "play"

    m.audio.seek = 0
end sub

sub onAudioStateChange()
    m.loading.visible = m.audio.state = "buffering"
    if m.audio.state = "error"
        showAudioErrorDialog()
    end if

    updateControlIcons()
end sub

sub showAudioErrorDialog()
    m.audioLoadErrorDialog = createObject("roSGNode", "ErrorDialog")
    m.audioLoadErrorDialog.title = "Oops :("
    m.audioLoadErrorDialog.message = "Audio file can not be loaded!"
    m.audioLoadErrorDialog.observeField("wasClosed", "onAudioLoadErrorDialogClosed")
    m.top.showDialog = m.audioLoadErrorDialog
end sub

sub onAudioLoadErrorDialogClosed()
    m.top.navigateBack = true
end sub

sub onPositionChange()
    if m.audio.position <> invalid
        m.position.text = getDurationString(m.audio.position)
        m.progressBar.percentage = (m.audio.position / m.audio.duration) * 100
    else
        m.position.text = "..:.."
    end if
end sub

sub onDurationChange()
    if m.audio.duration <> invalid
        m.duration.text = getDurationString(m.audio.duration)
    else
        m.duration.text = "..:.."
    end if
end sub

sub playOrPause()
    if m.audio.state = "playing"
        m.audio.control = "pause"
    else
        m.audio.control = "resume"
    end if
end sub

sub rewind()
    m.audio.seek = m.audio.position - 15
end sub

sub fastforward()
    if m.audio.position + 15 < m.audio.duration
        m.audio.seek = m.audio.position + 15
    end if
end sub

sub setNextFocusIndex()
    if m.focusIndex + 1 = m.focusOrder.count()
        newFocusIndex = 0
    else
        newFocusIndex = m.focusIndex + 1
    end if

    updateFocusIcons(newFocusIndex)
end sub

sub setPrevFocusIndex()
    if m.focusIndex - 1 = -1
        newFocusIndex = m.focusOrder.count() - 1
    else
        newFocusIndex = m.focusIndex - 1
    end if

    updateFocusIcons(newFocusIndex)
end sub

sub updateFocusIcons(newFocusIndex)
    m.focusIndex = newFocusIndex
    m.focusOrder[newFocusIndex].component.setFocus(true)
    updateControlIcons()
end sub

sub resetControlFocus()
    for each item in m.focusOrder
        item.component.blendColor = dialogColor("text")
    end for
end sub

sub updateControlIcons()
    if m.focusOrder = invalid
        return
    end if

    for i = 0 to m.focusOrder.count() - 1
        item = m.focusOrder[i]

        if i = 0 and m.audio.state = "playing"
            item.component.uri = item.activeUri
        else
            item.component.uri = item.normalUri
        end if

        if i = m.focusIndex
            item.component.blendColor = dialogColor("primary")
        else
            item.component.blendColor = dialogColor("text")
        end if
    end for
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if shouldTrapModalInput(m.top)
        return true
    end if

    if m.top.visible and press
        normalizedKey = normalizeKey(key)

        if normalizedKey = "back"
            m.top.navigateBack = true
        else if normalizedKey = "play"
            playOrPause()
        else if normalizedKey = "rewind"
            rewind()
        else if normalizedKey = "fastforward"
            fastforward()
        else if normalizedKey = "replay"
            m.audio.seek = 0
        else if normalizedKey = "ok"
            callback = m.focusOrder[m.focusIndex].callback
            callback()
        else if normalizedKey = "right"
            setNextFocusIndex()
        else if normalizedKey = "left"
            setPrevFocusIndex()
        else if isOptionsKey(normalizedKey)
            return true
        else
            return false
        end if
        return true
    end if

    return false
end function

function getParentWidth() as float
    if m.top.getParent() <> invalid and m.top.getParent().width <> invalid then
        return m.top.getParent().width
    else
        return 1920
    end if
end function


function getParentHeight() as float
    if m.top.getParent() <> invalid and m.top.getParent().height <> invalid then
        return m.top.getParent().height
    else
        return 1080
    end if
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
