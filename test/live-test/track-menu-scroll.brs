' Driver for track-menu.test.ts, run by the @rokucommunity/brs interpreter. Returns
' getTrackMenuScrollOffset from TrackMenu.brs as offsets[rowCount][itemCount][focusedIndex].
function main() as string
    offsets = []
    for rowCount = 0 to 10
        byItemCount = []
        for itemCount = 0 to 16
            byFocus = []
            for focusedIndex = 0 to itemCount - 1
                byFocus.push(getTrackMenuScrollOffset(itemCount, focusedIndex, rowCount))
            end for
            byItemCount.push(byFocus)
        end for
        offsets.push(byItemCount)
    end for

    return formatJson(offsets)
end function
