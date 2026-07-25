' Screen header: Roku's Overhang for the logo, options affordance and background, with a
' brand-face title of our own. Overhang exposes titleColor but no font field, so its title
' is left empty and drawn here instead.

sub init()
    m.overhang = m.top.findNode("overhang")
    m.logoDivider = m.top.findNode("logoDivider")
    m.titleLabel = m.top.findNode("titleLabel")

    ' Measured off Overhang's own layout so the brand title and divider land where the
    ' built-in ones did: divider 507px in, title clear of it, both optically centred on the
    ' logo. Every value is on the 3px autoscale grid so it stays whole-pixel at 720p.
    titleX = uiSnap(540)

    applyAppOverhangColors(m.overhang)

    ' Screens set showOptions as an XML attribute, and an initial value does not reach
    ' onScreenHeaderOptionsChange with m.overhang resolved, so forward it once here or the
    ' options affordance never appears. The handler still covers later writes.
    m.overhang.showOptions = m.top.showOptions

    m.logoDivider.translation = [uiSnap(507), uiSnap(81)]
    m.logoDivider.width = uiBorderWidth()
    m.logoDivider.height = uiSnap(42)
    setDialogNodeColor(m.logoDivider, "border")

    m.titleLabel.translation = [titleX, uiSnap(69)]
    m.titleLabel.height = uiSnap(66)
    m.titleLabel.vertAlign = "center"
    setDialogNodeColor(m.titleLabel, "text")
    applyTypography(m.titleLabel, "h1")

    renderScreenHeaderTitle()
end sub

sub onScreenHeaderTitleChange()
    renderScreenHeaderTitle()
end sub

sub onScreenHeaderOptionsChange()
    if m.overhang <> invalid
        m.overhang.showOptions = m.top.showOptions
    end if

    renderScreenHeaderTitle()
end sub

sub renderScreenHeaderTitle()
    if m.titleLabel = invalid
        return
    end if

    title = m.top.title
    if title = invalid
        title = ""
    end if

    m.titleLabel.text = title

    ' Overhang only drew the divider when it had a title to separate from the logo. Match
    ' that: screens without one (Home) show the logo alone rather than a divider pointing
    ' at nothing. Files and Audio set their title after init, so this tracks every change.
    m.logoDivider.visible = title <> ""

    ' Built-in Overhang laid title and options out together; this title is a plain Label,
    ' so it has to reserve the options region itself or a long one (Files sets the title to
    ' the folder name) runs under the "Delete *" affordance on the right.
    titleX = m.titleLabel.translation[0]
    available = uiScreenWidth() - titleX - uiPageMargin()
    if m.top.showOptions
        available = available - uiSnap(300)
    end if

    m.titleLabel.width = available
end sub
