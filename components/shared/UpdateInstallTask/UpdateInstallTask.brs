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
    if package.readFile(packagePath) = false or package.count() = 0
        return false
    end if

    body = CreateObject("roByteArray")
    body.fromAsciiString(buildInstallerBodyHead(boundary))
    body.append(package)
    tail = CreateObject("roByteArray")
    tail.fromAsciiString(buildInstallerBodyTail(boundary))
    body.append(tail)
    return body.writeFile(bodyPath)
end function

' A successful install replaces this app and relaunches it, so the request may never return.
function postToDevInstaller(boundary as string, bodyPath as string, password as string) as string
    installTimeoutMs = 120000
    port = CreateObject("roMessagePort")
    http = CreateObject("roUrlTransfer")
    http.setPort(port)
    http.setUrl(getDevInstallerUrl())
    http.retainBodyOnError(true)
    http.addHeader("Content-Type", "multipart/form-data; boundary=" + boundary)
    http.setUserAndPassword("rokudev", password)

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
