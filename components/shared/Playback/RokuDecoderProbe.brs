' Roku says to query decoders before every play and never cache the answers, so build a
' fresh probe per play.
function createRokuDecoderProbe() as object
    return {
        deviceInfo: CreateObject("roDeviceInfo"),
        canDecodeVideo: rokuDecoderProbeCanDecodeVideo,
        canDecodeAudio: rokuDecoderProbeCanDecodeAudio,
        videoMode: rokuDecoderProbeVideoMode,
        isStb: rokuDecoderProbeIsStb,
        hdcp22Active: rokuDecoderProbeHdcp22Active,
        hdr10: rokuDecoderProbeHdr10
    }
end function

function rokuDecoderProbeCanDecodeVideo(request as object) as boolean
    answer = m.deviceInfo.CanDecodeVideo(request)
    return answer <> invalid and answer.result = true
end function

function rokuDecoderProbeCanDecodeAudio(request as object) as boolean
    answer = m.deviceInfo.CanDecodeAudio(request)
    return answer <> invalid and answer.result = true
end function

function rokuDecoderProbeVideoMode() as string
    return m.deviceInfo.GetVideoMode()
end function

' GetModelType returns "STB" or "TV"; anything else is treated as a streaming player.
function rokuDecoderProbeIsStb() as boolean
    return m.deviceInfo.GetModelType() <> "TV"
end function

function rokuDecoderProbeHdcp22Active() as boolean
    hdmiStatus = CreateObject("roHdmiStatus")
    return hdmiStatus <> invalid and hdmiStatus.IsHdcpActive("2.2") = true
end function

function rokuDecoderProbeHdr10() as boolean
    properties = m.deviceInfo.GetDisplayProperties()
    return properties <> invalid and properties.Hdr10 = true
end function
