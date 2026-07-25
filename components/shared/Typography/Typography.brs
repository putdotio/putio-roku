' Roku type scale for the put.io brand face (GT America). See docs/FONTS.md.
'
' Sizes are authored in FHD (1920x1080) coordinates and are deliberately identical to the
' Roku built-in each role replaces. The Lab "Typography / GT America" story renders each
' built-in beside GT America at the same size and one and two 3px grid steps up; measuring
' ink extents off that screenshot put GT America within a few percent of the built-in it
' stands in for (94-95% on cap-height strings, 105-107% on digits) while one step up came out
' 6-9% oversized. The story shows the comparison, it does not compute those numbers -- redo
' the pixel measurement if you change the scale. Keeping the sizes fixed is what leaves every
' existing Label height, wrap budget and row baseline valid.
'
' Weights follow the design system's role mapping, matching the iOS app: bold for the
' largest headings, medium for titles and interactive labels, regular for body and support.
'
' Each role names the built-in it replaces. Builds packaged without the licensed faces assign
' that built-in instead, so every migrated label renders as it did before the brand face
' landed. ScreenHeader is the exception: it draws the screen title itself in all builds, so
' the header does not return to Overhang's own title rendering when the faces are absent.
' Consumers must include pkg:/source/BuildConfig.brs alongside this script.

function typographyRoles() as object
    return {
        h1: { face: "bold", size: 45, system: "font:LargeBoldSystemFont" },
        h2: { face: "medium", size: 36, system: "font:MediumBoldSystemFont" },
        body: { face: "regular", size: 36, system: "font:MediumSystemFont" },
        small: { face: "regular", size: 33, system: "font:SmallSystemFont" },
        label: { face: "medium", size: 33, system: "font:SmallBoldSystemFont" },
        caption: { face: "regular", size: 27, system: "font:SmallestSystemFont" }
    }
end function

' Applies a type scale role to any node that renders text through a font field.
sub applyTypography(node, role as string)
    if node <> invalid and node.hasField("font")
        node.font = brandFont(role)
    end if
end sub

' Returns the font for a role: a Font node when the brand faces are bundled, otherwise the
' Roku built-in URI the role replaces. Cached per component instance, so a list row builds
' each face once rather than once per render.
function brandFont(role as string) as object
    if m.brandFonts = invalid
        m.brandFonts = {}
        m.typographyRoles = typographyRoles()
    end if

    cached = m.brandFonts[role]
    if cached <> invalid
        return cached
    end if

    spec = m.typographyRoles[role]
    if spec = invalid
        spec = m.typographyRoles.body
    end if

    resolved = spec.system
    if buildConfigBrandFontsAvailable()
        font = createObject("roSGNode", "Font")
        font.uri = brandFontUri(spec.face)
        font.size = spec.size
        resolved = font
    end if

    m.brandFonts[role] = resolved
    return resolved
end function

function brandFontUri(face as string) as string
    return "pkg:/fonts/gt-america-standard-" + face + ".otf"
end function
