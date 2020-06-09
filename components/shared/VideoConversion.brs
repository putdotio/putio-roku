''' Video Conversion
sub startConversion()
  m.startConversionTask = createObject("roSGNode", "HttpTask")
  m.startConversionTask.observeField("response", "onStartConversionResponse")
  m.startConversionTask.url = ("/files/" + m.convertingFile.id.toStr() + "/mp4")
  m.startConversionTask.method = "POST"
  m.startConversionTask.control = "RUN"
end sub

sub onStartConversionResponse(obj)
  m.startConversionTask.unobserveField("response")
  data = parseJSON(obj.getData())
  if data.status <> invalid and data.status = "OK"
    m.shouldCheckConversionStatus = true
    checkConversionStatus()
  else
    m.shouldCheckConversionStatus = false
    m.conversionDialog.message = "Status: ERROR"
  end if
end sub

sub checkConversionStatus()
  if m.shouldCheckConversionStatus = true
    m.checkConversionTask = createObject("roSGNode", "HttpTask")
    m.checkConversionTask.observeField("response", "onCheckConversionStatusResponse")
    m.checkConversionTask.url = ("/files/" + m.convertingFile.id.toStr() + "/mp4")
    m.checkConversionTask.method = "GET"
    m.checkConversionTask.control = "RUN"
  end if
end sub

sub onCheckConversionStatusResponse(obj)
  m.checkConversionTask.unobserveField("response")
  data = parseJSON(obj.getData())

  if data.mp4 <> invalid and data.mp4.status <> invalid
    message = "Status: " + data.mp4.status

    if data.mp4.percent_done <> invalid
      message = message + " (%" + data.mp4.percent_done.toStr() + ")"
    end if

    m.conversionDialog.message = message

    if data.mp4.status = "COMPLETED"
      onConversionFinished()
    else
      sleep(2000)
      checkConversionStatus()
    end if
  else
    m.shouldCheckConversionStatus = false
    m.conversionDialog.message = "Status: ERROR"
  end if
end sub

sub onConversionFinished()
  m.shouldCheckConversionStatus = false
  m.conversionDialog.close = true
  m.top.navigate = {
    id: "videoScreen",
    params: {
      file: m.convertingFile
    }
  }
  m.convertingFile = {}
end sub

''' Video Conversion Dialog
sub showConversionDialog(file)
  m.convertingFile = file
  m.conversionDialog = createObject("roSGNode", "Dialog")
  m.conversionDialog.title = "Converting to MP4"
  m.conversionDialog.message = "Status: Starting..."
  m.conversionDialog.observeField("wasClosed", "onConversionDialogClosed")
  m.top.showDialog = m.conversionDialog
  startConversion()
end sub

sub onConversionDialogClosed()
  m.conversionDialog.unobserveField("wasClosed")
  m.shouldCheckConversionStatus = false
  m.convertingFile = {}
  m.fileList.setFocus(true)
end sub
