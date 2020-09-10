function init()
  m.top.observeField("visible", "onVisibleChange")

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
      callback: playOrPause,
    },
    {
      component: m.fastForwardButton,
      callback: fastforward,
    },
    {
      component: m.rewindButton,
      callback: rewind,
    },
  ]
  m.focusIndex = 0
end function

sub onVisibleChange()
  if m.top.visible
    m.overhang.title = m.top.params.fileName
    m.audio.observeField("state", "onAudioStateChange")
    m.audio.observeField("position", "onPositionChange")
    m.audio.observeField("duration", "onDurationChange")

    setupPlayer()

    m.playButton.setFocus(true)
    onAudioStateChange() ' to update play button's icon
    m.focusIndex = 0

    m.loading.visible = "true"
  else
    m.audio.control = "stop"
    m.audio.unobserveField("state")
    m.audio.unobserveField("position")
    m.audio.unobserveField("duration")

    m.focusOrder[m.focusIndex].component.uri = m.focusOrder[m.focusIndex].component.uri.replace("-focused", "")
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
  if m.audio.state = "playing"
    if m.playButton.hasFocus()
      m.playButton.uri = "pkg:/images/icons/pause-4-focused.png"
    else
      m.playButton.uri = "pkg:/images/icons/pause-4.png"
    end if
  else if m.audio.state = "paused" or m.audio.state = "stopped" or m.audio.state = "finished"
    if m.playButton.hasFocus()
      m.playButton.uri = "pkg:/images/icons/play-4-focused.png"
    else
      m.playButton.uri = "pkg:/images/icons/play-4.png"
    end if
  else if m.audio.state = "error"
    showAudioErrorDialog()
  end if
end sub

sub showAudioErrorDialog()
  m.audioLoadErrorDialog = createObject("roSGNode", "ErrorDialog")
  m.audioLoadErrorDialog.title = "Oops :("
  m.audioLoadErrorDialog.message = "Audio file can not be loaded!"
  m.audioLoadErrorDialog.observeField("wasClosed", "onAudioLoadErrorDialogClosed")
  m.top.showDialog = m.audioLoadErrorDialog
end sub

sub onAudioLoadErrorDialogClosed()
  m.top.navigateBack = "true"
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
  oldFocusIndex = m.focusIndex
  if m.focusIndex + 1 = m.focusOrder.count()
    newFocusIndex = 0
  else
    newFocusIndex = m.focusIndex + 1
  end if

  updateFocusIcons(oldFocusIndex, newFocusIndex)
  m.focusIndex = newFocusIndex
end sub

sub setPrevFocusIndex()
  oldFocusIndex = m.focusIndex
  if m.focusIndex - 1 = -1
    newFocusIndex = m.focusOrder.count() - 1
  else
    newFocusIndex = m.focusIndex - 1
  end if

  updateFocusIcons(oldFocusIndex, newFocusIndex)
  m.focusIndex = newFocusIndex
end sub

sub updateFocusIcons(oldFocusIndex, newFocusIndex)
  m.focusOrder[newFocusIndex].component.setFocus(true)
  m.focusOrder[oldFocusIndex].component.uri = m.focusOrder[oldFocusIndex].component.uri.replace("-focused", "")
  m.focusOrder[newFocusIndex].component.uri = m.focusOrder[newFocusIndex].component.uri.replace(".png", "-focused.png")
end sub

function onKeyEvent(key, press)
  if m.top.visible and press
    if key = "back"
      m.top.navigateBack = "true"
    else if key = "play"
      playOrPause()
    else if key = "rewind"
      rewind()
    else if key = "fastforward"
      fastforward()
    else if key = "replay"
      m.audio.seek = 0
    else if key = "OK"
      callback = m.focusOrder[m.focusIndex].callback
      callback()
    else if key = "right"
      setNextFocusIndex()
    else if key = "left"
      setPrevFocusIndex()
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

sub getDurationString(seconds) as String
	datetime = CreateObject("roDateTime")
	datetime.FromSeconds(seconds)

	hours = datetime.GetHours().ToStr()
	minutes = datetime.GetMinutes().ToStr()
	seconds = datetime.GetSeconds().ToStr()

	If Len(hours) = 1 Then
		hours = "0" + hours
	End If
	If Len(minutes) = 1 Then
		minutes = "0" + minutes
	End If
	If Len(seconds) = 1 Then
		seconds = "0" + seconds
	End If

	if hours <> "00"
		return hours + ":" + minutes + ":" + seconds
	else
		return minutes + ":" + seconds
	end if
end sub