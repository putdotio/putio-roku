sub init()
    ensureLabStoryListItemNodes()
end sub

sub ensureLabStoryListItemNodes()
    if m.sectionGroup = invalid
        m.sectionGroup = m.top.findNode("sectionGroup")
        m.storyGroup = m.top.findNode("storyGroup")
        m.focusBackground = m.top.findNode("focusBackground")
        m.sectionLabel = m.top.findNode("sectionLabel")
        m.storyLabel = m.top.findNode("storyLabel")
    end if

    applyListItemFocusBackground(m.focusBackground, 404, 58)
    setDialogNodeColor(m.sectionLabel, "textMuted")
    setDialogNodeColor(m.storyLabel, "text")
end sub

sub onItemContentChanged()
    ensureLabStoryListItemNodes()

    item = m.top.itemContent
    if item = invalid
        return
    end if
    if m.sectionGroup = invalid or m.storyGroup = invalid or m.sectionLabel = invalid or m.storyLabel = invalid
        return
    end if

    if item.isSection
        m.sectionGroup.visible = true
        m.storyGroup.visible = false
        m.sectionLabel.text = UCase(item.title)
    else
        m.sectionGroup.visible = false
        m.storyGroup.visible = true
        m.storyLabel.text = item.title
    end if

    updateFocusBackground()
end sub

sub onItemFocusChanged()
    updateFocusBackground()
end sub

sub updateFocusBackground()
    ensureLabStoryListItemNodes()

    item = m.top.itemContent
    if m.focusBackground <> invalid
        m.focusBackground.visible = item <> invalid and not item.isSection and m.top.itemHasFocus
    end if
end sub
