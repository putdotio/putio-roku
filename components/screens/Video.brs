function init()
  m.top.observeField("visible", "onVisibleChange")

  m.playButton = m.top.findNode("button-play")
  m.nextVideoContainer = m.top.findNode("next-video")
  m.nextVideoLabel = m.top.findNode("next-video-label")
  m.spinner = m.top.findNode("spinner")
  m.spinnerAnimation = m.top.FindNode("spinnerAnimation")
  m.message = m.top.findNode("message")
  m.subtitleList = m.top.findNode("subtitleList")

  m.file = {}
  m.subtitles = []
  m.nextVideo = {
    status: "IDLE", 'IDLE | FOUND | FAILED'
    file: {},
    subtitles: []
  }

  m.fetchSubtitlesTask = createObject("roSGNode", "HttpTask")
  m.findNextVideoTask = createObject("roSGNode", "HttpTask")
  m.fetchNextVideoTask = createObject("roSGNode", "HttpTask")
  m.fetchNextVideoSubtitlesTask = createObject("roSGNode", "HttpTask")
end function

sub onVisibleChange(obj)
  if m.top.visible
    onMount(m.top.params.file)
  else
    cancelHttpTasks()
  end if
end sub

sub onMount(file)
  focusPlayButton()

  if m.file.id <> file.id
    m.file = file
    setTitle()
    fetchSubtitles()
  end if

  findNextVideo()
end sub

sub cancelHttpTasks()
  m.fetchSubtitlesTask.unobserveField("response")
  m.findNextVideoTask.unobserveField("response")
  m.fetchNextVideoTask.unobserveField("response")
  m.fetchNextVideoSubtitlesTask.unobserveField("response")
end sub


''' API
sub fetchSubtitles()
  resetSubtitles()
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

  setSubtitles()
end sub

sub findNextVideo()
  resetNextVideo()
  m.findNextVideoTask.observeField("response", "onFindNextVideoResponse")
  m.findNextVideoTask.url = ("/files/" + m.file.id.toStr() + "/next-file?file_type=VIDEO")
  m.findNextVideoTask.method = "GET"
  m.findNextVideoTask.control = "RUN"
end sub

sub onFindNextVideoResponse(obj)
  m.findNextVideoTask.unobserveField("response")
  data = parseJSON(obj.getData())

  if data <> invalid and data.next_file.id <> invalid
    fetchNextVideo(data.next_file.id)
  else
    m.nextVideo.status = "FAILED"
    setNextVideo()
  end if
end sub

sub fetchNextVideo(id)
  m.fetchNextVideoTask.observeField("response", "onFetchNextVideoResponse")
  m.fetchNextVideoTask.url = ("/files/list?parent_id=" + id.toStr() + "&mp4_status_parent=1&stream_url_parent=1&mp4_stream_url_parent=1")
  m.fetchNextVideoTask.method = "GET"
  m.fetchNextVideoTask.control = "RUN"
end sub

sub onFetchNextVideoResponse(obj)
  m.fetchNextVideoTask.unobserveField("response")
  data = parseJSON(obj.getData())

  if data <> invalid and data.parent <> invalid
    fetchNextVideoSubtitles(data.parent.id)
    m.nextVideo.file = data.parent
  else
    m.nextVideo.status = "FAILED"
    setNextVideo()
  end if

end sub

sub fetchNextVideoSubtitles(id)
  m.fetchNextVideoSubtitlesTask.observeField("response", "onFetchNextVideoSubtitlesResponse")
  m.fetchNextVideoSubtitlesTask.url = ("/files/" + id.toStr() + "/subtitles")
  m.fetchNextVideoSubtitlesTask.method = "GET"
  m.fetchNextVideoSubtitlesTask.control = "RUN"
end sub

sub onFetchNextVideoSubtitlesResponse(obj)
  m.fetchNextVideoSubtitlesTask.unobserveField("response")
  data = parseJSON(obj.getData())

  if data <> invalid and data.subtitles <> invalid
    m.nextVideo.subtitles = data.subtitles
    m.nextVideo.status = "FOUND"
  else
    m.nextVideo.status = "FAILED"
  end if

  setNextVideo()
end sub


''' UI
sub setTitle()
  m.top.findNode("overhang").title = m.file.name
end sub

sub resetNextVideo()
  m.nextVideo = {
    status: "IDLE",
    file: {},
    subtitles: [],
  }

  m.nextVideoLabel.text = "Loading..."
end sub

sub setNextVideo()
  if m.nextVideo.status = "FOUND"
    m.nextVideoLabel.text = m.nextVideo.file.name
  else
    m.nextVideoLabel.text = "Could not find anything to play :("
  end if
end sub

sub setSubtitles()
  hideSpinner()
  hideMessage()

  content = createObject("roSGNode", "ContentNode")

  noSelectionItem = content.createChild("ContentNode")
  noSelectionItem.title = "Don’t you dare load any subtitles!"

  for each subtitle in m.subtitles
    listItemData = content.createChild("ContentNode")
    listItemData.title = subtitle.language + " — " + subtitle.name
  end for

  if m.subtitles[0] <> invalid
    m.subtitleList.checkedItem = 1
  else
    m.subtitleList.checkedItem = 0
  end if

  m.subtitleList.visible = "true"
  m.subtitleList.content = content
  m.subtitleList.observeField("itemSelected", "onSubtitleSelected")
end sub

sub resetSubtitles()
  showSpinner()
  showMessage("Loading")

  m.subtitles = []
  m.subtitleList.checkedItem = 0
  m.subtitleList.visible = "false"
  m.subtitleList.unobserveField("itemSelected")
end sub

sub showSpinner()
  m.spinner.visible = "true"
  m.spinnerAnimation.control = "start"
end sub

sub hideSpinner()
  m.spinner.visible = "false"
  m.spinnerAnimation.control = "stop"
end sub

sub showMessage(text)
  m.message.visible = "true"
  m.message.text = text
end sub

sub hideMessage()
  m.message.visible = "false"
end sub

sub focusPlayButton()
  m.playButton.setFocus(true)
  m.playButton.uri = "pkg:/images/PlayButtonFocused.png"
end sub

sub unfocusPlaybutton()
  m.playButton.setFocus(false)
  m.playButton.uri = "pkg:/images/PlayButtonUnfocused.png"
end sub

sub focusNextVideo()
  m.nextVideoContainer.setFocus(true)
  m.top.findNode("next-video-background").uri = "pkg:/images/NextVideoFocused.png"
  m.top.findNode("next-video-title").color = "0x000000FF"
  m.nextVideoLabel.color = "0x000000FF"
end sub

sub unfocusNextVideo()
  m.nextVideoContainer.setFocus(false)
  m.top.findNode("next-video-background").uri = "pkg:/images/NextVideoUnfocused.png"
  m.top.findNode("next-video-title").color = "0xFFFFFFFF"
  m.nextVideoLabel.color = "0xFFFFFFFF"
end sub


''' Events
sub onSubtitleSelected()
  focusPlayButton()
  onPlay()
end sub

sub onPlay()
  selectedSubtitle = {}

  if m.subtitleList.checkedItem > 0
    selectedSubtitle = m.subtitles[m.subtitleList.checkedItem - 1]
  end if

  m.top.navigate = {
    id: "videoPlayerScreen",
    params: {
      file: m.file,
      subtitle: selectedSubtitle,
    }
  }
end sub

sub onNextVideo()
  m.file = m.nextVideo.file
  m.subtitles = m.nextVideo.subtitles
  unfocusNextVideo()
  setTitle()
  setSubtitles()
  onPlay()
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
  if m.top.visible and press
    if key = "back"
      onGoBack()
      return true
    end if

    if m.playButton.hasFocus()
      if key = "OK"
        onPlay()
        return true
      end if

      if key = "right"
        unfocusPlaybutton()
        focusNextVideo()
        return true
      end if

      if key = "down" and m.subtitleList.visible
        unfocusPlaybutton()
        m.subtitleList.setFocus(true)
        return true
      end if
    end if

    if m.nextVideoContainer.hasFocus()
      if key = "OK" and m.nextVideo.status = "FOUND"
        onNextVideo()
        return true
      end if

      if key = "left"
        unfocusNextVideo()
        focusPlayButton()
        return true
      end if

      if key = "down" and m.subtitleList.visible
        unfocusNextVideo()
        m.subtitleList.setFocus(true)
        return true
      end if
    end if
  end if

  return false
end function
