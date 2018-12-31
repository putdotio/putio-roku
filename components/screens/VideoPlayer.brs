function init()
  m.top.observeField("visible", "onVisibleChange")
  m.video = m.top.findNode("video")
end function

sub onVisibleChange()
  if m.top.visible
    setupPlayer()
  end if
end sub

sub setupPlayer()
  file = m.top.params.file
  user = m.global.user

  videoContent = createObject("RoSGNode", "ContentNode")
  videoContent.url = "https://api.put.io/v2/files/" + file.id.toStr() + "/hls/media.m3u8?subtitle_key=all&oauth_token=" + user.download_token
  videoContent.title = file.name
  videoContent.streamformat = "hls"

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
  dialog.title = "Error!"
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
