function uiScreenWidth() as integer
    return 1920
end function

function uiScreenHeight() as integer
    return 1080
end function

function uiScaleGrid() as integer
    return 3
end function

function uiSnap(value as integer) as integer
    grid = uiScaleGrid()
    return Int((value + Int(grid / 2)) / grid) * grid
end function

function uiFloorToGrid(value as integer) as integer
    grid = uiScaleGrid()
    return Int(value / grid) * grid
end function

function uiCeilToGrid(value as integer) as integer
    grid = uiScaleGrid()
    return Int((value + grid - 1) / grid) * grid
end function

function uiCenterX(width as integer) as integer
    return uiSnap(Int((uiScreenWidth() - width) / 2))
end function

function uiCenterY(height as integer) as integer
    return uiSnap(Int((uiScreenHeight() - height) / 2))
end function

function uiBorderWidth() as integer
    return uiScaleGrid()
end function

function uiShadowOffset() as integer
    return 12
end function

function uiPageMargin() as integer
    return 102
end function

function uiListRowWidth() as integer
    return uiScreenWidth() - (uiPageMargin() * 2)
end function

function uiListRowHeight() as integer
    return 120
end function
