function init()
  m.top.observeField("visible", "onVisibleChange")

  m.list = m.top.findNode("list")
  m.list.observeField("itemSelected", "onListItemSelected")

  m.items = [
    {
      key: "search",
      title: "Search",
      iconName: "search"
    },
    {
      key: "files",
      title: "Your Files",
      iconName: "file_type_folder"
    },
    {
      key: "settings"
      title: "Settings"
      iconName: "settings"
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
  end for

  m.list.content = content
end sub

sub onListItemSelected(obj)
  key = m.list.content.getChild(obj.getData()).key

  if key = "search"
    m.top.navigate = {
      id: "searchScreen",
      params: {}
    }

  else if key = "files"
    m.top.navigate = {
      id: "filesScreen"
      params: {
        fileId: 0
      }
    }

  else if key = "settings"
    m.top.navigate = {
      id: "settingsScreen",
      params: {},
    }

  end if
end sub

function onKeyEvent(key, press)
  if m.top.visible and press and key = "back"
    m.top.showExitAppDialog = true
    return true
  end if
end function
