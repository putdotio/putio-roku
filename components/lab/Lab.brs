sub init()
    m.storyList = m.top.findNode("storyList")
    m.background = m.top.findNode("background")
    m.listView = m.top.findNode("listView")
    m.detailView = m.top.findNode("detailView")
    m.title = m.top.findNode("title")
    m.subtitle = m.top.findNode("subtitle")
    m.listDivider = m.top.findNode("listDivider")
    m.listStorySection = m.top.findNode("listStorySection")
    m.listStoryTitle = m.top.findNode("listStoryTitle")
    m.listStoryDescription = m.top.findNode("listStoryDescription")
    m.storySection = m.top.findNode("storySection")
    m.storyTitle = m.top.findNode("storyTitle")
    m.storyDescription = m.top.findNode("storyDescription")
    m.previewHost = m.top.findNode("previewHost")
    m.pendingStoryId = ""
    m.focusedStoryRowIndex = -1
    m.currentStoryIndex = 0
    m.currentPreview = invalid
    m.viewMode = "list"
    m.dialogPreviewTranslation = [0, 0]
    m.rowPreviewTranslation = [340, 240]
    applyLabStyle()

    m.stories = [
        {
            id: "app-dialog-empty",
            title: "AppDialog / no message",
            listTitle: "App / empty",
            section: "Dialogs",
            description: "Exit-style dialog. Two buttons, no body text, compact vertical rhythm.",
            component: "appDialog",
        },
        {
            id: "app-dialog-message",
            title: "AppDialog / message",
            listTitle: "App / message",
            section: "Dialogs",
            description: "Generic settings or playback error dialog with a body message and one action.",
            component: "appDialog",
        },
        {
            id: "delete-dialog-short",
            title: "DeleteFileDialog / short file",
            listTitle: "Delete / short",
            section: "Dialogs",
            description: "Delete confirmation with a normal filename and Cancel focused by default.",
            component: "deleteDialog",
        },
        {
            id: "delete-dialog-long",
            title: "DeleteFileDialog / long file",
            listTitle: "Delete / long",
            section: "Dialogs",
            description: "Long filename wrap check.",
            component: "deleteDialog",
        },
        {
            id: "continue-watching",
            title: "ContinueWatchingPrompt",
            listTitle: "Continue",
            section: "Playback",
            description: "Resume/start-over modal with Continue focused.",
            component: "continueWatching",
        },
        {
            id: "continue-watching-beginning",
            title: "ContinueWatchingPrompt / beginning",
            listTitle: "Continue / start",
            section: "Playback",
            description: "Same modal with Start from the beginning focused.",
            component: "continueWatching",
        },
        {
            id: "track-menu-audio",
            title: "TrackMenu / audio",
            listTitle: "Tracks / audio",
            section: "Playback",
            description: "Audio track selection menu with a selected track marker.",
            component: "trackMenu",
        },
        {
            id: "track-menu-subtitles",
            title: "TrackMenu / subtitles",
            listTitle: "Tracks / subtitles",
            section: "Playback",
            description: "Subtitle track selection menu with Off plus language options.",
            component: "trackMenu",
        },
        {
            id: "track-menu-subtitles-scroll",
            title: "TrackMenu / subtitles scroll",
            listTitle: "Tracks / scroll",
            section: "Playback",
            description: "Subtitle menu overflow state with top and bottom scroll separators.",
            component: "trackMenu",
        },
        {
            id: "track-menu-speed",
            title: "TrackMenu / playback speed",
            listTitle: "Tracks / speed",
            section: "Playback",
            description: "Playback speed selection menu with the current rate selected.",
            component: "trackMenu",
        },
        {
            id: "conversion-status-converting",
            title: "VideoConversionStatus / converting",
            listTitle: "Conversion",
            section: "Playback",
            description: "Preparing video panel with filename, progress, status, and cancel action.",
            component: "conversionStatus",
        },
        {
            id: "conversion-status-error",
            title: "VideoConversionStatus / error",
            listTitle: "Conversion / error",
            section: "Playback",
            description: "Conversion failure state with Retry action.",
            component: "conversionStatus",
        },
        {
            id: "list-item-generic",
            title: "ListItem",
            listTitle: "Rows / generic",
            section: "Rows",
            description: "Home and Settings style rows with icon, title, and secondary value.",
            component: "listItem",
        },
        {
            id: "list-item-files",
            title: "FileListItem",
            listTitle: "Rows / files",
            section: "Rows",
            description: "Files list rows with file type icons, metadata, watched state, and loading state.",
            component: "listItem",
        },
        {
            id: "list-item-file-watched-focused",
            title: "FileListItem / watched focused",
            listTitle: "Rows / watched",
            section: "Rows",
            description: "Focused file row with the watched eye inset from the trailing edge.",
            component: "listItem",
        },
        {
            id: "list-item-file-loading-focused",
            title: "FileListItem / loading focused",
            listTitle: "Rows / loading",
            section: "Rows",
            description: "Focused file row with the loading spinner inset from the trailing edge.",
            component: "listItem",
        },
        {
            id: "list-item-history",
            title: "HistoryListItem",
            listTitle: "Rows / history",
            section: "Rows",
            description: "History event rows with event-specific icon, title, metadata, and loading state.",
            component: "listItem",
        },
    ]

    m.storyList.observeField("itemFocused", "onStoryFocused")
    m.storyList.observeField("itemSelected", "onStorySelected")
    renderStoryList()
    if m.top.story <> invalid and m.top.story <> ""
        selectStoryById(m.top.story, true)
    else
        selectStoryById("", false)
    end if
end sub

sub applyLabStyle()
    setDialogNodeColor(m.background, "appBackground")
    setDialogNodeColor(m.title, "text")
    setDialogNodeColor(m.subtitle, "textMuted")
    setDialogNodeColor(m.listDivider, "border")
    setDialogNodeColor(m.listStorySection, "textMuted")
    setDialogNodeColor(m.listStoryTitle, "text")
    setDialogNodeColor(m.listStoryDescription, "textMuted")
    setDialogNodeColor(m.storySection, "textMuted")
    setDialogNodeColor(m.storyTitle, "text")
    setDialogNodeColor(m.storyDescription, "textMuted")
end sub

sub onStoryLaunchArgChange()
    if m.stories = invalid
        m.pendingStoryId = m.top.story
        return
    end if

    selectStoryById(m.top.story, true)
end sub

sub renderStoryList()
    content = createObject("roSGNode", "ContentNode")
    m.storyRows = []
    lastSection = ""

    for i = 0 to m.stories.count() - 1
        story = m.stories[i]
        if story.section <> lastSection
            sectionItem = content.createChild("LabStoryListItemData")
            sectionItem.title = story.section
            sectionItem.section = story.section
            sectionItem.isSection = true
            m.storyRows.push({
                isSection: true,
                section: story.section,
                storyIndex: -1,
            })
            lastSection = story.section
        end if

        item = content.createChild("LabStoryListItemData")
        item.title = story.listTitle
        item.section = story.section
        item.storyId = story.id
        item.storyIndex = i
        item.isSection = false
        m.storyRows.push({
            isSection: false,
            section: story.section,
            storyIndex: i,
        })
    end for

    m.storyList.content = content
end sub

sub selectStoryById(storyId as string, openDetail = false)
    if storyId = invalid or storyId = ""
        storyId = m.pendingStoryId
    end if

    selectedStoryIndex = 0
    if storyId <> invalid and storyId <> ""
        for i = 0 to m.stories.count() - 1
            if m.stories[i].id = storyId
                selectedStoryIndex = i
                exit for
            end if
        end for
    end if

    selectedRowIndex = findRowIndexForStoryIndex(selectedStoryIndex)
    m.focusedStoryRowIndex = selectedRowIndex
    m.currentStoryIndex = selectedStoryIndex
    m.storyList.jumpToItem = selectedRowIndex

    if openDetail
        renderStory(selectedStoryIndex)
    else
        updateListStoryDetails(selectedStoryIndex)
        showListMode()
    end if
end sub

sub onStoryFocused(obj)
    renderStoryForRow(obj.getData(), false)
end sub

sub onStorySelected(obj)
    renderStoryForRow(obj.getData(), true)
end sub

sub renderStoryForRow(rowIndex as integer, openDetail = false)
    if m.storyRows = invalid or rowIndex < 0 or rowIndex >= m.storyRows.count()
        return
    end if

    row = m.storyRows[rowIndex]
    if row.isSection
        nextRowIndex = getNearestStoryRowIndex(rowIndex)
        if nextRowIndex <> rowIndex
            m.storyList.jumpToItem = nextRowIndex
            renderStoryForRow(nextRowIndex, openDetail)
        end if
        return
    end if

    m.focusedStoryRowIndex = rowIndex
    m.currentStoryIndex = row.storyIndex
    updateListStoryDetails(row.storyIndex)

    if openDetail
        renderStory(row.storyIndex)
    end if
end sub

function getNearestStoryRowIndex(rowIndex as integer) as integer
    direction = 1
    if m.focusedStoryRowIndex >= 0 and rowIndex < m.focusedStoryRowIndex
        direction = -1
    end if

    nextIndex = findStoryRowIndex(rowIndex, direction)
    if nextIndex >= 0
        return nextIndex
    end if

    nextIndex = findStoryRowIndex(rowIndex, -direction)
    if nextIndex >= 0
        return nextIndex
    end if

    return rowIndex
end function

function findStoryRowIndex(rowIndex as integer, direction as integer) as integer
    i = rowIndex + direction
    while i >= 0 and i < m.storyRows.count()
        if not m.storyRows[i].isSection
            return i
        end if
        i = i + direction
    end while

    return -1
end function

function findRowIndexForStoryIndex(storyIndex as integer) as integer
    if m.storyRows = invalid
        return 0
    end if

    for i = 0 to m.storyRows.count() - 1
        row = m.storyRows[i]
        if not row.isSection and row.storyIndex = storyIndex
            return i
        end if
    end for

    return 0
end function

sub updateListStoryDetails(index as integer)
    if index < 0 or index >= m.stories.count()
        return
    end if

    story = m.stories[index]
    m.listStorySection.text = UCase(story.section)
    m.listStoryTitle.text = story.title
    m.listStoryDescription.text = story.description
    m.storySection.text = UCase(story.section)
    m.storyTitle.text = story.title
    m.storyDescription.text = story.description
end sub

sub showListMode()
    m.viewMode = "list"
    m.listView.visible = true
    m.detailView.visible = false
    clearPreviewHost()
    m.storyList.setFocus(true)
end sub

sub showDetailMode()
    m.viewMode = "detail"
    m.listView.visible = false
    m.detailView.visible = true
    m.top.setFocus(true)
end sub

sub renderStory(index as integer)
    if index < 0 or index >= m.stories.count()
        return
    end if

    m.currentStoryIndex = index
    updateListStoryDetails(index)
    story = m.stories[index]
    m.currentStoryId = story.id
    showDetailMode()
    hideStories()

    if story.id = "app-dialog-empty"
        renderAppDialogStory("Exit put.io?", "", ["OK", "Cancel"], 1)
    else if story.id = "app-dialog-message"
        renderAppDialogStory("Settings not saved", "Video playback type could not be saved. Please try again.", ["OK"], 0)
    else if story.id = "delete-dialog-short"
        renderDeleteDialogStory("Sintel.mp4")
    else if story.id = "delete-dialog-long"
        renderDeleteDialogStory("codex_sdk_sharing_parent_1778935120168_super_long_filename_that_should_wrap_without_becoming_a_giant_modal.mkv")
    else if story.id = "continue-watching"
        renderContinueWatchingStory(0)
    else if story.id = "continue-watching-beginning"
        renderContinueWatchingStory(1)
    else if story.id = "track-menu-audio"
        renderTrackMenuStory("Audio tracks", getAudioTrackMenuItems(), 1)
    else if story.id = "track-menu-subtitles"
        renderTrackMenuStory("Subtitles", getSubtitleTrackMenuItems(), 0)
    else if story.id = "track-menu-subtitles-scroll"
        renderTrackMenuStory("Subtitles", getSubtitleOverflowTrackMenuItems(), 8)
    else if story.id = "track-menu-speed"
        renderTrackMenuStory("Playback speed", getPlaybackSpeedMenuItems(), 3)
    else if story.id = "conversion-status-converting"
        renderConversionStatusStory("converting")
    else if story.id = "conversion-status-error"
        renderConversionStatusStory("error")
    else if story.id = "list-item-generic"
        renderGenericListItemStory()
    else if story.id = "list-item-files"
        renderFileListItemStory()
    else if story.id = "list-item-file-watched-focused"
        renderFocusedFileListItemStory("watched")
    else if story.id = "list-item-file-loading-focused"
        renderFocusedFileListItemStory("loading")
    else if story.id = "list-item-history"
        renderHistoryListItemStory()
    end if

end sub

sub hideStories()
    clearPreviewHost()
end sub

sub clearPreviewHost()
    while m.previewHost.getChildCount() > 0
        child = m.previewHost.getChild(0)
        m.previewHost.removeChild(child)
    end while

    m.currentPreview = invalid
end sub

sub addPreviewNode(node as object, translation as object, allowFocus = false)
    if translation <> invalid
        node.translation = translation
    end if

    node.visible = true
    m.previewHost.appendChild(node)
    m.currentPreview = node

    if not allowFocus
        disablePreviewFocus(node)
    end if
end sub

sub disablePreviewFocus(node as object)
    if node <> invalid and node.hasField("focusable")
        node.focusable = false
    end if
end sub

sub renderAppDialogStory(title as string, message as string, buttons as object, defaultButton as integer)
    dialog = createObject("roSGNode", "AppDialog")
    dialog.close = false
    dialog.title = title
    dialog.message = message
    dialog.buttons = buttons
    dialog.defaultButton = defaultButton
    addPreviewNode(dialog, m.dialogPreviewTranslation)
end sub

sub renderDeleteDialogStory(fileName as string)
    dialog = createObject("roSGNode", "DeleteFileDialog")
    dialog.file = {
        id: 1001,
        name: fileName,
    }
    addPreviewNode(dialog, m.dialogPreviewTranslation)
end sub

sub renderContinueWatchingStory(focusedButton as integer)
    prompt = createObject("roSGNode", "ContinueWatchingPrompt")
    prompt.fileName = "Sintel.mp4"
    prompt.duration = 888
    prompt.startFrom = 366
    prompt.focusedButton = focusedButton
    addPreviewNode(prompt, m.dialogPreviewTranslation)
end sub

sub renderTrackMenuStory(title as string, items as object, focusedIndex as integer)
    trackMenu = createObject("roSGNode", "TrackMenu")
    trackMenu.title = title
    trackMenu.items = items
    trackMenu.focusedIndex = focusedIndex
    addPreviewNode(trackMenu, m.dialogPreviewTranslation)
end sub

sub renderConversionStatusStory(previewMode as string)
    conversionStatus = createObject("roSGNode", "VideoConversionStatus")
    addPreviewNode(conversionStatus, m.dialogPreviewTranslation)
    conversionStatus.control = "stop"
    conversionStatus.fileId = 1001
    conversionStatus.fileName = "Sintel.2010.1080p.BluRay.x264.mp4"
    conversionStatus.previewMode = previewMode
end sub

sub renderGenericListItemStory()
    content = createObject("roSGNode", "ContentNode")
    addGenericListItem(content, "file-folder", "Files", "Browse your put.io files", "")
    addGenericListItem(content, "search", "Search", "Find media by name", "")
    addGenericListItem(content, "history", "History", "Enabled", "right")
    addGenericListItem(content, "settings", "Settings", "Playback type: Direct", "right")

    list = createPreviewMarkupList("ListItem")
    list.content = content
    list.jumpToItem = 0
    addPreviewNode(list, invalid, true)
end sub

sub renderFileListItemStory()
    content = createObject("roSGNode", "ContentNode")
    addFileListItem(content, "Sintel.mp4", "VIDEO", 734003200, "2026-05-18T18:42:00Z", 366, false)
    addFileListItem(content, "Camera Uploads", "FOLDER", 0, "2026-05-17T15:14:00Z", 0, false)
    addFileListItem(content, "Roadtrip Mix.flac", "AUDIO", 119537664, "2026-05-15T09:05:00Z", 0, false)
    addFileListItem(content, "Still loading metadata.mkv", "VIDEO", 0, "2026-05-12T21:30:00Z", 0, true)

    list = createPreviewMarkupList("FileListItem")
    list.content = content
    list.jumpToItem = 0
    addPreviewNode(list, invalid, true)
end sub

sub renderFocusedFileListItemStory(state as string)
    isLoading = state = "loading"
    startFrom = 366
    fileName = "Sintel.mp4"

    if isLoading
        startFrom = 0
        fileName = "Still loading metadata.mkv"
    end if

    item = createObject("roSGNode", "FileListItemData")
    item.file = {
        id: 1001,
        name: fileName,
        file_type: "VIDEO",
        size: 734003200,
        created_at: "2026-05-18T18:42:00Z",
        start_from: startFrom,
    }
    item.isLoading = isLoading
    item.rowWidth = 1240

    fileListItem = createObject("roSGNode", "FileListItem")
    fileListItem.translation = m.rowPreviewTranslation
    addPreviewNode(fileListItem, invalid, true)
    fileListItem.itemContent = item
    fileListItem.itemHasFocus = true
end sub

sub renderHistoryListItemStory()
    content = createObject("roSGNode", "ContentNode")
    addHistoryListItem(content, {
        type: "upload",
        file_name: "Sintel.mp4",
        file_size: 734003200,
        created_at: "2026-05-18T18:42:00Z",
    }, false)
    addHistoryListItem(content, {
        type: "transfer_completed",
        transfer_name: "Planet Earth II S01E01",
        transfer_size: 1073741824,
        created_at: "2026-05-17T12:20:00Z",
    }, false)
    addHistoryListItem(content, {
        type: "file_shared",
        file_name: "Family Photos.zip",
        sharing_user_name: "Ayse",
        created_at: "2026-05-16T08:10:00Z",
    }, false)
    addHistoryListItem(content, {
        type: "transfer_error",
        transfer_name: "Ubuntu archive mirror",
        created_at: "2026-05-15T22:30:00Z",
    }, true)

    list = createPreviewMarkupList("HistoryListItem")
    list.content = content
    list.jumpToItem = 0
    addPreviewNode(list, invalid, true)
end sub

function createPreviewMarkupList(itemComponentName as string) as object
    list = createObject("roSGNode", "MarkupList")
    list.itemComponentName = itemComponentName
    list.translation = m.rowPreviewTranslation
    list.itemSize = [1240, 120]
    list.itemSpacing = [0, 30]
    list.drawFocusFeedback = false
    list.vertFocusAnimationStyle = "fixedFocus"
    list.numRows = 4

    return list
end function

sub addGenericListItem(content as object, iconName as string, title as string, description as string, valueAlign as string)
    item = content.createChild("ListItemData")
    item.iconName = iconName
    item.title = title
    item.description = description
    item.valueAlign = valueAlign
    item.rowWidth = 1240
end sub

sub addFileListItem(content as object, name as string, fileType as string, size as integer, createdAt as string, startFrom as integer, isLoading as boolean)
    item = content.createChild("FileListItemData")
    item.file = {
        id: content.getChildCount() + 1001,
        name: name,
        file_type: fileType,
        size: size,
        created_at: createdAt,
        start_from: startFrom,
    }
    item.isLoading = isLoading
    item.rowWidth = 1240
end sub

sub addHistoryListItem(content as object, event as object, isLoading as boolean)
    item = content.createChild("HistoryListItemData")
    item.event = event
    item.isLoading = isLoading
    item.rowWidth = 1240
end sub

function getAudioTrackMenuItems() as object
    return [
        { label: "English stereo", selected: false },
        { label: "Turkish stereo", selected: true },
        { label: "Japanese 5.1", selected: false },
        { label: "Commentary", selected: false },
    ]
end function

function getSubtitleTrackMenuItems() as object
    return [
        { label: "Off", selected: true },
        { label: "English", selected: false },
        { label: "Turkish", selected: false },
        { label: "German", selected: false },
        { label: "Spanish", selected: false },
    ]
end function

function getSubtitleOverflowTrackMenuItems() as object
    return [
        { label: "Off", selected: false },
        { label: "English", selected: false },
        { label: "Turkish", selected: true },
        { label: "German", selected: false },
        { label: "Spanish", selected: false },
        { label: "Portuguese", selected: false },
        { label: "French", selected: false },
        { label: "Italian", selected: false },
        { label: "Dutch", selected: false },
        { label: "Polish", selected: false },
    ]
end function

function getPlaybackSpeedMenuItems() as object
    return [
        { label: "0.25x", selected: false },
        { label: "0.5x", selected: false },
        { label: "0.75x", selected: false },
        { label: "1x", selected: true },
        { label: "1.25x", selected: false },
        { label: "1.5x", selected: false },
        { label: "1.75x", selected: false },
        { label: "2x", selected: false },
    ]
end function

function onKeyEvent(key as string, press as boolean) as boolean
    normalizedKey = normalizeKey(key)

    if m.viewMode = "list"
        if press = false
            return normalizedKey = "ok" or normalizedKey = "select" or normalizedKey = "right"
        end if

        if normalizedKey = "ok" or normalizedKey = "select" or normalizedKey = "right"
            renderStoryForRow(m.storyList.itemFocused, true)
            return true
        end if

        return false
    end if

    if press = false
        return normalizedKey = "back" or normalizedKey = "left" or normalizedKey = "info" or normalizedKey = "options" or normalizedKey = "ok" or normalizedKey = "select" or normalizedKey = "right"
    end if

    if normalizedKey = "back" or normalizedKey = "left" or normalizedKey = "info" or normalizedKey = "options"
        showListMode()
        return true
    else if normalizedKey = "ok" or normalizedKey = "select" or normalizedKey = "right"
        return focusStoryPreview()
    end if

    return false
end function

function focusStoryPreview() as boolean
    if m.currentStoryId = invalid or m.currentStoryId = ""
        return false
    end if

    if m.currentPreview = invalid
        return false
    end if

    if m.currentStoryId = "list-item-generic"
        m.currentPreview.setFocus(true)
        return true
    else if m.currentStoryId = "list-item-files"
        m.currentPreview.setFocus(true)
        return true
    else if m.currentStoryId = "list-item-file-watched-focused" or m.currentStoryId = "list-item-file-loading-focused"
        m.currentPreview.itemHasFocus = true
        return true
    else if m.currentStoryId = "list-item-history"
        m.currentPreview.setFocus(true)
        return true
    end if

    return false
end function
