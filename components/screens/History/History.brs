function init()
    m.storage = CreateObject("roRegistrySection", "userConfig")

    m.top.observeField("visible", "onVisibleChange")
    m.top.observeField("routeShown", "onRouteShown")
    applyAppOverhangColors(m.top.findNode("overhang"))

    m.parent = {}
    m.history = []
    m.breadcrumbs = []
    m.historyRequestInFlight = false

    m.historyList = m.top.findNode("historyList")
    setDialogNodeFieldColor(m.historyList, "focusBitmapBlendColor", "focus")
    m.historyList.observeField("itemSelected", "onHistoryItemSelected")
    m.emptyState = m.top.findNode("emptyState")

    m.fetchHistoryTask = createObject("roSGNode", "HttpTask")
end function

sub onVisibleChange()
    if m.top.visible
        showHistoryRoute()
    else
        m.fetchHistoryTask.unobserveField("response")
        m.historyRequestInFlight = false
    end if
end sub

sub onRouteShown()
    showHistoryRoute()
end sub

sub showHistoryRoute()
    if m.top.visible = false
        return
    end if

    m.historyList.setFocus(true)
    if m.focusEventId = invalid and m.historyRequestInFlight = false
        hideHistory()
        hideEmptyState()
        showLoading()
        fetchHistory()
    end if
end sub

sub fetchHistory()
    m.historyRequestInFlight = true
    m.fetchHistoryTask = createObject("roSGNode", "HttpTask")
    m.fetchHistoryTask.observeField("response", "onFetchHistoryResponse")
    m.fetchHistoryTask.url = "/events/list"
    m.fetchHistoryTask.method = "GET"
    m.fetchHistoryTask.control = "RUN"
end sub

sub onFetchHistoryResponse(obj)
    m.fetchHistoryTask.unobserveField("response")
    m.historyRequestInFlight = false
    data = parseJSON(obj.getData())

    if data <> invalid and data.events <> invalid
        m.history = data.events
        m.breadcrumbs = data.breadcrumbs
        showHistory()
    else
        showFetchHistoryErrorDialog(data)
    end if
end sub

''' UI
sub showLoading()
    hideEmptyState()
    m.top.findNode("loading").visible = "true"
end sub

sub hideLoading()
    m.top.findNode("loading").visible = "false"
end sub

sub showHistory()
    content = createObject("roSGNode", "ContentNode")

    forIndex = 0
    focusIndex = 0
    for each historyEvent in m.history
        if shouldShowHistoryEvent(historyEvent)
            listItemData = content.createChild("HistoryListItemData")
            listItemData.event = historyEvent

            if historyEvent.id = m.focusEventId
                focusIndex = forIndex
            end if

            forIndex = forIndex + 1
        end if
    end for

    m.historyList.content = content
    if forIndex = 0
        hideHistory()
        showEmptyState()
        hideLoading()
        return
    end if

    hideEmptyState()
    m.historyList.visible = "true"

    if not focusIndex = 0
        m.historyList.jumpToItem = focusIndex
    end if

    hideLoading()
end sub

sub hideHistory()
    m.historyList.visible = "false"
end sub

sub showEmptyState()
    m.emptyState.visible = "true"
end sub

sub hideEmptyState()
    m.emptyState.visible = "false"
end sub

sub onHistoryItemSelected(obj)
    historyListItem = m.historyList.content.getChild(obj.getData())
    event = historyListItem.event

    if canNavigateToEvent(event)
        fetchFilesAndNavigate(event.file_id)
    else
        showFileNotSupportedDialog(onFileNotSupportedDialogClosed)
    end if
end sub

sub fetchFilesAndNavigate(parentId)
    m.fetchFilesTask = createObject("roSGNode", "HttpTask")
    m.fetchFilesTask.observeField("response", "onFetchFilesResponse")
    m.fetchFilesTask.url = ("/files/list?parent_id=" + parentId.toStr() + "&breadcrumbs=1")
    m.fetchFilesTask.method = "GET"
    m.fetchFilesTask.control = "RUN"
end sub

sub onFetchFilesResponse(obj)
    m.fetchFilesTask.unobserveField("response")
    data = parseJSON(obj.getData())

    if data <> invalid and data.parent <> invalid
        file = data.parent
        if isFileSupported(file)
            m.focusEventId = file.id

            navigateToFile(file, file.id)
        else
            showFileNotSupportedDialog(onFileNotSupportedDialogClosed)
        end if
    else
        showFetchFilesErrorDialog(data)
    end if
end sub

''' Error Dialog
sub showFetchFilesErrorDialog(data)
    m.fetchFilesErrorDialog = createObject("roSGNode", "ErrorDialog")
    m.fetchFilesErrorDialog.error = data
    m.fetchFilesErrorDialog.observeField("wasClosed", "onFetchFilesErrorDialogClosed")
    m.top.showDialog = m.fetchFilesErrorDialog
end sub

sub onFetchFilesErrorDialogClosed()
    m.fetchFilesErrorDialog.unobserveField("wasClosed")
    m.historyList.setFocus(true)
end sub


sub canNavigateToEvent(event) as boolean
    return shouldShowHistoryEvent(event)
end sub

function shouldShowHistoryEvent(event) as boolean
    return event <> invalid and (event.type = "file_shared" or event.type = "transfer_completed")
end function

''' Error Dialog
sub showFetchHistoryErrorDialog(data)
    m.fetchHistoryErrorDialog = createObject("roSGNode", "ErrorDialog")
    m.fetchHistoryErrorDialog.error = data
    m.fetchHistoryErrorDialog.observeField("wasClosed", "onFetchHistoryErrorDialogClosed")
    m.top.showDialog = m.fetchHistoryErrorDialog
end sub

sub onFetchHistoryErrorDialogClosed()
    m.fetchHistoryErrorDialog.unobserveField("wasClosed")
    m.historyList.setFocus(true)
end sub

sub onFileNotSupportedDialogClosed()
    m.historyList.setFocus(true)
end sub

''' Key Handler
function onKeyEvent(key as string, press as boolean) as boolean
    if shouldTrapModalInput(m.top)
        return true
    end if

    if m.top.visible and press
        normalizedKey = normalizeKey(key)

        if normalizedKey = "back"
            m.focusEventId = invalid
            m.top.navigateBack = true
            return true
        else if isOptionsKey(normalizedKey)
            return true
        end if

        return false
    end if

    return false
end function
