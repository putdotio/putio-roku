sub init()
    m.top.focusable = true
    m.startConversionTask = createObject("roSGNode", "HttpTask")
    m.checkConversionTask = createObject("roSGNode", "HttpTask")
    m.fetchFileTask = createObject("roSGNode", "HttpTask")
    m.timer = createObject("roSGNode", "Timer")
    m.timer.duration = 5
    m.timer.observeField("fire", "onTimerFired")

    m.fileNameLabel = m.top.findNode("fileNameLabel")
    m.spinner = m.top.findNode("spinner")
    m.progressGroup = m.top.findNode("progressGroup")
    m.progressFill = m.top.findNode("progressFill")
    m.statusLabel = m.top.findNode("statusLabel")
    m.actionLabel = m.top.findNode("actionLabel")
    m.hasError = false
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

sub resetState()
    stopTasks()
    m.hasError = false
    m.top.completedFile = {}
    m.spinner.visible = true
    m.spinner.control = "start"
    m.progressGroup.visible = false
    m.progressFill.width = 0
    m.actionLabel.text = "Cancel"
    setStatus("Starting conversion...")
end sub

sub stopTasks()
    m.timer.control = "stop"
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
        m.progressGroup.visible = false
    end if

    if status = "COMPLETED"
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

    m.progressGroup.visible = true
    m.progressFill.width = int(628 * percent / 100)
end sub

sub setStatus(status as string)
    m.statusLabel.text = status
end sub

sub showError(message as string)
    stopTasks()
    m.hasError = true
    m.spinner.control = "stop"
    m.spinner.visible = false
    m.progressGroup.visible = false
    m.actionLabel.text = "Retry"
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
