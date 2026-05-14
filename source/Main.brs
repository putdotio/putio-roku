sub Main(args as object)
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    m.global = screen.getGlobalNode()
    m.global.addFields({
        appId: "3776",
        user: {},
        route: {
            id: "splashScreen",
            params: {},
        },
        apiURL: "https://api.put.io/v2",
    })

    scene = screen.CreateScene("App")
    scene.backgroundColor = "0x333333FF"
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
