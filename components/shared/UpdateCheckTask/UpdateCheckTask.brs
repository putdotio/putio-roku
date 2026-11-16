sub init()
    m.top.functionName = "checkForUpdate"
end sub

sub checkForUpdate()
    requestTimeoutMs = 10000
    port = CreateObject("roMessagePort")
    http = CreateObject("roUrlTransfer")
    http.setPort(port)
    http.setCertificatesFile("common:/certs/ca-bundle.crt")
    http.initClientCertificates()
    http.setUrl(getUpdateManifestUrl())

    latestVersion = ""
    if http.asyncGetToString()
        msg = wait(requestTimeoutMs, port)
        if type(msg) = "roUrlEvent" and msg.getResponseCode() = 200
            latestVersion = readUpdateManifestVersion(msg.getString())
        else
            http.asyncCancel()
        end if
    end if

    m.top.latestVersion = latestVersion
end sub
