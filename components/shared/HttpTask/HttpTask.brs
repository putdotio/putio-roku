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
  storage = CreateObject("roRegistrySection", "userConfig")
  if storage.Exists("token")
    m.http.AddHeader("Authorization", "token " + storage.Read("token"))
  end if

  m.http.InitClientCertificates()

  ' Set URL
  m.http.SetUrl(m.global.apiURL + m.top.url)

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
  ' ? "HttpTask Message: "; msg.getstring()
  ' ? "HttpTask ResponseCode: "; msg.getresponsecode()

  if (type(msg) = "roUrlEvent")
    if (msg.getresponsecode() > 0 and msg.getresponsecode() < 400)
      m.top.response = msg.getstring()
    else
      ? "HttpTask Failed (Response Code): "; msg.getstring()
      m.top.response = msg.getstring()
    end if
  else if (msg = invalid)
    ? "HttpTask Failed (Response Code): "; msg
    m.top.response = "{ error_type: 'NETWORK_ERROR', error_message: 'Network Error' }"
  end if

  m.http.asynccancel()
  m.top.response = ""
end sub
