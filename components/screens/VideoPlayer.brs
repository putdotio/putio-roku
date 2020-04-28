function init()
  m.top.observeField("visible", "onVisibleChange")
  m.video = m.top.findNode("video")
end function

sub onVisibleChange()
  if m.top.visible
    m.video.notificationInterval = 10
    m.video.observeField("state", "onPlayerStateChanged")
    m.video.observeField("position", "onPlayerPositionChanged")
    setupPlayer()
  else
    m.video.control = "stop"
    m.video.unobserveField("state")
    m.video.unobserveField("position")
  end if
end sub

sub setupPlayer()
  user = m.global.user
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
  m.video.control = "play"

  if file.start_from > 0
    m.video.seek = file.start_from
  end if

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

sub onError()
  dialog = createObject("roSGNode", "Dialog")
  dialog.title = "Video Error"
  dialog.message = m.video.errorMsg + chr(10) + "Code: " + m.video.errorCode.toStr()
  m.top.showDialog = dialog
end sub

sub onGoBack()
  m.top.navigate = {
    id: "videoScreen",
    params: {
      file: m.top.params.file,
    }
  }
end sub

sub onPlayerPositionChanged(obj)
  if m.global.user.settings.start_from = true and m.top.params.file.is_shared = false
    saveVideoTime(obj.getData())
  end if
end sub

sub saveVideoTime(time)
  if time > 0
    m.httpTask = createObject("roSGNode", "HttpTask")
    m.httpTask.url = ("/files/" + m.top.params.file.id.toStr() + "/start-from/set")
    m.httpTask.method = "POST"
    m.httpTask.body = { time: time }
    m.httpTask.control = "RUN"
  end if
end sub

function onKeyEvent(key, press)
  if m.top.visible and key = "back" and press
    onGoBack()
    return true
  end if

  return false
end function
