function init()
  m.storage = CreateObject("roRegistrySection", "userConfig")
  m.top.observeField("visible", "onVisibleChange")

  m.keyboard = m.top.findNode("keyboard")
  m.keyboard.setFocus(true)
  m.keyboard.observeField("text", "onKeywordChange")

  m.loading = m.top.findNode("loading")
  m.searchFileList = m.top.findNode("searchFileList")
  m.searchFileList.observeField("itemSelected", "onFileSelected")
  m.searchFileList.visible = false

  m.searchTask = createObject("roSGNode", "HttpTask")
  m.files = []

  m.searchResultGroup = m.top.findNode("searchResultGroup")

  m.searchHistory = m.top.findNode("searchHistory")
  m.searchHistory.observeField("itemSelected", "onHistoryItemSelected")

  m.fetchSearchHistory = createObject("roSGNode", "HttpTask")
  m.putSearchHistory = createObject("roSGNode", "HttpTask")
end function

function getSearchHistory()
  return m.searchHistoryItems
end function

sub setSearchHistory(text)
  historyItems = getSearchHistory()
  historyItemsTemp = CreateObject("roArray", historyItems.Count(), true)

  historyItemsTemp.Push(text)
  for each historyItem in historyItems
    if historyItem <> text and historyItemsTemp.Count() < 6
      historyItemsTemp.Push(historyItem)
    end if
  end for

  m.searchHistoryItems = historyItemsTemp
  putSearchHistory(m.searchHistoryItems)
end sub

sub updateSearchHistoryButtons(keyword)
  if m.keyboard.text.Len() = 0
    m.searchResultGroup.insertChild(m.searchHistory, 0)
    content = createObject("roSGNode", "ContentNode")
    for each historyItem in getSearchHistory()
      label = content.createChild("ContentNode")
      label.title = historyItem
    end for

    m.searchHistory.content = content
    m.searchHistory.visible = true
  else
    m.searchResultGroup.removeChild(m.searchHistory)
    m.searchHistory.visible = false
  end if
  ' STOP
end sub

sub onVisibleChange()
  if m.top.visible
    if m.keyboard.text = "" or m.keyboard.text = invalid
      fetchSearchHistory()
    end if
    m.keyboard.setFocus(true)
    updateSearchHistoryButtons(m.keyboard.text)
  end if
end sub

sub onKeywordChange(obj)
  keyword = obj.getData()
  updateSearchHistoryButtons(keyword)

  if keyword <> invalid and len(keyword) > 0
    showLoading()
    onSearch(keyword)
  else
    m.files = []
    configureFileList()
  end if
end sub

sub onSearch(keyword)
  m.searchTask.observeField("response", "onSearchResponse")
  if toBool(m.storage.read("show_only_media_files"))
    keyword = (keyword + " type:FOLDER,AUDIO,VIDEO,IMAGE")
  end if
  m.searchTask.url = "/files/search/" + keyword.encodeUri() + "/page/1"
  m.searchTask.method = "GET"
  m.searchTask.control = "RUN"
end sub

sub onSearchResponse(obj)
  m.searchTask.unobserveField("response")
  data = parseJSON(obj.getData())

  if data <> invalid
    if data.files <> invalid
      m.files = data.files
      configureFileList()
    else
      showErrorDialog(data)
    end if
  end if

  hideLoading()
end sub

''' Events
sub onFileSelected(obj)
  file = m.searchFileList.content.getChild(obj.getData()).file

  if isFileSupported(file)
    setSearchHistory(m.keyboard.text)
    navigateToFile(file)
  else
    showFileNotSupportedDialog()
  end if
end sub

sub onHistoryItemSelected(obj)
  m.keyboard.text = m.searchHistory.content.getChild(obj.getData()).title
  updateSearchHistoryButtons(m.keyboard.text)
  m.searchFileList.setFocus(true)
end sub

sub onFileNotSupportedDialogClosed()
  m.searchFileList.setFocus(true)
end sub

''' UI
sub showLoading()
  m.loading.visible = "true"
end sub

sub hideLoading()
  m.loading.visible = "false"
end sub

sub configureFileList()
  content = createObject("roSGNode", "ContentNode")

  for each file in m.files
    listItemData = content.createChild("FileListItemData")
    listItemData.file = file
  end for

  m.searchFileList.visible = m.files.Count() > 0
  m.searchFileList.content = content
end sub

''' Error Dialog
sub showErrorDialog(data)
  m.errorDialog = createObject("roSGNode", "ErrorDialog")
  m.errorDialog .error = data
  m.errorDialog .observeField("wasClosed", "onErrorDialogClosed")
  m.top.showDialog = m.errorDialog
end sub

sub onErrorDialogClosed()
  m.errorDialog.unobserveField("wasClosed")
end sub

''' API
sub fetchSearchHistory()
  m.fetchSearchHistory.observeField("response", "onFetchSearchHistory")
  m.fetchSearchHistory.url = "/config/search_history"
  m.fetchSearchHistory.method = "GET"
  m.fetchSearchHistory.control = "RUN"
end sub

sub putSearchHistory(historyItems)
  if historyItems = invalid
    historyItems = []
  end if
  m.putSearchHistory.observeField("response", "onPutSearchHistory")
  m.putSearchHistory.url = "/config/search_history"
  m.putSearchHistory.body = { value: historyItems }
  m.putSearchHistory.method = "PUT"
  m.putSearchHistory.control = "RUN"
end sub

sub onPutSearchHistory(obj)
  m.putSearchHistory.unobserveField("response")
  ' if there is an error, just skip
  fetchSearchHistory()
end sub

sub onFetchSearchHistory(obj)
  m.fetchSearchHistory.unobserveField("response")
  data = parseJSON(obj.getData())

  if data <> invalid
    if data.value <> invalid
      m.searchHistoryItems = data.value
      updateSearchHistoryButtons(m.keyboard.text)
    else if data.status_code = 404 or data.status = "OK"
      putSearchHistory(invalid)
    end if
  end if
end sub

function onKeyEvent(key, press)
  if m.top.visible and press
    if key = "back"
      m.keyboard.text = ""
      m.top.navigateBack = "true"
      return true
    else if key = "left"
      if m.searchHistory.isInFocusChain()
        m.keyboard.setFocus(true)
        return true
      else if m.searchFileList.isInFocusChain()
        m.keyboard.setFocus(true)
        return true
      end if
      return false
    else if key = "right"
      if m.keyboard.isInFocusChain()
        if m.searchHistory.visible
          m.searchHistory.setFocus(true)
          return true
        else if m.searchFileList.visible
          m.searchFileList.setFocus(true)
          return true
        end if
      end if
      return false
    end if
    return false
  end if

  return false
end function
