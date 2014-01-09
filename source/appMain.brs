function Main()
  InitTheme()
  facade = CreateObject("roParagraphScreen")
  facade.Show()
  token = RegRead("token")
  if (token = invalid) then
    res = ShowLinkScreen(facade)
    if (res = -1) then
      return -1
    end if
  else
    m.token = token
  end if
  m.subtitle_on = RegRead("subtitle_on")
  RunLandingScreen(facade)
end function


function GetLinkingCode() as Dynamic
  request = MakeRequest()
  device_id = GetDeviceESN()
  url = "https://put.io/roku/key/"+device_id
  port = CreateObject("roMessagePort")
  request.SetMessagePort(port)
  request.SetUrl(url)
  if (request.AsyncGetToString())
    msg = wait(0, port)
    if (type(msg) = "roUrlEvent")
      code = msg.GetResponseCode()
      if (code = 200)
        json = ParseJSON(msg.GetString())
        if (json.DoesExist("key")) then
          return json["key"]
        end if
      endif
    else if (event = invalid)
      request.AsyncCancel()
    endif
  endif
  return invalid
end function


function ValidateLinkingCode() as Integer
  request = MakeRequest()

  url = "https://put.io/roku/check"
  port = CreateObject("roMessagePort")
  request.SetMessagePort(port)
  request.SetUrl(url)
  device_id = GetDeviceESN()
  if (request.AsyncPostFromString("device_id="+device_id))
    msg = wait(0, port)
    if (type(msg) = "roUrlEvent")
      code = msg.GetResponseCode()
      if (code = 200)
        json = ParseJSON(msg.GetString())
        if (json.DoesExist("oauth_token")) then
          token = json["oauth_token"]
          RegWrite("token", token)
          RegWrite("subtitle_on", "on")
          m.token = token
          return 1
        end if
      end if
    end if
  end if
end function


sub ShowLinkScreen(facade) as Integer
  dt = CreateObject("roDateTime")

  ' create a roCodeRegistrationScreen and assign it a roMessagePort
  port = CreateObject("roMessagePort")
  screen = CreateObject("roCodeRegistrationScreen")
  screen.SetMessagePort(port)

  ' add some header text
  screen.AddHeaderText("  Link this Roku to your put.io account")
  ' add some buttons
  screen.AddButton(1, "Get new code")
  screen.AddButton(2, "Back")
  ' Focal text should give specific instructions to the user
  screen.AddFocalText("Go to put.io/roku, log into your account, and enter the following:", "spacing-normal")

  ' display a retrieving message until we get a linking code
  screen.SetRegistrationCode("Retrieving...")
  screen.Show()

  ' get a new code
  linkingCode = GetLinkingCode()
  if linkingCode <> invalid
    screen.SetRegistrationCode(linkingCode)
  else
    screen.SetRegistrationCode("Failed to get code...")
  end if
 
  screen.Show()
  current = dt.AsSeconds()+300

  while true
    ' we want to poll the API every 5 seconds for validation,
    msg = Wait(5000, screen.GetMessagePort())

    if msg = invalid
      ' poll the API for validation
      if (ValidateLinkingCode() = 1)
        ' if validation succeeded, close the screen
        exit while
      end if

      dt.Mark()
      if dt.AsSeconds() > current
        ' the code expired. display a message, then get a new one
        d = CreateObject("roMessageDialog")
        dPort = CreateObject("roMessagePort")
        d.SetMessagePort(dPort)
        d.SetTitle("Code Expired")
        d.SetText("This code has expired. Press OK to get a new one")
        d.AddButton(1, "OK")
        d.Show()

        Wait(0, dPort)
        d.Close()
        current = dt.AsSeconds()+300
        screen.SetRegistrationCode("Retrieving...")
        screen.Show()
        linkingCode = GetLinkingCode()
        if linkingCode <> invalid
          screen.SetRegistrationCode(linkingCode)
        else
          screen.SetRegistrationCode("Failed to get code...")
        end if
        screen.Show()
      end if
    else if type(msg) = "roCodeRegistrationScreenEvent"
      if msg.isScreenClosed()
          screen.Close()
          facade.Close()
          return -1
      else if msg.isButtonPressed()
        if msg.GetIndex() = 1
          ' the user wants a new code
          code = GetLinkingCode()
          linkingCode = GetLinkingCode()
          current = dt.AsSeconds()+300
          if linkingCode <> invalid
            screen.SetRegistrationCode(linkingCode)
          else
            screen.SetRegistrationCode("Failed to get code...")
          end if
          screen.Show()
        else if msg.GetIndex() = 2
          ' the user wants to close the screen
          screen.Close()
          facade.Close()
          return -1
        end if
      end if
    end if
  end while
  screen.Close()
end sub


function RunLandingScreen(facade) as Integer
  screen = CreateObject("roListScreen")
  port = CreateObject("roMessagePort")
  screen.SetMessagePort(port)

  landing_items = CreateObject("roArray", 3, true)
  landing_items[0] = {
                      Title: "Your Files", 
                      HDSmallIconUrl: "pkg:/images/your-files.png", 
                    }
  landing_items[1] = {
                      Title: "Search", 
                      HDSmallIconUrl: "pkg:/images/search.png", 
                    }
  landing_items[2] = {
                      Title: "Settings", 
                      HDSmallIconUrl: "pkg:/images/settings.png", 
                    }
  screen.SetContent(landing_items)
  screen.Show()

  while (true)
      msg = wait(0, port)
      if (msg.isScreenClosed()) Then
          facade.Close()
          return -1
      end if
      if (type(msg) = "roListScreenEvent") then
        if (msg.isListItemSelected()) then
          if (msg.GetIndex() = 0) then
            list_root_url = "https://api.put.io/v2/files/list?oauth_token="+m.token
            FileBrowser(list_root_url)
          else if (msg.GetIndex() = 1) then
            Search(false)
          else if (msg.GetIndex() = 2) then
            res = Settings()
            if (res = 1) then
              screen.close()
              facade.close()
            end if
          end if
        end if
      end if
  end while
end function


function Settings() as Integer
  screen = CreateObject("roListScreen")
  port = CreateObject("roMessagePort")
  screen.SetMessagePort(port)

  items = CreateObject("roArray", 3, true)
  items[0] = {
      Title: "Unlink this device", 
      HDSmallIconUrl: "pkg:/images/unlink.png", 
  }
  if (m.subtitle_on = "on")
    s_title = "Disable subtitles"
  else 
    s_title = "Enable subtitles"
  end if

  items[1] = {
      Title: s_title,
      HDSmallIconUrl: "pkg:/images/subtitles.png", 
  }
  screen.SetContent(items)
  screen.Show()

  while (true)
      msg = wait(0, port)
      if (msg.isScreenClosed()) then
        return -1
      end if
      if (type(msg) = "roListScreenEvent") then
        if (msg.isListItemSelected()) then
          if (msg.GetIndex() = 0) then
            RegDelete("token")
            RegDelete("subtitle_on")
            screen.close()
            return 1
          else if (msg.GetIndex() = 1) then
            if (m.subtitle_on = "on")
              m.subtitle_on = "off"
            else
              m.subtitle_on = "on"
            end if
            return -1
          end if
        end if
      end if
  end while
end function

function InitTheme()
    app = CreateObject("roAppManager")

    secondaryText    = "#FFED6D"
    primaryText      = "#FFED6D"
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
        ListItemHighlightHD: "pkg:/images/selected-bg.png"
        ListItemHighlightSD: "pkg:/images/selected-bg.png"
        SpringboardTitleText: "#FFED6D"
        ButtonNormalColor: "#FFED6D"
        ButtonHighlightColor: "#FFED6D"
        ButtonMenuHighlightText: "#FFED6D"
        ButtonMenuNormalOverlayText: "#FFED6D"
        ButtonMenuNormalText: "#FFED6D"
        ParagraphBodyText: "#FFED6D"
        ParagraphHeaderText: "#FFED6D"
        RegistrationFocalColor: "FFFFFF"
        DialogBodyText: "#FFED6D"
        DialogTitleText: "#FFED6D"
        RegistrationCodeColor: "#FFED6D"
        RegistrationFocalColor: "#FFED6D"
        RegistrationFocalRectColor: "#FFED6D"
        RegistrationFocalRectHD: "#FFED6D"
        RegistrationFocalRectSD: "#FFED6D"
    }
    app.SetTheme( theme )
end function


function FileBrowser(url as string, search_history=invalid) as Integer
  screen = CreateObject("roListScreen")
  port = CreateObject("roMessagePort")
  screen.SetMessagePort(port)
  l = Loading()
  result = GetFileList(url)
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
  l.close()


  focusedItem = invalid

  while (true)
    msg = wait(0, port)
    if (msg.isScreenClosed()) then
        return -1
    end if

    if (type(msg) = "roListScreenEvent") then
      if msg.isListItemFocused()
          focusedItem = msg.GetIndex()
      end if

      if (msg.isRemoteKeyPressed()) then
        if (msg.GetIndex() = 10) then
          content_type = files[focusedItem].ContentType
          r = CreateObject("roRegex", "/", "")
          parsed_ct = r.Split(content_type)
          c_root = parsed_ct[0]
          c_format = parsed_ct[1]
          id = files[focusedItem].ID.tostr()

          if (content_type = "application/x-directory") then
            item = {
              ContentType: "episode"
              SDPosterUrl: "pkg:/images/mid-folder.png"
              ID: id
              title: files[focusedItem].Title
            }
            res = DeleteScreen(item)
            if (res = -1) then
              files.delete(focusedItem)
              screen.SetContent(files)
            end if
          else if (c_root = "video") then
            item = { 
              ContentType: "episode"
              SDPosterUrl: files[focusedItem].SDBackgroundImageUrl
              HDPosterUrl: files[focusedItem].HDBackgroundImageUrl
              ID: id
              title: files[focusedItem].Title
              }
            res = DeleteScreen(item)
            if (res = -1) then
              files.delete(focusedItem)
              screen.SetContent(files)
            end if
          else
            item = { 
              ContentType: "episode"
              SDPosterUrl: "pkg:/images/mid-file.png"
              ID: id
              title: files[focusedItem].Title
            }
            res = DeleteScreen(item)
            if (res = -1) then
              files.delete(focusedItem)
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
        id = files[msg.GetIndex()].ID.tostr()
        'bir item uzerinde OK butonuna basilirsa yapiacak isler burada tanimlaniyor'
        if (content_type = "application/x-directory") then
          if (files[msg.GetIndex()].size = 0) then
            item = { 
              ContentType: "episode"
              SDPosterUrl: "pkg:/images/mid-folder.png"
              ID: id
              title: files[msg.GetIndex()].Title
              NonVideo: true
            }
            res = SpringboardScreen(item)
            if (res = -1) then
              files.delete(msg.GetIndex())
              screen.SetContent(files)
            end if
          else
            id = files[msg.GetIndex()].ID.tostr()
            url = "https://api.put.io/v2/files/list?oauth_token="+m.token+"&parent_id="+id
            FileBrowser(url)
          end if
        else if (c_root = "video") then
          if (c_format = "mp4") then
            putio_api = "https://api.put.io/v2/files/"+id+"/stream?oauth_token="+m.token
            item = { 
              ContentType: "episode"
              SDPosterUrl: files[msg.GetIndex()].SDBackgroundImageUrl
              HDPosterUrl: files[msg.GetIndex()].HDBackgroundImageUrl
              ID: id
              title: files[msg.GetIndex()].Title
              url: putio_api
             }
            res = SpringboardScreen(item)
            if (res = -1) then
              files.delete(msg.GetIndex())
              screen.SetContent(files)
            end if
          else
            if (files[msg.GetIndex()].Mp4Available = true) then
              putio_api = "https://api.put.io/v2/files/"+id+"/mp4/stream?oauth_token="+m.token
              item = { 
                ContentType:"episode"
                SDPosterUrl: files[msg.GetIndex()].SDBackgroundImageUrl
                HDPosterUrl: files[msg.GetIndex()].HDBackgroundImageUrl
                ID: id
                title: files[msg.GetIndex()].Title
                url: putio_api
               }
              res = SpringboardScreen(item)
              if (res = -1) then
                files.delete(msg.GetIndex())
                screen.SetContent(files)
              end if
            else
              putio_api = "https://api.put.io/v2/files/"+id+"/stream?oauth_token="+m.token
              item = { 
                ContentType:"episode"
                SDPosterUrl: files[msg.GetIndex()].SDBackgroundImageUrl
                HDPosterUrl: files[msg.GetIndex()].SDBackgroundImageUrl
                ID: id
                title: files[msg.GetIndex()].Title
                convert_mp4: true
                url: putio_api
              }
              res = SpringboardScreen(item)
              if (res = -1) then
                files.delete(msg.GetIndex())
                screen.SetContent(files)
              end if
            end if
          end if
        else
          item = { 
            ContentType: "episode"
            SDPosterUrl: "pkg:/images/mid-file.png"
            ID: id
            title: files[msg.GetIndex()].Title
            NonVideo: true
          }
          res = SpringboardScreen(item)
          if (res = -1) then
            files.delete(msg.GetIndex())
            screen.SetContent(files)
          end if
        end if 
      end if
    end if
  end while
end function


function GetFileList(url as string) as object
  request = MakeRequest()

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
              hd_screenshot = "pkg:/images/mid-folder.png"
              sd_screenshot = "pkg:/images/mid-folder.png"
              sd_small = "pkg:/images/small-folder.png"
              hd_small = "pkg:/images/small-folder.png"
            else
              r = CreateObject("roRegex", "/", "")
              parsed_ct = r.Split(kind.content_type)
              c_root = parsed_ct[0]
              if (c_root <> "video") then
                sd_screenshot = "pkg:/images/mid-file.png"
                hd_screenshot = "pkg:/images/mid-file.png"
                sd_small = "pkg:/images/file-icon.png"
                hd_small = "pkg:/images/file-icon.png"
              else
                r = CreateObject("roRegex", "https://", "")
                ss = r.ReplaceAll(kind.screenshot, "http://")
                sd_screenshot = ss
                hd_screenshot = ss
                sd_small = "pkg:/images/playable-icon.png"
                hd_small = "pkg:/images/playable-icon.png"
              end if
            endif 

            topic = {
              Title: kind.name,
              ID: kind.id,
              Mp4Available: kind.is_mp4_available,
              ContentType: kind.content_type,
              SDBackgroundImageUrl: hd_screenshot, 
              HDPosterUrl: hd_screenshot,
              SDPosterUrl: sd_screenshot,
              ShortDescriptionLine1: kind.name,
              SDSmallIconUrl: sd_small, 
              HDSmallIconUrl: hd_small, 
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


function SpringboardScreen(item as object) As Integer
    if (item.DoesExist("NonVideo") = false) then
      l = Loading()
      redirected = ResolveRedirect(item["url"])
      item["url"] = redirected
    end if

    port = CreateObject("roMessagePort")
    screen = CreateObject("roSpringboardScreen")    
    screen.SetMessagePort(port)

    screen.SetDescriptionStyle("video") 'audio, movie, video, generic
                                        ' generic+episode=4x3,
    screen.ClearButtons()

    if (item.DoesExist("convert_mp4") = true) then
      request = MakeRequest()

      url = "https://api.put.io/v2/files/"+item["ID"]+"/mp4?oauth_token="+m.token
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
              screen.AddButton(2, "Convert to MP4")
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
          screen.AddButton(2, "Convert to MP4")
        end if
      end if
    else
      if (item.DoesExist("nonVideo") = false) then
        screen.AddButton(1, "Play")
      end if
    end if

    if (item.DoesExist("NonVideo") = false) then
        subtitles = invalid
        request = MakeRequest()
        url = "https://api.put.io/v2/files/"+item["ID"]+"/subtitles?oauth_token="+m.token
        port = CreateObject("roMessagePort")
        request.SetMessagePort(port)
        request.SetUrl(url)
        if (request.AsyncGetToString())
          msg = wait(0, port)
          if (type(msg) = "roUrlEvent") then
            code = msg.GetResponseCode()
            if (code = 200) then
                subtitles = ParseJSON(msg.GetString())
                for each subtitle in subtitles["subtitles"]
                  if (subtitles.default = subtitle.key) 
                    screen.AddButton(3, "Subtitles")
                  endif
                end for
            end if
          end if
        end if
    end if

    screen.AddButton(4, "Delete")

    screen.AllowUpdates(false)
    if item <> invalid and type(item) = "roAssociativeArray"
        screen.SetContent(item)
    endif

    screen.SetStaticRatingEnabled(false)
    screen.AllowUpdates(true)

    screen.Show()
    if (item.DoesExist("NonVideo") = false) then
      l.close()
    end if

    downKey=3
    selectKey=6
    subtitle_index = invalid
    while true
      msg = wait(0, screen.GetMessagePort())
      if type(msg) = "roSpringboardScreenEvent"
        if msg.isScreenClosed()
          exit while                
        else if msg.isButtonPressed()
          if msg.GetIndex() = 1
            if subtitle_index = invalid
              subtitle = subtitles.default
            else if subtitle_index = 0
              'Ayni scopeda degismis olabilir bu degisken. o yuzden tekrar ediyoruz' 
              subtitle = invalid
            else
              subtitle = subtitles["subtitles"][subtitle_index-1]["key"]
            end if
            DisplayVideo(item, subtitle)
          else if msg.GetIndex() = 2
            ConvertToMp4(item)
          else if msg.GetIndex() = 3
            tmp = SelectSubtitle(subtitles, item.SDPosterUrl)
            if tmp <> invalid
              'selectsubtitle invalid ya da 0, 1, 2... seklinde bir sonuc donuyor'
              'default subtitle secimi yapilan durumla karismamasi icin burdaki invalidi dikkate almiyoruz'
              'geri ok tusuyla hicbir sey yapmadan geri donulurse invalid donuyor'
              subtitle_index = tmp
            end if
          else if msg.GetIndex() = 4
            res = DeleteItem(item)  
            if (res = true) then
              return -1
            end if
          end if
        endif
      endif
    end while
end function


function DisplayVideo(args As object, subtitle)
    print "Displaying video: "
    p = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(p)
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
    if (m.subtitle_on = "on")
      if subtitle <> invalid
        videoclip.SubtitleUrl = "https://api.put.io/v2/files/"+args["ID"]+"/subtitles/"+subtitle+"?oauth_token="+m.token
      end if
    end if

    video.SetCertificatesFile("common:/certs/ca-bundle.crt")
    video.AddHeader("X-Roku-Reserved-Dev-Id", "")
    video.AddHeader("User-Agent", "PutioRoku Client 1.0")
    video.InitClientCertificates()

    video.SetContent(videoclip)
    video.show()
    video.ShowSubtitle(true)

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
              'if nowpos > 10000   
              'end if
              if nowpos > 0
                  if abs(nowpos - lastSavedPos) > statusInterval
                      lastSavedPos = nowpos
                  end if
              end if
          else if msg.isRequestFailed()
              print "play failed: "; msg.GetMessage()
          endif
      end if
    end while
end function


function ResolveRedirect(str As String) As String
    http = MakeRequest()
    http.SetUrl( str )
    event = http.Head()
    headers = event.GetResponseHeaders()
    redirect = headers.location
    if ( redirect <> invalid AND redirect <> str )
      str = redirect                
    endif
    r = CreateObject("roRegex", "https://", "")
    str = r.ReplaceAll(str, "http://")
    return str
end function


function ConvertToMp4(item as Object) as void
  request = MakeRequest()
  lc = Loading()
  url = "https://api.put.io/v2/files/"+item["ID"]+"/mp4?oauth_token="+m.token
  port = CreateObject("roMessagePort")
  request.SetMessagePort(port)
  request.SetUrl(url)
  if (request.AsyncPostFromString(""))
    msg = wait(0, port)
    if (type(msg) = "roUrlEvent")
      lc.close()
    else if (event = invalid)
      request.AsyncCancel()
      lc.close()
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
        screen.SetClearButtonEnabled(true) 'defaults to true'
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
              url ="https://api.put.io/v2/files/search/"+msg.GetMessage()+"?oauth_token="+m.token
              FileBrowser(url, history)
          endif
        endif
    end while 
end function
 

function DeleteItem(item as object) as Boolean
  l = Loading()
  request = MakeRequest()
  request.EnableEncodings(true)
  url = "https://api.put.io/v2/files/delete?oauth_token="+m.token
  port = CreateObject("roMessagePort")
  request.SetMessagePort(port)
  request.SetUrl(url)
  request.AddHeader("Content-Type","application/x-www-form-urlencoded")
  if (request.AsyncPostFromString("file_ids="+item["ID"]))
    msg = wait(0, port)
    if (type(msg) = "roUrlEvent")
      l.close()
      code = msg.GetResponseCode()
      if (code = 200)
        return true
      endif
    else if (event = invalid)
      request.AsyncCancel() 
      l.close()
      return false
    endif
  endif
end function


Sub Loading() as Object
  canvasItems = [
        { 
            url:"pkg:/images/app-icon.png"
            TargetRect:{x:500,y:240,w:290,h:218}
        },
        { 
            Text:"Thinking..."
            TextAttrs:{Color:"#FFED6D", Font:"Medium",
            HAlign:"HCenter", VAlign:"VCenter",
            Direction:"LeftToRight"}
            TargetRect:{x:390,y:467,w:500,h:60}
        }
  ] 
 
  canvas = CreateObject("roImageCanvas")
  port = CreateObject("roMessagePort")
  canvas.SetMessagePort(port)
  'Set opaque background'
  canvas.SetLayer(0, {Color:"#4D4D4D", CompositionMode:"Source"}) 
  canvas.SetRequireAllImagesToDraw(true)
  canvas.SetLayer(1, canvasItems)
  canvas.Show()
  return canvas
end Sub

 
function CheckSubtitle()
  l = Loading()
  request = MakeRequest()
  
  url = "https://api.put.io/v2/account/settings?oauth_token="+m.token
  port = CreateObject("roMessagePort")
  request.SetMessagePort(port)
  request.setUrl(url)

  if (request.AsyncGetToString())
    while (true)
      msg = wait(0, port)
      l.close()
      if (type(msg) = "roUrlEvent")
        code = msg.GetResponseCode()
        if (code = 200)
          json = ParseJSON(msg.GetString())
          lang = json["settings"]["default_subtitle_language"]
          if (Len(lang) = 0)
            return invalid
          end if
          return lang
        end if
      end if
    end while
  end if
  l.close()
  return invalid
end function



function RegRead(key, section=invalid)
    if section = invalid then section = "Default"
    sec = CreateObject("roRegistrySection", section)
    if sec.Exists(key) then return sec.Read(key)
    return invalid
end function


function RegWrite(key, val, section=invalid)
    if section = invalid then section = "Default"
    sec = CreateObject("roRegistrySection", section)
    sec.Write(key, val)
    sec.Flush() 'commit it'
end function


function RegDelete(key, section=invalid)
    if section = invalid then section = "Default"
    sec = CreateObject("roRegistrySection", section)
    sec.Delete(key)
    sec.Flush()
end function


function MakeRequest() as Object
  request = CreateObject("roUrlTransfer")
  request.SetCertificatesFile("common:/certs/ca-bundle.crt")
  request.AddHeader("X-Roku-Reserved-Dev-Id", "")
  request.AddHeader("User-Agent", "PutioRoku Client 1.0")
  request.InitClientCertificates()
  return request
end function


function GetDeviceESN()
    return CreateObject("roDeviceInfo").GetDeviceUniqueId()
end function


function DeleteScreen(item as object) As Integer
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSpringboardScreen")    
    screen.SetMessagePort(port)
    screen.SetDescriptionStyle("video") 
    screen.ClearButtons()
    screen.AddButton(1, "Delete")
    screen.SetStaticRatingEnabled(false)
    screen.AllowUpdates(true)
    if item <> invalid and type(item) = "roAssociativeArray"
        screen.SetContent(item)
    endif
    screen.Show()

    while true
      msg = wait(0, screen.GetMessagePort())
      if type(msg) = "roSpringboardScreenEvent"
        if msg.isScreenClosed()
          exit while                
        else if msg.isButtonPressed()
          if msg.GetIndex() = 1
            res = DeleteItem(item)  
            if (res = true) then
              return -1
            end if
          end if
        endif
      endif
    end while
end function


function SelectSubtitle(subtitles as object, screenshot)
    port = CreateObject("roMessagePort")
    screen = CreateObject("roSpringboardScreen")    
    screen.SetMessagePort(port)
    screen.SetDescriptionStyle("video") 
    screen.ClearButtons()
    screen.AddButton(0, "Don't load any subtitles")
    counter = 1
    for each subtitle in subtitles["subtitles"]
      screen.AddButton(counter, "Option "+counter.tostr())
      counter = counter + 1
    end for

    screen.SetStaticRatingEnabled(false)
    screen.AllowUpdates(true)
    item = {
      title: "Available "+subtitles["subtitles"][0].language+" Subtitles"
      ContentType: "episode"
      SDPosterUrl: screenshot
    }
    screen.SetContent(item)
    screen.Show()
    while true
      msg = wait(0, screen.GetMessagePort())
      if type(msg) = "roSpringboardScreenEvent"
        if msg.isScreenClosed()
          exit while                
        else if msg.isButtonPressed()
          subtitle_index = msg.GetIndex()
          return subtitle_index
        endif
      endif
    end while

end function

