sub init()
  m.top.functionname = "request"
  m.top.response = ""
end sub

function request()
  port = createObject("roMessagePort")
  m.http = createObject("roUrlTransfer")
  m.http.RetainBodyOnError(true)
  m.http.setPort(port)
  m.http.setCertificatesFile("common:/certs/ca-bundle.crt")
  m.http.enablehostverification(false)
  m.http.enablepeerverification(false)

  ' Inject Token
  storage = CreateObject("roRegistrySection", "user")
  if storage.Exists("token")
    m.http.AddHeader("Authorization", "token " + storage.Read("token"))
  end if

  m.http.InitClientCertificates()

  ' Set URL
  m.http.SetUrl("https://api.put.io/v2" + m.top.url)

  ' Set Request Method
  m.http.SetRequest(m.top.method)

  ' Make Request
  if m.top.method = "POST"
    body = ""

    if m.top.body <> invalid
      m.http.AddHeader("Content-Type", "application/json")
      body = formatJSON(m.top.body)
    end if

    if m.http.AsyncPostFromString(body) Then
      msg = wait(10000, port) ' I guess this is something like timeout
      onResponse(msg)
    end if
  else
    if m.http.AsyncGetToString() Then
      msg = wait(10000, port) ' I guess this is something like timeout
      onResponse(msg)
    end if
  end if

end function

sub onResponse(msg)
  if (type(msg) = "roUrlEvent")
    if (msg.getresponsecode() > 0 and msg.getresponsecode() < 400)
      m.top.response = msg.getstring()
    else
      ' ? "Http Task Failed: "; msg.getfailurereason();" "; msg.getresponsecode();" "; url
      m.top.response = msg.getstring()
    end if
    m.http.asynccancel()
  else if (msg = invalid)
    ' ? "Http Task Failed"
    m.top.response = ""
    m.http.asynccancel()
  end if
end sub
