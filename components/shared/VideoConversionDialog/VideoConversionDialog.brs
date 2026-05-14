sub init()
    m.startConversionTask = createObject("roSGNode", "HttpTask")
    m.checkConversionTask = createObject("roSGNode", "HttpTask")
    m.fetchFileTask = createObject("roSGNode", "HttpTask")

    m.timer = createObject("roSGNode", "Timer")
    m.timer.duration = 2
    m.timer.observeField("fire", "onTimerFired")
end sub

sub onFileIdChange()
    m.top.convertedFile = {}
    m.top.title = "Converting to MP4"
    m.top.message = "Status: Starting..."
    startConversion()
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
        m.top.message = "Status: ERROR"
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

    if data <> invalid and data.mp4 <> invalid and data.mp4.status <> invalid
        message = "Status: " + data.mp4.status

        if data.mp4.percent_done <> invalid
            message = message + " (%" + data.mp4.percent_done.toStr() + ")"
        end if

        m.top.message = message

        if data.mp4.status = "COMPLETED"
            onConversionCompleted()
        else
            m.timer.control = "start"
        end if
    else
        m.top.message = "Status: ERROR"
    end if
end sub

sub onTimerFired()
    checkConversionStatus()
end sub

sub onConversionCompleted()
    refetchConvertedFile()
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
        m.top.convertedFile = data.parent
        m.top.completed = "true"
        m.top.close = "true"
    else
        m.top.message = "Status: ERROR"
    end if
end sub
