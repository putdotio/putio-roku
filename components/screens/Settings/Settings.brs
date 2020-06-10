function init()
  m.top.observeField("visible", "onVisibleChange")
  m.settingsList = m.top.findNode("settingsList")
  m.settingsList.observeField("itemSelected", "onListItemSelected")
  appInfo = createObject("roAppInfo")
  m.items = [
    {
      key: "version",
      title: "Version",
      description: appInfo.GetVersion()
    },
    {
      key: "logout"
      title: "Logout"
    }
  ]
  renderList()
end function

sub onVisibleChange()
  if m.top.visible
    m.settingsList.setFocus(true)
  end if
end sub

sub renderList()
  content = createObject("roSGNode", "ContentNode")

  for i = 0 to m.items.count() - 1
    item = m.items[i]
    listItemData = content.createChild("ListItemData")
    listItemData.key = item.key
    listItemData.title = item.title
    if item.description <> invalid
      listItemData.description = item.description
    end if
  end for

  m.settingsList.content = content
end sub

sub onListItemSelected(obj)
  key = m.settingsList.content.getChild(obj.getData()).key

  if key = "logout"
    storage = CreateObject("roRegistrySection", "user")
    storage.Delete("token")
    storage.Flush()
    m.top.navigate = {
      id: "authScreen"
      params: {}
    }
  end if
end sub

function onKeyEvent(key, press)
  if m.top.visible and key = "back" and press
    m.top.navigate = {
      id: "filesScreen"
      params: {}
    }
    return true
  end if

  return false
end function
