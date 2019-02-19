function init()
  m.top.observeField("visible", "onVisibleChange")
  m.video = m.top.findNode("video")
end function

sub onVisibleChange()
  if m.top.visible
    fetchSubtitles()
  end if
end sub

sub fetchSubtitles()
  file = m.top.params.file
  m.httpTask = createObject("roSGNode", "HttpTask")
  m.httpTask.observeField("response", "onFetchSubtitlesResponse")
  m.httpTask.url = ("/files/" + file.id.toStr() + "/subtitles")
  m.httpTask.method = "GET"
  m.httpTask.control = "RUN"
end sub

sub onFetchSubtitlesResponse(obj)
  data = parseJSON(obj.getData())

  if data <> invalid and data.subtitles <> invalid
    setupPlayer(data.subtitles)
  else
    setupPlayer([])
  end if
end sub

sub setupPlayer(subtitles)
  file = m.top.params.file
  user = m.global.user

  videoContent = createObject("RoSGNode", "ContentNode")

  if file.is_mp4_available = true
    videoContent.url = file.mp4_stream_url
  else
    videoContent.url = file.stream_url
  end if

  subtitleTracks = []

  for each subtitle in subtitles
    subtitleTracks.push({
      Language: subtitle.language,
      Trackname: subtitle.url,
      Description: subtitle.name
    })
  end for

  videoContent.title = file.name
  videoContent.streamformat = "mp4"
  videoContent.subtitletracks = subtitleTracks

  m.video.observeField("state", "onPlayerStateChanged")
  m.video.content = videoContent
  m.video.control = "play"
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
    id: "fileListScreen",
    params: {
      fileId: m.top.params.file.parent_id,
      focusFileId: m.top.params.file.id,
    }
  }
end sub

function onKeyEvent(key, press)
  if m.top.visible and key = "back" and press
    m.video.control = "stop"
    onGoBack()
    return true
  end if

  return false
end function
