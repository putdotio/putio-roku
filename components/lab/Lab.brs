sub init()
    m.storyList = m.top.findNode("storyList")
    m.background = m.top.findNode("background")
    m.sidebar = m.top.findNode("sidebar")
    m.sidebarDivider = m.top.findNode("sidebarDivider")
    m.previewWash = m.top.findNode("previewWash")
    m.title = m.top.findNode("title")
    m.subtitle = m.top.findNode("subtitle")
    m.storySection = m.top.findNode("storySection")
    m.storyTitle = m.top.findNode("storyTitle")
    m.storyDescription = m.top.findNode("storyDescription")
    m.appDialog = m.top.findNode("appDialogStory")
    m.deleteDialog = m.top.findNode("deleteDialogStory")
    m.continueWatchingPrompt = m.top.findNode("continueWatchingStory")
    m.trackMenu = m.top.findNode("trackMenuStory")
    m.conversionStatus = m.top.findNode("conversionStatusStory")
    m.genericListItemList = m.top.findNode("genericListItemStory")
    m.fileListItemList = m.top.findNode("fileListItemStory")
    m.historyListItemList = m.top.findNode("historyListItemStory")
    m.appDialogScrim = m.appDialog.findNode("scrim")
    m.deleteDialogScrim = m.deleteDialog.findNode("scrim")
    m.continueWatchingBackdrop = m.continueWatchingPrompt.findNode("backdrop")
    m.conversionStatusBackdrop = m.conversionStatus.findNode("backdrop")
    m.pendingStoryId = ""
    m.focusedStoryRowIndex = -1
    m.storyPreviewTranslation = [250, 0]
    applyLabStyle()
    hideStoryBackdrops()

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
    selectStoryById(m.top.story)
    m.storyList.setFocus(true)
end sub

sub applyLabStyle()
    setDialogNodeColor(m.background, "appBackground")
    setDialogNodeColor(m.sidebar, "appBackground")
    setDialogNodeColor(m.sidebarDivider, "border")
    setDialogNodeColor(m.previewWash, "appBackgroundWash")
    setDialogNodeColor(m.title, "text")
    setDialogNodeColor(m.subtitle, "textMuted")
    setDialogNodeColor(m.storySection, "textMuted")
    setDialogNodeColor(m.storyTitle, "text")
    setDialogNodeColor(m.storyDescription, "textMuted")
end sub

sub onStoryLaunchArgChange()
    if m.stories = invalid
        m.pendingStoryId = m.top.story
        return
    end if

    selectStoryById(m.top.story)
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

sub selectStoryById(storyId as string)
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
    m.storyList.jumpToItem = selectedRowIndex
    renderStory(selectedStoryIndex)
end sub

sub onStoryFocused(obj)
    renderStoryForRow(obj.getData())
end sub

sub onStorySelected(obj)
    renderStoryForRow(obj.getData())
end sub

sub renderStoryForRow(rowIndex as integer)
    if m.storyRows = invalid or rowIndex < 0 or rowIndex >= m.storyRows.count()
        return
    end if

    row = m.storyRows[rowIndex]
    if row.isSection
        nextRowIndex = getNearestStoryRowIndex(rowIndex)
        if nextRowIndex <> rowIndex
            m.storyList.jumpToItem = nextRowIndex
        end if
        return
    end if

    m.focusedStoryRowIndex = rowIndex
    renderStory(row.storyIndex)
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

sub renderStory(index as integer)
    if index < 0 or index >= m.stories.count()
        return
    end if

    story = m.stories[index]
    m.currentStoryId = story.id
    m.storySection.text = UCase(story.section)
    m.storyTitle.text = story.title
    m.storyDescription.text = story.description

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
    else if story.id = "list-item-history"
        renderHistoryListItemStory()
    end if
end sub

sub hideStories()
    m.appDialog.visible = false
    m.deleteDialog.visible = false
    m.continueWatchingPrompt.visible = false
    m.trackMenu.visible = false
    m.conversionStatus.visible = false
    m.conversionStatus.control = "stop"
    m.genericListItemList.visible = false
    m.fileListItemList.visible = false
    m.historyListItemList.visible = false
    resetStoryTranslations()
end sub

sub resetStoryTranslations()
    m.appDialog.translation = m.storyPreviewTranslation
    m.deleteDialog.translation = m.storyPreviewTranslation
    m.continueWatchingPrompt.translation = m.storyPreviewTranslation
    m.trackMenu.translation = m.storyPreviewTranslation
    m.conversionStatus.translation = m.storyPreviewTranslation
    hideStoryBackdrops()
end sub

sub hideStoryBackdrops()
    if m.appDialogScrim <> invalid
        m.appDialogScrim.visible = false
    end if

    if m.deleteDialogScrim <> invalid
        m.deleteDialogScrim.visible = false
    end if

    if m.continueWatchingBackdrop <> invalid
        m.continueWatchingBackdrop.visible = false
    end if

    if m.conversionStatusBackdrop <> invalid
        m.conversionStatusBackdrop.visible = false
    end if
end sub

sub renderAppDialogStory(title as string, message as string, buttons as object, defaultButton as integer)
    m.appDialog.close = false
    m.appDialog.title = title
    m.appDialog.message = message
    m.appDialog.buttons = buttons
    m.appDialog.defaultButton = defaultButton
    m.appDialog.visible = true
end sub

sub renderDeleteDialogStory(fileName as string)
    m.deleteDialog.file = {
        id: 1001,
        name: fileName,
    }
    m.deleteDialog.visible = true
end sub

sub renderContinueWatchingStory(focusedButton as integer)
    m.continueWatchingPrompt.fileName = "Sintel.mp4"
    m.continueWatchingPrompt.duration = 888
    m.continueWatchingPrompt.startFrom = 366
    m.continueWatchingPrompt.focusedButton = focusedButton
    m.continueWatchingPrompt.visible = true
end sub

sub renderTrackMenuStory(title as string, items as object, focusedIndex as integer)
    m.trackMenu.title = title
    m.trackMenu.items = items
    m.trackMenu.focusedIndex = focusedIndex
    m.trackMenu.visible = true
end sub

sub renderConversionStatusStory(previewMode as string)
    m.conversionStatus.control = "stop"
    m.conversionStatus.fileId = 1001
    m.conversionStatus.fileName = "Sintel.2010.1080p.BluRay.x264.mp4"
    m.conversionStatus.previewMode = previewMode
    m.conversionStatus.visible = true
end sub

sub renderGenericListItemStory()
    content = createObject("roSGNode", "ContentNode")
    addGenericListItem(content, "media-gallery-1", "Files", "Browse your put.io files", "")
    addGenericListItem(content, "search", "Search", "Find media by name", "")
    addGenericListItem(content, "history-1", "History", "Enabled", "right")
    addGenericListItem(content, "settings", "Settings", "Playback type: Direct", "right")

    m.genericListItemList.content = content
    m.genericListItemList.jumpToItem = 0
    m.genericListItemList.visible = true
end sub

sub renderFileListItemStory()
    content = createObject("roSGNode", "ContentNode")
    addFileListItem(content, "Sintel.mp4", "VIDEO", 734003200, "2026-05-18T18:42:00Z", 366, false)
    addFileListItem(content, "Camera Uploads", "FOLDER", 0, "2026-05-17T15:14:00Z", 0, false)
    addFileListItem(content, "Roadtrip Mix.flac", "AUDIO", 119537664, "2026-05-15T09:05:00Z", 0, false)
    addFileListItem(content, "Still loading metadata.mkv", "VIDEO", 0, "2026-05-12T21:30:00Z", 0, true)

    m.fileListItemList.content = content
    m.fileListItemList.jumpToItem = 0
    m.fileListItemList.visible = true
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

    m.historyListItemList.content = content
    m.historyListItemList.jumpToItem = 0
    m.historyListItemList.visible = true
end sub

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
    if press = false
        return false
    end if

    normalizedKey = LCase(key)

    if normalizedKey = "ok" or normalizedKey = "select"
        renderStory(m.storyList.itemFocused)
        return true
    else if normalizedKey = "back"
        m.storyList.setFocus(true)
        renderStory(m.storyList.itemFocused)
        return true
    else if normalizedKey = "right"
        return focusStoryPreview()
    else if normalizedKey = "left"
        m.storyList.setFocus(true)
        return true
    else if normalizedKey = "info" or normalizedKey = "options"
        m.storyList.setFocus(true)
        return true
    end if

    return false
end function

function focusStoryPreview() as boolean
    if m.currentStoryId = invalid or m.currentStoryId = ""
        return false
    end if

    if m.currentStoryId = "list-item-generic"
        m.genericListItemList.setFocus(true)
        return true
    else if m.currentStoryId = "list-item-files"
        m.fileListItemList.setFocus(true)
        return true
    else if m.currentStoryId = "list-item-history"
        m.historyListItemList.setFocus(true)
        return true
    end if

    return false
end function
