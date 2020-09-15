sub SubtitleWithDate(createdAt, subtitleText = invalid) as String
  date = convertDate(createdAt)
  if subtitleText <> invalid
    return date + " - " + subtitleText
  end if
  return date
end sub

' Upload
sub HistoryEventUploadTitle(event) as String
  return "You've uploaded " + event.file_name
end sub

sub HistoryEventUploadDescription(event) as String
  size = convertSize(event.file_size)
  return SubtitleWithDate(event.created_at, size)
end sub

' File shared
sub HistoryEventFileSharedTitle(event) as String
  return event.file_name
end sub

sub HistoryEventFileSharedDescription(event) as String
  return SubtitleWithDate(event.created_at, "shared by " + event.sharing_user_name)
end sub

' Transfer completed
sub HistoryEventTransferCompletedTitle(event) as String
  return event.transfer_name
end sub

sub HistoryEventTransferCompletedDescription(event) as String
  size = convertSize(event.transfer_size)
  return SubtitleWithDate(event.created_at, size)
end sub

' Transfer rrror
sub HistoryEventTransferErrorTitle(event) as String
  return "Error in transfer " + event.transfer_name
end sub

sub HistoryEventTransferErrorDescription(event) as String
  return SubtitleWithDate(event.created_at)
end sub

' File from RSS deleted
sub HistoryEventFileFromRSSDeletedTitle(event) as String
  return "We had to delete " + event.file_name + " per your instructions, since there wasn't enough free space."
end sub

sub HistoryEventFileFromRSSDeletedDescription(event) as String
  size = convertSize(event.file_size)
  return SubtitleWithDate(size)
end sub

' RSS paused
sub HistoryEventRSSPausedTitle(event) as String
  return event.rss_filter_title + " is paused because we couldn't reach the source"
end sub

sub HistoryEventRSSPausedDescription(event) as String
  return SubtitleWithDate(event.created_at)
end sub

' Transfer from RSS error
sub HistoryEventRSSTransferErrorTitle(event) as String
  return "Error in transfer from RSS for " + event.transfer_name
end sub

sub HistoryEventRSSTransferErrorDescription(event) as String
  return SubtitleWithDate(event.created_at)
end sub

'Transfer callback error
sub HistoryEventTransferCallbackErrorTitle(event) as String
  return "Error in transfer callback for " + event.transfer_name
end sub

sub HistoryEventTransferCallbackErrorDescription(event) as String
  return SubtitleWithDate(event.created_at, event.message)
end sub

' Private torrent pin
sub HistoryEventPrivateTorrentPinTitle(event) as String
  return "Your private IP `" + event.pinned_host_ip + "` was temporarily down, we had to use `" + event.new_host_ip + "` for " + event.user_download_name
end sub

sub HistoryEventPrivateTorrentPinDescription(event) as String
  return SubtitleWithDate(event.created_at)
end sub

' Voucher
sub HistoryEventVoucherTitle(event) as String
  return "Hey there. Welcome to put.io. We've made you and " + event.voucher_owner_name + " friends. You can see their shares now."
end sub

sub HistoryEventVoucherDescription(event) as String
  return SubtitleWithDate(event.created_at)
end sub

' Default - Any
sub HistoryEventAnyTitle(event) as String
  return event.type
end sub

sub HistoryEventAnyDescription(event) as String
  return SubtitleWithDate(event.created_at)
end sub

' Map
sub GetMapFromHistoryEventType(eventType) as Object
  eventMap = {
      upload: {
        title: HistoryEventUploadTitle,
        description: HistoryEventUploadDescription,
        icon: "cloud-upload-1",
      },
      file_shared: {
        title: HistoryEventFileSharedTitle,
        description: HistoryEventFileSharedDescription,
        icon: "cloud-add-1",
      },
      transfer_completed: {
        title: HistoryEventTransferCompletedTitle,
        description: HistoryEventTransferCompletedDescription,
        icon: "media-gallery-1",
      },
      transfer_error: {
        title: HistoryEventTransferErrorTitle,
        description: HistoryEventTransferErrorDescription,
        icon: "x-2-red",
      },
      file_from_rss_deleted_for_space: {
        title: HistoryEventFileFromRSSDeletedTitle,
        description: HistoryEventFileFromRSSDeletedDescription,
        icon: "exclamation-point-1",
      },
      rss_filter_paused: {
        title: HistoryEventRSSPausedDescription,
        description: HistoryEventRSSPausedDescription,
        icon: "rss-1",
      },
      transfer_from_rss_error: {
        title: HistoryEventRSSTransferErrorTitle,
        title: HistoryEventRSSTransferErrorDescription,
        icon: "x-2-red",
      },
      transfer_callback_error: {
        title: HistoryEventTransferCallbackErrorTitle,
        description: HistoryEventTransferCallbackErrorDescription,
        icon: "x-2-red",
      },
      private_torrent_pin: {
        title: HistoryEventPrivateTorrentPinTitle,
        description: HistoryEventPrivateTorrentPinDescription,
        icon: "exclamation-point-1",
      },
      voucher: {
        title: HistoryEventVoucherTitle,
        description: HistoryEventVoucherDescription,
        icon: "user-1",
      }
  }

  if eventMap[eventType] <> invalid
    return eventMap[eventType]
  end if
  
  return {
    title: HistoryEventAnyTitle,
    description: HistoryEventAnyDescription,
    icon: "x-2",
  }
end sub