function init()
  m.top.observeField("visible", "onVisibleChange")

  m.list = m.top.findNode("list")
  m.list.observeField("itemSelected", "onListItemSelected")

  m.items = [
    {
      key: "files",
      title: "Your Files",
    },
    {
      key: "settings"
      title: "Settings"
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
  end for

  m.list.content = content
end sub

sub onListItemSelected(obj)
  key = m.list.content.getChild(obj.getData()).key

  if key = "files"
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
