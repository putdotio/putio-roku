sub init()
    m.top.focusable = true
    m.startConversionTask = createObject("roSGNode", "HttpTask")
    m.checkConversionTask = createObject("roSGNode", "HttpTask")
    m.fetchFileTask = createObject("roSGNode", "HttpTask")
    m.timer = createObject("roSGNode", "Timer")
    m.timer.duration = 5
    m.timer.observeField("fire", "onTimerFired")

    m.backdrop = m.top.findNode("backdrop")
    m.panelFill = m.top.findNode("panelFill")
    m.panelShadow = m.top.findNode("panelShadow")
    m.panelBorderTop = m.top.findNode("panelBorderTop")
    m.panelBorderRight = m.top.findNode("panelBorderRight")
    m.panelBorderBottom = m.top.findNode("panelBorderBottom")
    m.panelBorderLeft = m.top.findNode("panelBorderLeft")
    m.title = m.top.findNode("title")
    m.fileNameLabel = m.top.findNode("fileNameLabel")
    m.spinner = m.top.findNode("spinner")
    m.progressGroup = m.top.findNode("progressGroup")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressFill = m.top.findNode("progressFill")
    m.statusLabel = m.top.findNode("statusLabel")
    m.actionButton = m.top.findNode("actionButton")
    m.actionBackground = m.top.findNode("actionBackground")
    m.actionLabel = m.top.findNode("actionLabel")
    m.hasError = false
    applyDialogScrim(m.backdrop)
    applyDialogPanelColors(m.panelFill, m.panelShadow, m.panelBorderTop, m.panelBorderRight, m.panelBorderBottom, m.panelBorderLeft)
    applyDialogTextColors(m.title, m.fileNameLabel)
    setDialogNodeColor(m.progressTrack, "border")
    setDialogNodeColor(m.progressFill, "primary")
    setDialogNodeColor(m.statusLabel, "textMuted")
    applyDialogButtonState(m.actionBackground, m.actionLabel, true, "secondary")
end sub

sub onFileNameChange()
    m.fileNameLabel.text = m.top.fileName
end sub

sub onControlChange()
    command = LCase(m.top.control)

    if command = "start"
        if m.top.fileId <= 0
            return
        end if

        resetState()
        startConversion()
    else if command = "stop"
        stopTasks()
    end if
end sub

sub onPreviewModeChange()
    if m.statusLabel = invalid
        return
    end if

    mode = LCase(m.top.previewMode)
    if mode = ""
        return
    end if

    stopTasks()
    m.hasError = false
    showSpinner()
    hideProgress()
    m.actionLabel.text = "Cancel"

    if mode = "queued"
        setStatus("Waiting to convert...")
    else if mode = "converting"
        updateProgress(62)
        setStatus("Converting your video...")
    else if mode = "error"
        m.hasError = true
        hideSpinner()
        m.actionLabel.text = "Retry"
        setStatus("Conversion failed.")
    else
        setStatus("Starting conversion...")
    end if
end sub

sub resetState()
    stopTasks()
    m.hasError = false
    m.top.completedFile = {}
    showSpinner()
    hideProgress()
    m.actionLabel.text = "Cancel"
    setStatus("Starting conversion...")
end sub

sub stopTasks()
    m.timer.control = "stop"
    m.startConversionTask.control = "stop"
    m.checkConversionTask.control = "stop"
    m.fetchFileTask.control = "stop"
    m.startConversionTask.unobserveField("response")
    m.checkConversionTask.unobserveField("response")
    m.fetchFileTask.unobserveField("response")
end sub

sub startConversion()
    m.startConversionTask.observeField("response", "onStartConversionResponse")
    m.startConversionTask.url = ("/files/" + m.top.fileId.toStr() + "/mp4")
    m.startConversionTask.method = "POST"
    m.startConversionTask.control = "RUN"
end sub

sub onStartConversionResponse(obj)
    m.startConversionTask.unobserveField("response")
    data = parseJSON(obj.getData())

    if data <> invalid and data.status <> invalid and data.status = "OK"
        checkConversionStatus()
    else
        showError("Conversion could not be started.")
    end if
end sub

sub checkConversionStatus()
    m.checkConversionTask.observeField("response", "onCheckConversionStatusResponse")
    m.checkConversionTask.url = ("/files/" + m.top.fileId.toStr() + "/mp4")
    m.checkConversionTask.method = "GET"
    m.checkConversionTask.control = "RUN"
end sub

sub onCheckConversionStatusResponse(obj)
    m.checkConversionTask.unobserveField("response")
    data = parseJSON(obj.getData())

    if data = invalid or data.mp4 = invalid or data.mp4.status = invalid
        showError("Conversion status could not be checked.")
        return
    end if

    status = data.mp4.status

    if data.mp4.percent_done <> invalid
        updateProgress(data.mp4.percent_done)
    else
        showSpinner()
        hideProgress()
    end if

    if status = "COMPLETED"
        hideSpinner()
        setStatus("Conversion complete.")
        refetchConvertedFile()
    else if status = "ERROR"
        showError("Conversion failed.")
    else if status = "NOT_AVAILABLE"
        showError("This file cannot be converted.")
    else
        if status = "IN_QUEUE"
            setStatus("Waiting to convert...")
        else if status = "CONVERTING"
            setStatus("Converting your video...")
        else
            setStatus("Preparing video...")
        end if

        m.timer.control = "start"
    end if
end sub

sub onTimerFired()
    checkConversionStatus()
end sub

sub refetchConvertedFile()
    m.fetchFileTask.observeField("response", "onFetchFileResponse")
    m.fetchFileTask.url = ("/files/list?parent_id=" + m.top.fileId.toStr() + "&mp4_status_parent=1&stream_url_parent=1&mp4_stream_url_parent=1&video_metadata_parent=1")
    m.fetchFileTask.method = "GET"
    m.fetchFileTask.control = "RUN"
end sub

sub onFetchFileResponse(obj)
    m.fetchFileTask.unobserveField("response")
    data = parseJSON(obj.getData())

    if data <> invalid and data.parent <> invalid
        stopTasks()
        m.top.completedFile = data.parent
        m.top.completed = true
    else
        showError("Converted video could not be loaded.")
    end if
end sub

sub updateProgress(percentDone)
    percent = percentDone
    if percent < 0
        percent = 0
    else if percent > 100
        percent = 100
    end if

    hideSpinner()
    m.progressGroup.visible = true
    m.progressFill.width = int(672 * percent / 100)
    m.statusLabel.translation = [64, 244]
    m.actionButton.translation = [240, 324]
end sub

sub showSpinner()
    m.spinner.visible = true
    m.spinner.control = "start"
    m.statusLabel.translation = [64, 274]
    m.actionButton.translation = [240, 328]
end sub

sub hideSpinner()
    m.spinner.control = "stop"
    m.spinner.visible = false
end sub

sub hideProgress()
    m.progressGroup.visible = false
    m.progressFill.width = 0
end sub

sub setStatus(status as string)
    m.statusLabel.text = status
end sub

sub showError(message as string)
    stopTasks()
    m.hasError = true
    hideSpinner()
    hideProgress()
    m.actionLabel.text = "Retry"
    m.statusLabel.translation = [64, 224]
    m.actionButton.translation = [240, 304]
    setStatus(message)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if m.top.visible and press
        normalizedKey = LCase(key)

        if normalizedKey = "back"
            stopTasks()
            m.top.dismissed = true
        else if normalizedKey = "ok" or normalizedKey = "select"
            if m.hasError
                resetState()
                startConversion()
            else
                stopTasks()
                m.top.dismissed = true
            end if
        else
            return false
        end if

        return true
    end if

    return false
end function
