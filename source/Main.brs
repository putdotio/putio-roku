sub Main(args as object)
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    if shouldLaunchLab(args)
        launchLab(screen, args)
        return
    end if

    m.global = screen.getGlobalNode()
    m.global.addFields({
        appId: "3776",
        user: {},
        config: {
            playbackType: "hls"
        },
        route: {
            id: "splashScreen",
            params: {},
        },
        apiURL: "https://api.put.io/v2",
    })

    scene = screen.CreateScene("App")
    scene.backgroundColor = "0x161616FF"
    scene.backgroundUri = ""
    if args <> invalid
        scene.deepLink = args
    end if

    input = CreateObject("roInput")
    input.setMessagePort(m.port)

    screen.show()

    scene.signalBeacon("AppLaunchComplete")
    scene.observeField("exitApp", m.port)

    while(true)
        msg = wait(0, m.port)
        msgType = type(msg)

        if msgType = "roSGScreenEvent" then
            if msg.isScreenClosed() then
                return
            end if
        else if msgType = "roInputEvent" then
            if msg.isInput()
                scene.deepLink = msg.getInfo()
            end if
        else if msgType = "roSGNodeEvent" then
            field = msg.getField()
            if field = "exitApp" then
                return
            end if
        end if
    end while
end sub

function shouldLaunchLab(args as object) as boolean
    if isLabLaunchEnabled() = false
        return false
    end if

    if args = invalid
        return false
    end if

    lab = readLaunchArg(args, "lab")
    story = readLaunchArg(args, "story")

    return isTruthyLaunchArg(lab) or story <> invalid
end function

function isLabLaunchEnabled() as boolean
    return false
end function

function readLaunchArg(args as object, key as string)
    if args <> invalid and args.doesExist(key)
        return args[key]
    end if

    return invalid
end function

function isTruthyLaunchArg(value) as boolean
    if value = invalid
        return false
    end if

    normalizedValue = LCase(value.toStr())
    return normalizedValue = "1" or normalizedValue = "true" or normalizedValue = "yes"
end function

sub launchLab(screen, args as object)
    scene = screen.CreateScene("Lab")
    scene.backgroundColor = "0x161616FF"
    scene.backgroundUri = ""

    story = readLaunchArg(args, "story")
    if story <> invalid
        scene.story = story.toStr()
    end if

    screen.show()
    scene.signalBeacon("AppLaunchComplete")

    while(true)
        msg = wait(0, m.port)
        msgType = type(msg)

        if msgType = "roSGScreenEvent" and msg.isScreenClosed()
            return
        end if
    end while
end sub
