sub init()
    m.top.functionName = "send"
end sub

' Sentry has no BrightScript SDK, so this posts one event envelope over plain HTTPS.
' The DSN only carries the public key; nothing here is a secret. Failures are dropped
' silently: an unreachable ingest must never affect the screen that reported the error.
sub send()
    requestTimeoutMs = 10000
    dsn = parseSentryDsn(m.top.dsn)
    event = m.top.event

    if dsn = invalid or event = invalid or event.event_id = invalid
        m.top.done = true
        return
    end if

    sentAt = CreateObject("roDateTime").ToISOString()
    envelope = formatJSON({ event_id: event.event_id, sent_at: sentAt, dsn: m.top.dsn }) + chr(10)
    envelope = envelope + formatJSON({ type: "event" }) + chr(10)
    envelope = envelope + formatJSON(event) + chr(10)

    port = createObject("roMessagePort")
    http = createObject("roUrlTransfer")
    http.setPort(port)
    http.retainBodyOnError(true)
    ' Mirrors HttpTask: older Roku OS CA bundles reject some modern chains, and the
    ' payload carries no credential worth protecting from an active attacker.
    http.setCertificatesFile("common:/certs/ca-bundle.crt")
    http.enableHostVerification(false)
    http.enablePeerVerification(false)
    http.initClientCertificates()
    http.setUrl(dsn.envelopeUrl)
    http.addHeader("Content-Type", "application/x-sentry-envelope")
    http.addHeader("X-Sentry-Auth", "Sentry sentry_version=7, sentry_client=" + sentryClientName(event) + ", sentry_key=" + dsn.publicKey)
    http.setRequest("POST")

    if http.asyncPostFromString(envelope)
        msg = wait(requestTimeoutMs, port)
        if type(msg) = "roUrlEvent"
            m.top.responseCode = msg.getResponseCode()
        else
            http.asyncCancel()
        end if
    end if

    m.top.done = true
end sub

function sentryClientName(event as object) as string
    if event.sdk <> invalid and event.sdk.name <> invalid and event.sdk.version <> invalid
        return event.sdk.name.toStr() + "/" + event.sdk.version.toStr()
    end if

    return "putio-roku/unknown"
end function

' DSN shape: https://<publicKey>@<host>/<projectId>. Returns invalid for anything else.
function parseSentryDsn(dsn as string) as object
    if dsn = invalid or dsn = ""
        return invalid
    end if

    schemeEnd = Instr(1, dsn, "://")
    if schemeEnd <= 0
        return invalid
    end if

    scheme = Left(dsn, schemeEnd - 1)
    remainder = Mid(dsn, schemeEnd + 3)
    atIndex = Instr(1, remainder, "@")
    if atIndex <= 1
        return invalid
    end if

    publicKey = Left(remainder, atIndex - 1)
    colonIndex = Instr(1, publicKey, ":")
    if colonIndex > 0
        publicKey = Left(publicKey, colonIndex - 1)
    end if

    hostAndPath = Mid(remainder, atIndex + 1)
    slashIndex = Instr(1, hostAndPath, "/")
    if slashIndex <= 1
        return invalid
    end if

    host = Left(hostAndPath, slashIndex - 1)
    path = Mid(hostAndPath, slashIndex)
    lastSlash = 0
    for i = Len(path) to 1 step -1
        if Mid(path, i, 1) = "/"
            lastSlash = i
            exit for
        end if
    end for

    projectId = Mid(path, lastSlash + 1)
    basePath = Left(path, lastSlash - 1)
    if projectId = "" or publicKey = ""
        return invalid
    end if

    return {
        publicKey: publicKey,
        projectId: projectId,
        envelopeUrl: scheme + "://" + host + basePath + "/api/" + projectId + "/envelope/",
    }
end function
