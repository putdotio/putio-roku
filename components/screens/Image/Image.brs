function init()
    m.top.observeField("visible", "onVisibleChange")
    applyAppOverhangColors(m.top.findNode("overhang"))

    m.image = m.top.findNode("renderedImage")
    m.loading = m.top.findNode("loading")
    m.overhang = m.top.findNode("overhang")

    m.image.observeField("loadStatus", "onImageLoad")
    layoutImage()
end function

sub onVisibleChange()
    if m.top.visible
        layoutImage()
        m.image.visible = "false"
        m.loading.visible = "true"
        m.image.uri = (m.global.apiURL + "/files/" + m.top.params.fileId.toStr() + "/download?oauth_token=" + m.global.user.download_token.toStr() + "")
        m.overhang.title = m.top.params.fileName
    else
        m.image.uri = ""
    end if
end sub

sub onImageLoad()
    if m.image.loadStatus = "ready"
        m.loading.visible = "false"
        m.image.visible = "true"
    else if m.image.loadStatus = "failed"
        showImageErrorDialog()
    end if
end sub

sub layoutImage()
    marginX = 96
    topY = 160
    bottomY = 96
    viewportWidth = getImageViewportWidth()
    viewportHeight = getImageViewportHeight()

    m.image.translation = [marginX, topY]
    m.image.width = viewportWidth - (marginX * 2)
    m.image.height = viewportHeight - topY - bottomY
end sub

function getImageViewportWidth() as integer
    parent = m.top.getParent()
    if parent <> invalid and parent.width <> invalid and parent.width > 0
        return parent.width
    end if

    return 1920
end function

function getImageViewportHeight() as integer
    parent = m.top.getParent()
    if parent <> invalid and parent.height <> invalid and parent.height > 0
        return parent.height
    end if

    return 1080
end function

sub onImageLoadErrorDialogClosed()
    m.top.navigateBack = true
end sub

sub showImageErrorDialog()
    m.imageLoadErrorDialog = createObject("roSGNode", "ErrorDialog")
    m.imageLoadErrorDialog.title = "Oops :("
    m.imageLoadErrorDialog.message = "This image can not be loaded!"
    m.imageLoadErrorDialog.observeField("wasClosed", "onImageLoadErrorDialogClosed")
    m.top.showDialog = m.imageLoadErrorDialog
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if shouldTrapModalInput(m.top)
        return true
    end if

    if m.top.visible and press
        normalizedKey = normalizeKey(key)

        if normalizedKey = "back"
            m.top.navigateBack = true
            return true
        else if isOptionsKey(normalizedKey)
            return true
        end if
    end if

    return false
end function
