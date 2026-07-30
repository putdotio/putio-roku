sub init()
    m.top.functionname = "request"
    m.top.response = ""
end sub

function request()
    requestTimeoutMs = 10000
    port = createObject("roMessagePort")
    m.http = createObject("roUrlTransfer")
    m.http.RetainBodyOnError(true)
    m.http.setPort(port)
    m.http.setCertificatesFile("common:/certs/ca-bundle.crt")
    m.http.enablehostverification(false)
    m.http.enablepeerverification(false)

    storage = CreateObject("roRegistrySection", "userConfig")
    if storage.Exists("token") and shouldAddAuthorizationHeader(m.top.url)
        m.http.AddHeader("Authorization", "token " + storage.Read("token"))
    end if

    m.http.InitClientCertificates()

    m.http.SetUrl(m.global.apiURL + m.top.url)

    m.http.SetRequest(m.top.method)

    if m.top.method = "POST" or m.top.method = "PUT"
        body = ""

        if m.top.body <> invalid
            m.http.AddHeader("Content-Type", "application/json")
            body = formatJSON(m.top.body)
        end if

        if m.http.AsyncPostFromString(body) then
            msg = wait(requestTimeoutMs, port)
            onResponse(msg)
        end if
    else
        if m.http.AsyncGetToString() then
            msg = wait(requestTimeoutMs, port)
            onResponse(msg)
        end if
    end if

end function

function shouldAddAuthorizationHeader(url as string) as boolean
    return Left(url, 16) <> "/oauth2/oob/code"
end function

sub onResponse(msg)
    if (type(msg) = "roUrlEvent")
        if (msg.getresponsecode() > 0 and msg.getresponsecode() < 400)
            m.top.response = msg.getstring()
        else
            ? "HttpTask Failed (Response Code): "; msg.getstring()
            m.top.response = msg.getstring()
        end if
    else if (msg = invalid)
        ? "HttpTask Failed (Response Code): "; msg
        m.top.response = "{""error_type"":""NETWORK_ERROR"",""error_message"":""Network Error""}"
    end if

    m.http.asynccancel()
    m.top.response = ""
end sub
