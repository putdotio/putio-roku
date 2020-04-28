function init()
  m.top.observeField("visible", "onVisibleChange")
  m.poster = m.top.findNode("poster")
  m.playButton = m.top.findNode("button-play")
  m.playButton.observeField("buttonSelected", "onPlay")
  m.spinner = m.top.findNode("spinner")
  m.spinnerAnimation = m.top.FindNode("spinnerAnimation")
  m.message = m.top.findNode("message")
  m.file = {}
  m.subtitles = []
  m.subtitleList = m.top.findNode("subtitleList")
end function

sub onVisibleChange(obj)
  if m.top.visible
    if m.file.id = m.top.params.file.id
      showSubtitles()
    else
      m.file = m.top.params.file
      fetchSubtitles()
    end if

    renderTitle()
    renderPoster()
    m.playButton.setFocus(true)
  end if
end sub

sub fetchSubtitles()
  showSpinner()
  showMessage("Loading...")
  hideSubtitles()

  m.fetchSubtitlesTask = createObject("roSGNode", "HttpTask")
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

  showSubtitles()
end sub

sub renderTitle()
  overhang = m.top.findNode("overhang")
  overhang.title = m.file.name
end sub

sub renderPoster()
  m.poster.uri = m.file.screenshot
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

sub showSubtitles()
  hideSpinner()
  hideMessage()

  content = createObject("roSGNode", "ContentNode")

  noSelectionItem = content.createChild("ContentNode")
  noSelectionItem.title = "No Subtitle"

  for each subtitle in m.subtitles
    listItemData = content.createChild("ContentNode")
    listItemData.title = UCase(subtitle.language_code) + " - " + subtitle.name
  end for

  m.subtitleList.visible = "true"
  m.subtitleList.content = content
end sub

sub hideSubtitles()
  m.subtitles = []
  m.subtitleList.checkedItem = 0
  m.subtitleList.visible = "false"
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

sub onGoBack()
  if m.fetchSubtitlesTask <> invalid
    m.fetchSubtitlesTask.unobserveField("response")
  end if

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
    else if key = "right"
      if m.subtitleList.visible
        m.subtitleList.setFocus(true)
      end if
      return true
    else if key = "left"
      m.playButton.setFocus(true)
      return true
    end if
  end if

  return false
end function
