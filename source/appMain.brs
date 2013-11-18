function Main()
  InitTheme()
  RunLandingScreen()
end function


function RunLandingScreen() as void
  screen = CreateObject("roListScreen")
  port = CreateObject("roMessagePort")
  screen.SetMessagePort(port)

  landing_items = CreateObject("roArray", 3, true)
  landing_items[0] = {Title: "Your Files"}
  landing_items[1] = {Title: "Settings"}
  landing_items[2] = {Title: "Search"}
  screen.SetContent(landing_items)
  screen.Show()

  while (true)
      msg = wait(0, port)
      if (type(msg) = "roListScreenEvent") then
        if (msg.isListItemSelected()) then
          if (msg.GetIndex() = 0) then
            list_root_url = "https://api.put.io/v2/files/list?oauth_token=039TXRBN"
            FileBrowser(list_root_url)
          else if (msg.GetIndex() = 2) then
            Search(false)
          end if
        end if
      end if
  end while
end function


function InitTheme() as void
    app = CreateObject("roAppManager")

    secondaryText    = "#FFED6D"
    primaryText      = "#4D4D4D"
    buttonText       = "#C0C0C0"
    buttonHighlight  = "#ffffff"
    backgroundColor  = "#4D4D4D"
    
    theme = {
        BackgroundColor: backgroundColor
        OverhangSliceHD: "pkg:/images/roku-app-overhang.png"
        OverhangSliceSD: "pkg:/images/roku-app-overhang.png"
        OverhangLogoHD: "pkg:/images/roku-app-logo.png"
        OverhangLogoSD: "pkg:/images/roku-app-logo.png"
        OverhangOffsetSD_X: "230"
        OverhangOffsetSD_Y: "72"
        OverhangOffsetHD_X: "230"
        OverhangOffsetHD_Y: "72"
        BreadcrumbTextLeft: "#FFED6D"
        BreadcrumbTextRight: "#FFED6D"
        BreadcrumbDelimiter: "#FFED6D"
        ThemeType: "generic-dark"
        ListItemText: secondaryText
        ListItemHighlightText: primaryText
        ListScreenDescriptionText: secondaryText
        ListItemHighlightHD: "pkg:/images/select_bkgnd.png"
        ListItemHighlightSD: "pkg:/images/select_bkgnd.png"
        SpringboardTitleText: "#FFED6D"
        DialogTitleText: "#FFED6D"
        DialogBodyText: "#FFED6D"
        ButtonHighlightHD: "pkg:/images/select_bkgnd.png"
        ButtonHighlightSD: "pkg:/images/select_bkgnd.png"
        ButtonNormalColor: "#FFED6D"
    }
    app.SetTheme( theme )
end function


function FileBrowser(url as string, search_history=invalid) as Integer
  screen = CreateObject("roListScreen")
  port = CreateObject("roMessagePort")
  screen.SetMessagePort(port)

  dialog = CreateObject("roOneLineDialog")
  dialog.SetTitle("Retrieving...")
  dialog.ShowBusyAnimation()
  dialog.Show()
  result = GetFileList(url)
  dialog.Close()
  if (result.DoesExist("parent")) then
    screen.SetBreadcrumbText("", result.parent.name)
  else
    if (type(screen) = "roListScreen") then
      screen.SetHeader("Search Results")
    end if
  end if

  files = result.files
  screen.SetContent(files)
  screen.Show()

  focusedItem = invalid

  while (true)
    msg = wait(0, port)
    if (msg.isScreenClosed()) Then
        print "browser screen closed"
        return -1
    end if
    if (type(msg) = "roListScreenEvent") then
      if msg.isListItemFocused()
          focusedItem = msg.GetIndex()
      end if
      if (msg.isRemoteKeyPressed()) then
        if (msg.GetIndex() = 10) then
          res = DeleteItem(files[focusedItem])
          if (res = 1) then
            if (files.delete(focusedItem)) then
              screen.SetContent(files)
            end if
          end if
        end if
      end if

      if (msg.isListItemSelected()) then
        content_type = files[msg.GetIndex()].ContentType
        r = CreateObject("roRegex", "/", "")
        parsed_ct = r.Split(content_type)
        c_root = parsed_ct[0]
        c_format = parsed_ct[1]

        'bir item uzerinde OK butonuna basilirsa yapiacak isler burada tanimlaniyor'
        if (content_type = "application/x-directory") then
          if (files[msg.GetIndex()].size = 0) then
            dlg= CreateObject("roOneLineDialog")
            dlg.SetTitle("Empty folder")
            dlg.Show()
            Sleep(1000)
            dlg.Close()
          else
            id = files[msg.GetIndex()].ID.tostr()
            url = "https://api.put.io/v2/files/list?oauth_token=039TXRBN&parent_id="+id
            FileBrowser(url)
          end if
        else if (c_root = "video") then
          id = files[msg.GetIndex()].ID.tostr()
          if (c_format = "mp4") then
            putio_api = "https://api.put.io/v2/files/"+id+"/stream?oauth_token=039TXRBN"
            location = ResolveRedirect(putio_api)
            item = { 
              ContentType: "episode"
              SDPosterUrl: files[msg.GetIndex()].SDBackgroundImageUrl
              HDPosterUrl: files[msg.GetIndex()].HDBackgroundImageUrl
              ID: id
              title: files[msg.GetIndex()].Title
              url: location
             }
            SpringboardScreen(item)
          else
            if (files[msg.GetIndex()].Mp4Available = true) then
              putio_api = "https://api.put.io/v2/files/"+id+"/mp4/stream?oauth_token=039TXRBN"
              location = ResolveRedirect(putio_api)
              item = { 
                ContentType:"episode"
                SDPosterUrl: files[msg.GetIndex()].SDBackgroundImageUrl
                HDPosterUrl: files[msg.GetIndex()].HDBackgroundImageUrl
                ID: id
                title: files[msg.GetIndex()].Title
                url: location
               }
              SpringboardScreen(item)
            else
              putio_api = "https://api.put.io/v2/files/"+id+"/stream?oauth_token=039TXRBN"
              location = ResolveRedirect(putio_api)
              item = { 
                ContentType:"episode"
                SDPosterUrl: files[msg.GetIndex()].SDBackgroundImageUrl
                HDPosterUrl: files[msg.GetIndex()].SDBackgroundImageUrl
                ID: id
                title: files[msg.GetIndex()].Title
                convert_mp4: true
                url: location
              }
              SpringboardScreen(item)
            end if
          end if
        else
          nv_dialog = CreateObject("roOneLineDialog")
          nv_dialog.SetTitle("Hello World!")
          nv_dialog.Show()
          Sleep(1000)
          nv_dialog.Close()
        end if 
      end if
    end if
  end while
end function


function GetFileList(url as string) as object
  request = CreateObject("roUrlTransfer")
  request.SetCertificatesFile("common:/certs/ca-bundle.crt")
  request.AddHeader("X-Roku-Reserved-Dev-Id", "")
  request.InitClientCertificates()

  port = CreateObject("roMessagePort")
  request.SetMessagePort(port)
  request.setUrl(url)
  result = CreateObject("roAssociativeArray")

  if (request.AsyncGetToString())
    while (true)
      msg = wait(0, port)
      if (type(msg) = "roUrlEvent")
        code = msg.GetResponseCode()
        if (code = 200)
          files = CreateObject("roArray", 10, true)
          json = ParseJSON(msg.GetString())
          if (json.DoesExist("parent")) then
            result.parent = {name: json["parent"].name, parent_id: json["parent"].parent_id}
          end if
          for each kind in json["files"]
            if (kind.content_type = "application/x-directory") then
              hd_screenshot = "pkg:/images/folder.png"
              sd_screenshot = ""
            else
              sd_screenshot = kind.screenshot
              hd_screenshot = kind.screenshot
            endif 

            topic = {
              Title: kind.name,
              ID: kind.id,
              Mp4Available: kind.is_mp4_available,
              ContentType: kind.content_type,
              SDSmallIconUrl: "pkg:/images/about_small.png",
              HDSmallIconUrl: "pkg:/images/about_small.png",
              SDBackgroundImageUrl: hd_screenshot, 
              'HDBackgroundImageUrl: "pkg:/images/bkg.png"
              HDPosterUrl: hd_screenshot,
              SDPosterUrl: hd_screenshot,
              ShortDescriptionLine1: kind.name,
              size: kind.size,
            }
            files.push(topic)
          end for
          result.files = files
          return result
        endif
      else if (event = invalid)
        request.AsyncCancel()
      endif
    end while
  endif
  return invalid
end function


function SpringboardScreen(item as object) As Boolean
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSpringboardScreen")    
    screen.SetMessagePort(port)

    screen.SetDescriptionStyle("video") 'audio, movie, video, generic
                                        ' generic+episode=4x3,
    screen.ClearButtons()

    if (item.DoesExist("convert_mp4") = true) then
      request = CreateObject("roUrlTransfer")
      request.SetCertificatesFile("common:/certs/ca-bundle.crt")
      request.AddHeader("X-Roku-Reserved-Dev-Id", "")
      request.InitClientCertificates()

      url = "https://api.put.io/v2/files/"+item["ID"]+"/mp4?oauth_token=039TXRBN"
      port = CreateObject("roMessagePort")
      request.SetMessagePort(port)
      request.SetUrl(url)
      if (request.AsyncGetToString())
        msg = wait(0, port)
        if (type(msg) = "roUrlEvent") then
          code = msg.GetResponseCode()
          if (code = 200) then
            result = ParseJSON(msg.GetString())
            if (result["mp4"]["status"] = "NOT_AVAILABLE") then
              screen.AddButton(1, "Try to play")
              screen.AddButton(3, "Convert to MP4")
            else if (result["mp4"]["status"] = "COMPLETED") then
              screen.AddButton(1, "Play")
            else if (result["mp4"]["status"] = "CONVERTING")
              screen.AddButton(1, "Try to play")
              percent_done = result["mp4"]["percent_done"]
              item.Description = "Converting to MP4...  "+percent_done.tostr()+"%"
            else if (result["mp4"]["status"] = "IN_QUEUE")
              screen.AddButton(1, "Try to play")
              item.Description = "In queue, please wait..."
            end if
          end if
        else if (event = invalid)
          request.AsyncCancel()
          screen.AddButton(1, "Try to play")
          screen.AddButton(3, "Convert to MP4")
        end if
      end if
    else
      screen.AddButton(1, "Play")
    end if
    
    screen.AllowUpdates(false)
    if item <> invalid and type(item) = "roAssociativeArray"
        screen.SetContent(item)
    endif

    screen.SetStaticRatingEnabled(false)
    screen.AllowUpdates(true)
    screen.Show()

    downKey=3
    selectKey=6
    while true
      msg = wait(0, screen.GetMessagePort())
      if type(msg) = "roSpringboardScreenEvent"
        if msg.isScreenClosed()
          print "Screen closed"
          exit while                
        else if msg.isButtonPressed()
          print "Button pressed: "; msg.GetIndex(); " " msg.GetData()
          if msg.GetIndex() = 1
              DisplayVideo(item)
          else if msg.GetIndex() = 3
              ConvertToMp4(item)
          endif
        else
          print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
        endif
      else 
        print "wrong type.... type=";msg.GetType(); " msg: "; msg.GetMessage()
      endif
    end while
    return true
end function


function DisplayVideo(args As object)
    print "Displaying video: "
    p = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(p)

    'bitrates  = [0]          ' 0 = no dots, adaptive bitrate
    'bitrates  = [348]    ' <500 Kbps = 1 dot
    'bitrates  = [664]    ' <800 Kbps = 2 dots
    'bitrates  = [996]    ' <1.1Mbps  = 3 dots
    'bitrates  = [2048]    ' >=1.1Mbps = 4 dots
    bitrates  = [0]    

    qualities = ["HD"]
    StreamFormat = "mp4"
    title = args["title"]

    urls = [args["url"]]
    if type(args["url"]) = "roString" and args["url"] <> "" then
        urls[0] = args["url"]
    end if
    if type(args["StreamFormat"]) = "roString" and args["StreamFormat"] <> "" then
        StreamFormat = args["StreamFormat"]
    end if
    
    videoclip = CreateObject("roAssociativeArray")
    videoclip.StreamBitrates = bitrates
    videoclip.StreamUrls = urls
    videoclip.StreamQualities = qualities
    videoclip.StreamFormat = StreamFormat
    videoclip.Title = title
    videoclip.SubtitleUrl = "https://api.put.io/v2/subtitles/get/"+args["ID"]+"?oauth_token=039TXRBN"
    video.SetContent(videoclip)
    video.show()

    lastSavedPos   = 0
    statusInterval = 10 'position must change by more than this number of seconds before saving

    while true
        msg = wait(0, video.GetMessagePort())
        if type(msg) = "roVideoScreenEvent"
            if msg.isScreenClosed() then 'ScreenClosed event
                print "Closing video screen"
                exit while
            else if msg.isPlaybackPosition() then
                nowpos = msg.GetIndex()
                if nowpos > 10000
                    
                end if
                if nowpos > 0
                    if abs(nowpos - lastSavedPos) > statusInterval
                        lastSavedPos = nowpos
                    end if
                end if
            else if msg.isRequestFailed()
                print "play failed: "; msg.GetMessage()
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
            endif
        end if
    end while
end function


function ResolveRedirect(str As String) As String
    http = CreateObject("roUrlTransfer")
    http.SetCertificatesFile("common:/certs/ca-bundle.crt")
    http.AddHeader("X-Roku-Reserved-Dev-Id", "")
    http.InitClientCertificates()
    http.SetUrl( str )
    event = http.Head()
    headers = event.GetResponseHeaders()
    redirect = headers.location
    if ( redirect <> invalid AND redirect <> str )
      print "Old url: " str
      print "Redirect url: " redirect
      str = redirect                
    endif
    r = CreateObject("roRegex", "https://", "")
    str = r.ReplaceAll(str, "http://")
    return str
end function


function ConvertToMp4(item as Object) as void
  request = CreateObject("roUrlTransfer")
  request.SetCertificatesFile("common:/certs/ca-bundle.crt")
  request.AddHeader("X-Roku-Reserved-Dev-Id", "")
  request.InitClientCertificates()
  
  dialog1 = CreateObject("roOneLineDialog")
  dialog1.SetTitle("Sending to MP4 queue")
  dialog1.Show()

  url = "https://api.put.io/v2/files/"+item["ID"]+"/mp4?oauth_token=039TXRBN"
  port = CreateObject("roMessagePort")
  request.SetMessagePort(port)
  request.SetUrl(url)
  if (request.AsyncPostFromString(""))
    msg = wait(0, port)
    dialog1.Close()
    if (type(msg) = "roUrlEvent")
      code = msg.GetResponseCode()
      if (code = 200)
        print msg.GetString()
      endif
    else if (event = invalid)
      request.AsyncCancel()
    endif
  endif
end function


function Search(history) as Integer
    displayHistory = true
    if (type(history) <> "roArray") then
      history = CreateObject("roArray", 1, true)
    end if
    screen = CreateObject("roSearchScreen")
    port = CreateObject("roMessagePort")
    screen.SetBreadcrumbText("", "Search in your files")
    screen.SetMessagePort(port) 
    if displayHistory
        screen.SetSearchTermHeaderText("Recent Searches:")
        screen.SetSearchButtonText("Search")
        screen.SetClearButtonText("Clear history")
        screen.SetClearButtonEnabled(true) 'defaults to true
        screen.SetSearchTerms(history)
    endif 
    screen.Show() 
    while true
        msg = wait(0, screen.GetMessagePort())
        if type(msg) = "roSearchScreenEvent"
          if (msg.isScreenClosed()) then
              print "search screen closed"
              return -1
          else if msg.isCleared()
              print "search terms cleared"
              history.Clear()
          else if msg.isFullResult()
              print "full search: "; msg.GetMessage()
              history.Push(msg.GetMessage())
              if displayHistory
                  screen.AddSearchTerm(msg.GetMessage())
              end if
              url ="https://api.put.io/v2/files/search/"+msg.GetMessage()+"?oauth_token=039TXRBN"
              FileBrowser(url, history)
              exit while
          endif
        endif
    end while 
end function
 

function DeleteItem(item as object) as Integer
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSpringboardScreen")    
    screen.SetMessagePort(port)

    screen.SetDescriptionStyle("generic") 'audio, movie, video, generic
                                        ' generic+episode=4x3,
    screen.ClearButtons()
    screen.AddButton(1, "Delete")

    screen.AllowUpdates(false)
    if item <> invalid and type(item) = "roAssociativeArray"
        screen.SetContent(item)
    endif

    screen.SetStaticRatingEnabled(false)
    screen.AllowUpdates(true)
    screen.Show()

    while true
      msg = wait(0, screen.GetMessagePort())
      if type(msg) = "roSpringboardScreenEvent"
        if msg.isScreenClosed()
          print "Screen closed"
          return -1            
        else if msg.isButtonPressed()
          print "siliyorum"
          return -1
        endif
      end if
    end while
end function
