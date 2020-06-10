function init()
  m.top.observeField("visible", "onVisibleChange")

  m.list = m.top.findNode("settingsList")
  m.list.observeField("itemSelected", "onListItemSelected")

  m.items = [
    {
      key: "version",
      title: "Version",
      description: createObject("roAppInfo").GetVersion(),
      iconName: "info"
    },
    {
      key: "logout",
      title: "Logout",
      iconName: "logout"
    }
  ]

  renderList()
end function

sub onVisibleChange()
  if m.top.visible
    m.list.setFocus(true)
  end if
end sub

sub renderList()
  content = createObject("roSGNode", "ContentNode")

  for i = 0 to m.items.count() - 1
    item = m.items[i]
    listItemData = content.createChild("ListItemData")
    listItemData.key = item.key
    listItemData.title = item.title
    listItemData.iconName = item.iconName
    if item.description <> invalid
      listItemData.description = item.description
    end if
  end for

  m.list.content = content
end sub

sub onListItemSelected(obj)
  key = m.list.content.getChild(obj.getData()).key

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
      id: "homeScreen"
      params: {}
    }
    return true
  end if

  return false
end function
