function init()
  m.top.observeField("visible", "onVisibleChange")

  m.file = {}
  m.subtitles = []

  m.playButton = m.top.findNode("button-play")
  m.subtitleList = m.top.findNode("subtitleList")
  m.subtitleList.observeField("itemSelected", "onSubtitleSelected")

  m.fetchFileTask = createObject("roSGNode", "HttpTask")
  m.fetchSubtitlesTask = createObject("roSGNode", "HttpTask")
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

  if m.file.id <> m.top.params.fileId
    hideContent()
    showLoading()
    fetchFile(m.top.params.fileId)
  else
    focusPlayButton()
  end if
end sub

sub cancelHttpTasks()
  m.fetchFileTask.unobserveField("response")
  m.fetchSubtitlesTask.unobserveField("response")
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
    fetchSubtitles(m.top.params.fileId)
  else
    showFetchFileErrorDialog(data)
  end if
end sub

sub fetchSubtitles(fileId)
  m.fetchSubtitlesTask.observeField("response", "onFetchSubtitlesResponse")
  m.fetchSubtitlesTask.url = ("/files/" + fileId.toStr() + "/subtitles")
  m.fetchSubtitlesTask.method = "GET"
  m.fetchSubtitlesTask.control = "RUN"
end sub

sub onFetchSubtitlesResponse(obj)
  m.fetchSubtitlesTask.unobserveField("response")
  data = parseJSON(obj.getData())

  if data <> invalid and data.subtitles <> invalid
    m.subtitles = data.subtitles
  end if

  hideLoading()
  showContent()
  focusPlayButton()
end sub

''' UI
sub setTitle(title)
  m.top.findNode("overhang").title = title
end sub

sub configurePlayButtonImage()
  if m.playButton.hasFocus()
    if m.file.need_convert
      m.playButton.uri = "pkg:/images/ConvertButtonFocused.png"
      m.playButton.width = "430"
    else
      m.playButton.uri = "pkg:/images/PlayButtonFocused.png"
      m.playButton.width = "312"
    end if
  else
    if m.file.need_convert
      m.playButton.uri = "pkg:/images/ConvertButtonUnfocused.png"
      m.playButton.width = "430"
    else
      m.playButton.uri = "pkg:/images/PlayButtonUnfocused.png"
      m.playButton.width = "312"
    end if
  end if
end sub

sub showLoading()
  m.top.findNode("loading").visible = "true"
end sub

sub hideLoading()
  m.top.findNode("loading").visible = "false"
end sub

sub showContent()
  m.top.findNode("content").visible = "true"
  setPoster()
  setSubtitles()
end sub

sub hideContent()
  m.top.findNode("content").visible = "false"
end sub

sub setPoster()
  m.top.findNode("poster").uri = m.file.screenshot
end sub

sub setSubtitles()
  content = createObject("roSGNode", "ContentNode")

  noSelectionItem = content.createChild("ContentNode")
  noSelectionItem.title = "Don’t load any subtitles"

  for each subtitle in m.subtitles
    listItemData = content.createChild("ContentNode")
    listItemData.title = subtitle.language + " — " + subtitle.name
  end for

  m.subtitleList.checkedItem = 0
  if m.subtitles.count() > 0
    m.subtitleList.checkedItem = 1
  end if
  
  m.subtitleList.visible = "true"
  m.subtitleList.content = content
end sub

sub focusPlayButton()
  m.playButton.setFocus(true)
  configurePlayButtonImage()
end sub

sub unfocusPlaybutton()
  m.playButton.setFocus(false)
  configurePlayButtonImage()
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
  focusPlayButton()
end sub

sub onVideoConversionCompleted()
  m.file = m.videoConversionDialog.convertedFile
  onPlay()
end sub

''' Events
sub onSubtitleSelected()
  focusPlayButton()
  onPlay()
end sub

sub onPlay()
  if m.file.need_convert
    showVideoConversionDialog()
    return
  end if

  if m.subtitleList.checkedItem = 0
    selectedSubtitle = {}
  else if m.subtitles[m.subtitleList.checkedItem] <> invalid
    selectedSubtitle = m.subtitles[m.subtitleList.checkedItem]
  end if

  m.top.navigate = {
    id: "videoPlayerScreen",
    params: {
      file: m.file,
      subtitle: selectedSubtitle,
    }
  }
end sub

function onKeyEvent(key, press)
  if m.top.visible and press
    if key = "back"
      m.top.navigateBack = "true"
      return true
    end if

    if m.playButton.hasFocus()
      if key = "OK"
        onPlay()
        return true
      end if

      if key = "down"
        unfocusPlaybutton()
        m.subtitleList.setFocus(true)
        return true
      end if
    end if

    if m.subtitleList.hasFocus()
      if key = "up"
        m.subtitleList.setFocus(false)
        focusPlayButton()
        return true
      end if
    end if
  end if

  return false
end function
