sub init()
  m.top.functionname = "request"
  m.top.response = ""
end sub

function request()
  ' boilerplate code
  http = createObject("roUrlTransfer")
  port = createObject("roMessagePort")
  http.RetainBodyOnError(true)
  http.setPort(port)
  http.setCertificatesFile("common:/certs/ca-bundle.crt")
  http.InitClientCertificates()
  http.enablehostverification(false)
  http.enablepeerverification(false)

  ' set url
  url = "https://api.put.io/v2" + m.top.url
  http.setUrl(url)

  ' request
  if http.AsyncGetToString() Then
    msg = wait(10000, port) ' I guess this is something like timeout
    if (type(msg) = "roUrlEvent")
      if (msg.getresponsecode() > 0 and msg.getresponsecode() < 400)
        m.top.response = msg.getstring()
      else
        ? "feed load failed: "; msg.getfailurereason();" "; msg.getresponsecode();" "; url
        m.top.response = ""
      end if
      http.asynccancel()
    else if (msg = invalid)
      ? "feed load failed."
      m.top.response = ""
      http.asynccancel()
    end if
  end if
end function
