function init()
  m.top.observeField("visible", "onVisibleChange")
  m.video = m.top.findNode("video")
  m.startFromMap = {}
  m.startFrom = 0
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

  if subtitle <> invalid and subtitle.url <> invalid
    videoContent.subtitletracks = [
      {
        Language: subtitle.language,
        Trackname: subtitle.url,
        Description: subtitle.name
      }
    ]
  end if

  m.video.content = videoContent

  if m.startFromMap[file.id.toStr()] <> invalid
    m.startFrom = m.startFromMap[file.id.toStr()]
  else if file.start_from > 0
    m.startFrom = file.start_from
  else
    m.startFrom = 0
  end if

  if m.startFrom > 0
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

sub onPlayerStateChanged(obj)
  state = obj.getData()
  if state = "error"
    onError()
	else if state = "finished"
    onGoBack()
	end if
end sub

sub showChooseStartFromDialog()
  m.chooseStartFromDialog = createObject("roSGNode", "Dialog")
  m.chooseStartFromDialog.title = "Where would you like to start?"
  m.chooseStartFromDialog.buttons = [
    "Continue watching from " + getDurationString(m.startFrom) + " of " + getDurationString(m.top.params.file.video_metadata.duration),
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
    startPlayback(m.startFrom)
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


sub onError()
  ? "Video Error: " + m.video.errorMsg
  ? "Video Error Code: " + m.video.errorCode.toStr()
  m.errorDialog = createObject("roSGNode", "Dialog")
  m.errorDialog.title = "Video Error"
  m.errorDialog.message = m.video.errorMsg + chr(10) + "Code: " + m.video.errorCode.toStr()
  m.errorDialog.observeField("wasClosed", "onErrorDialogClosed")
  m.top.showDialog = errorDialog
end sub

sub onErrorDialogClosed()
  onGoBack()
end sub

sub onPlayerPositionChanged(obj)
  if m.global.user.settings.start_from = true and m.top.params.file.is_shared = false
    saveVideoTime(obj.getData())
  end if
end sub

sub saveVideoTime(time)
  if time > 0
    m.startFromMap[m.top.params.file.id.toStr()] = time
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

sub getDurationString(seconds) as String
	datetime = CreateObject("roDateTime")
	datetime.FromSeconds(seconds)

	hours = datetime.GetHours().ToStr()
	minutes = datetime.GetMinutes().ToStr()
	seconds = datetime.GetSeconds().ToStr()

	If Len( hours ) = 1 Then
		hours = "0" + hours
	End If
	If Len( minutes ) = 1 Then
		minutes = "0" + minutes
	End If
	If Len( seconds ) = 1 Then
		seconds = "0" + seconds
	End If

	if hours <> "00"
		return hours + ":" + minutes + ":" + seconds
	else
		return minutes + ":" + seconds
	end if
end sub
