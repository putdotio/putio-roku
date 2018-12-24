sub Main()
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    ' Globals
    m.global = screen.getGlobalNode()
    m.global.addFields({
      user: {}
    })

    scene = screen.CreateScene("App")
    screen.show()

    while(true)
      msg = wait(0, m.port)
      msgType = type(msg)
      if msgType = "roSGScreenEvent"
        if msg.isScreenClosed() then return
      end if
    end while
end sub
