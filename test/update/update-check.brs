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
        ]
    })
end function
