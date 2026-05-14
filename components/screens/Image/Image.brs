function init()
    m.top.observeField("visible", "onVisibleChange")

    m.image = m.top.findNode("image")
    m.loading = m.top.findNode("loading")
    m.overhang = m.top.findNode("overhang")

    m.image.observeField("loadStatus", "onImageLoad")
end function

sub onVisibleChange()
    if m.top.visible
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

sub onImageLoadErrorDialogClosed()
    m.top.navigateBack = "true"
end sub

sub showImageErrorDialog()
    m.imageLoadErrorDialog = createObject("roSGNode", "ErrorDialog")
    m.imageLoadErrorDialog.title = "Oops :("
    m.imageLoadErrorDialog.message = "This image can not be loaded!"
    m.imageLoadErrorDialog.observeField("wasClosed", "onImageLoadErrorDialogClosed")
    m.top.showDialog = m.imageLoadErrorDialog
end sub

function onKeyEvent(key, press)
    if m.top.visible and press
        if key = "back"
            m.top.navigateBack = "true"
            return true
        end if
    end if

    return false
end function