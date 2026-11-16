sub init()
    m.top.functionName = "installUpdate"
end sub

sub installUpdate()
    packagePath = "tmp:/putio-update.zip"
    bodyPath = "tmp:/putio-update-body.bin"
    status = "failed"

    if downloadUpdatePackage(getUpdatePackageUrl(m.top.version), packagePath)
        boundary = "putio-" + CreateObject("roDeviceInfo").GetRandomUUID()
        if writeInstallerBody(boundary, packagePath, bodyPath)
            status = postToDevInstaller(boundary, bodyPath, m.top.password)
        end if
    end if

    DeleteFile(packagePath)
    DeleteFile(bodyPath)
    m.top.status = status
end sub

function downloadUpdatePackage(url as string, path as string) as boolean
    downloadTimeoutMs = 120000
    port = CreateObject("roMessagePort")
    http = CreateObject("roUrlTransfer")
    http.setPort(port)
    http.setCertificatesFile("common:/certs/ca-bundle.crt")
    http.initClientCertificates()
    http.setUrl(url)

    if http.asyncGetToFile(path) = false
        return false
    end if

    msg = wait(downloadTimeoutMs, port)
    if type(msg) <> "roUrlEvent"
        http.asyncCancel()
        return false
    end if

    return msg.getResponseCode() = 200
end function

function writeInstallerBody(boundary as string, packagePath as string, bodyPath as string) as boolean
    package = CreateObject("roByteArray")
    if package.readFile(packagePath) = false or isZipArchive(package) = false
        return false
    end if

    head = CreateObject("roByteArray")
    head.fromAsciiString(buildInstallerBodyHead(boundary))
    tail = CreateObject("roByteArray")
    tail.fromAsciiString(buildInstallerBodyTail(boundary))
    return head.writeFile(bodyPath) and package.appendFile(bodyPath) and tail.appendFile(bodyPath)
end function

' The Roku dev installer closes its socket after a 401. roUrlTransfer's own digest auth streams
' the body unauthenticated first, and a reused connection hits the closed socket, so the POST
' fails with "Send failure: Broken pipe". Sign the first request and open a fresh connection.
function postToDevInstaller(boundary as string, bodyPath as string, password as string) as string
    installTimeoutMs = 120000
    challenge = fetchDevInstallerChallenge()
    if challenge = invalid
        return "failed"
    end if

    username = "rokudev"
    uri = "/plugin_install"
    nc = "00000001"
    cnonce = lcase(CreateObject("roDeviceInfo").GetRandomUUID().replace("-", "").left(16))
    response = computeDigestResponse(md5Hex, username, password, "POST", uri, challenge, cnonce, nc)

    port = CreateObject("roMessagePort")
    http = CreateObject("roUrlTransfer")
    http.setPort(port)
    http.setUrl(getDevInstallerUrl())
    http.retainBodyOnError(true)
    http.addHeader("Content-Type", "multipart/form-data; boundary=" + boundary)
    http.addHeader("Authorization", buildDigestAuthorization(username, uri, challenge, response, cnonce, nc))
    http.enableFreshConnection(true)

    if http.asyncPostFromFile(bodyPath) = false
        return "failed"
    end if

    msg = wait(installTimeoutMs, port)
    if type(msg) <> "roUrlEvent"
        http.asyncCancel()
        return "failed"
    end if

    return readInstallerStatus(msg.getResponseCode(), msg.getString())
end function

function fetchDevInstallerChallenge() as dynamic
    challengeTimeoutMs = 10000
    port = CreateObject("roMessagePort")
    http = CreateObject("roUrlTransfer")
    http.setPort(port)
    http.setUrl(getDevInstallerUrl())
    http.retainBodyOnError(true)

    if http.asyncGetToString() = false
        return invalid
    end if

    msg = wait(challengeTimeoutMs, port)
    if type(msg) <> "roUrlEvent"
        http.asyncCancel()
        return invalid
    end if

    if msg.getResponseCode() <> 401
        return invalid
    end if

    return parseDigestChallenge(msg.getResponseHeaders()["www-authenticate"])
end function

function md5Hex(text as string) as string
    digest = CreateObject("roEVPDigest")
    digest.setup("md5")
    bytes = CreateObject("roByteArray")
    bytes.fromAsciiString(text)
    return digest.process(bytes)
end function
