' Fake roDeviceInfo probe for the player tests: it answers from the case and records every
' decoder query.
function createFakeDecoderProbe(answers as object) as object
    return {
        answers: answers,
        calls: [],
        canDecodeVideo: function(request as object) as boolean
            m.calls.push({ query: "video", request: request })
            return m.answers.video
        end function,
        canDecodeAudio: function(request as object) as boolean
            m.calls.push({ query: "audio", request: request })
            return m.answers.audio
        end function,
        videoMode: function() as string
            return m.answers.videoMode
        end function,
        isStb: function() as boolean
            return m.answers.stb
        end function,
        hdcp22Active: function() as boolean
            return m.answers.hdcp22
        end function,
        hdr10: function() as boolean
            return m.answers.hdr10
        end function
    }
end function
