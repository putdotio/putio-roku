' Driver for update-check.test.ts, run by the @rokucommunity/brs interpreter.
function main() as string
    return formatJson({
        newer: [
            isNewerAppVersion("2.19.0", "2.18.00004"),
            isNewerAppVersion("2.18.10", "2.18.9"),
            isNewerAppVersion("3.0.0", "2.99.99"),
            isNewerAppVersion("2.18.4", "2.18.00004"),
            isNewerAppVersion("2.18.3", "2.18.4"),
            isNewerAppVersion("2.19", "2.18.4"),
            isNewerAppVersion("<html>", "2.18.4"),
            isNewerAppVersion(invalid, "2.18.4")
        ],
        manifest: [
            readUpdateManifestVersion("{""version"":""2.19.0""}"),
            readUpdateManifestVersion("{""version"":2}"),
            readUpdateManifestVersion("<!doctype html>"),
            readUpdateManifestVersion("")
        ],
        offer: [
            shouldOfferAppUpdate("2.19.0", "2.18.00004", ""),
            shouldOfferAppUpdate("2.19.0", "2.18.00004", "2.19.0"),
            shouldOfferAppUpdate("2.20.0", "2.18.00004", "2.19.0"),
            shouldOfferAppUpdate("", "2.18.00004", "")
        ],
        description: [
            buildVersionDescription("2.18.00004", "2.19.0"),
            buildVersionDescription("2.18.00004", "")
        ],
        packageUrl: getUpdatePackageUrl("2.21.0"),
        challenge: [
            parseDigestChallenge("Digest qop=""auth"", realm=""rokudev"", nonce=""1794847765"""),
            parseDigestChallenge("Basic realm=""x"""),
            parseDigestChallenge(invalid)
        ],
        digestResponse: [
            computeDigestResponse(fakeMd5, "rokudev", "pw", "POST", "/plugin_install", {realm: "rokudev", nonce: "n1", qop: "auth"}, "c1", "00000001"),
            computeDigestResponse(fakeMd5, "rokudev", "pw", "POST", "/plugin_install", {realm: "rokudev", nonce: "n1"}, "c1", "00000001")
        ],
        authorization: buildDigestAuthorization("rokudev", "/plugin_install", {realm: "rokudev", nonce: "n1", qop: "auth"}, "r1", "c1", "00000001").replace(chr(34), "'"),
        zip: [
            isZipArchive(bytesFromHex("504B0304140000")),
            isZipArchive(bytesFromAscii("<!doctype html>")),
            isZipArchive(bytesFromHex("504B"))
        ],
        installer: [
            readInstallerStatus(200, "<font color=""red"">Application Received: 862810 bytes stored.</font><font color=""red"">Install Success.</font>"),
            readInstallerStatus(401, ""),
            readInstallerStatus(200, "<font color=""red"">Install Failure: Compilation Failed.</font>"),
            readInstallerStatus(-28, invalid)
        ],
        body: (buildInstallerBodyHead("b") + "ZIP" + buildInstallerBodyTail("b")).replace(chr(34), "'").split(chr(13) + chr(10))
    })
end function

function bytesFromHex(hex as string) as object
    bytes = CreateObject("roByteArray")
    bytes.fromHexString(hex)
    return bytes
end function

function bytesFromAscii(text as string) as object
    bytes = CreateObject("roByteArray")
    bytes.fromAsciiString(text)
    return bytes
end function

function fakeMd5(text as string) as string
    return "h(" + text + ")"
end function
