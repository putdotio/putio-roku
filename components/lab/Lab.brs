sub init()
    m.storyList = m.top.findNode("storyList")
    m.storyTitle = m.top.findNode("storyTitle")
    m.storyDescription = m.top.findNode("storyDescription")
    m.appDialog = m.top.findNode("appDialogStory")
    m.deleteDialog = m.top.findNode("deleteDialogStory")
    m.continueWatchingPrompt = m.top.findNode("continueWatchingStory")
    m.trackMenu = m.top.findNode("trackMenuStory")
    m.appDialogScrim = m.appDialog.findNode("scrim")
    m.deleteDialogScrim = m.deleteDialog.findNode("scrim")
    m.continueWatchingBackdrop = m.continueWatchingPrompt.findNode("backdrop")
    m.pendingStoryId = ""
    m.storyPreviewTranslation = [250, 0]
    hideStoryBackdrops()

    m.stories = [
        {
            id: "app-dialog-empty",
            title: "AppDialog / no message",
            listTitle: "App / empty",
            description: "Exit-style dialog. Two buttons, no body text, compact vertical rhythm.",
            component: "appDialog",
        },
        {
            id: "app-dialog-message",
            title: "AppDialog / message",
            listTitle: "App / message",
            description: "Generic settings or playback error dialog with a body message and one action.",
            component: "appDialog",
        },
        {
            id: "delete-dialog-short",
            title: "DeleteFileDialog / short file",
            listTitle: "Delete / short",
            description: "Delete confirmation with a normal filename and Cancel focused by default.",
            component: "deleteDialog",
        },
        {
            id: "delete-dialog-long",
            title: "DeleteFileDialog / long file",
            listTitle: "Delete / long",
            description: "Long filename wrap check.",
            component: "deleteDialog",
        },
        {
            id: "continue-watching",
            title: "ContinueWatchingPrompt",
            listTitle: "Continue",
            description: "Resume/start-over modal with Continue focused.",
            component: "continueWatching",
        },
        {
            id: "continue-watching-beginning",
            title: "ContinueWatchingPrompt / beginning",
            listTitle: "Continue / start",
            description: "Same modal with Start from the beginning focused.",
            component: "continueWatching",
        },
        {
            id: "track-menu-audio",
            title: "TrackMenu / audio",
            listTitle: "Tracks / audio",
            description: "Audio track selection menu with a selected track marker.",
            component: "trackMenu",
        },
        {
            id: "track-menu-subtitles",
            title: "TrackMenu / subtitles",
            listTitle: "Tracks / subtitles",
            description: "Subtitle track selection menu with Off plus language options.",
            component: "trackMenu",
        },
        {
            id: "track-menu-subtitles-scroll",
            title: "TrackMenu / subtitles scroll",
            listTitle: "Tracks / scroll",
            description: "Subtitle menu overflow state with top and bottom scroll separators.",
            component: "trackMenu",
        },
        {
            id: "track-menu-speed",
            title: "TrackMenu / playback speed",
            listTitle: "Tracks / speed",
            description: "Playback speed selection menu with the current rate selected.",
            component: "trackMenu",
        },
    ]

    m.storyList.observeField("itemFocused", "onStoryFocused")
    m.storyList.observeField("itemSelected", "onStorySelected")
    renderStoryList()
    selectStoryById(m.top.story)
    m.storyList.setFocus(true)
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

    for each story in m.stories
        item = content.createChild("ContentNode")
        item.title = story.listTitle
    end for

    m.storyList.content = content
end sub

sub selectStoryById(storyId as string)
    if storyId = invalid or storyId = ""
        storyId = m.pendingStoryId
    end if

    selectedIndex = 0
    if storyId <> invalid and storyId <> ""
        for i = 0 to m.stories.count() - 1
            if m.stories[i].id = storyId
                selectedIndex = i
                exit for
            end if
        end for
    end if

    m.storyList.jumpToItem = selectedIndex
    renderStory(selectedIndex)
end sub

sub onStoryFocused(obj)
    renderStory(obj.getData())
end sub

sub onStorySelected(obj)
    renderStory(obj.getData())
end sub

sub renderStory(index as integer)
    if index < 0 or index >= m.stories.count()
        return
    end if

    story = m.stories[index]
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
    end if
end sub

sub hideStories()
    m.appDialog.visible = false
    m.deleteDialog.visible = false
    m.continueWatchingPrompt.visible = false
    m.trackMenu.visible = false
    resetStoryTranslations()
end sub

sub resetStoryTranslations()
    m.appDialog.translation = m.storyPreviewTranslation
    m.deleteDialog.translation = m.storyPreviewTranslation
    m.continueWatchingPrompt.translation = m.storyPreviewTranslation
    m.trackMenu.translation = m.storyPreviewTranslation
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
    else if normalizedKey = "info" or normalizedKey = "options"
        m.storyList.setFocus(true)
        return true
    end if

    return false
end function
