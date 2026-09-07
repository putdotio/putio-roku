' Render-thread helpers for reporting to Sentry. Events are built here and handed to a
' SentryTask so the screen never waits on the network. Reporting is a no-op unless the
' package was built with a DSN (see PUTIO_ROKU_SENTRY_DSN in docs/ROKU_VARIANTS.md).
function sentryIsEnabled() as boolean
    return buildConfigSentryDsn() <> ""
end function

sub sentryCaptureEvent(event as object)
    if event = invalid or sentryIsEnabled() = false
        return
    end if

    task = createObject("roSGNode", "SentryTask")
    task.id = "sentryTask"
    task.dsn = buildConfigSentryDsn()
    task.event = event
    sentryRetainTask(task)
    task.control = "RUN"
end sub

' An unreferenced Task node can be collected mid-request, and the reporting screen is
' popped as soon as its failure dialog closes, so in-flight tasks hang off the scene's
' sentryTasks group rather than the screen. Finished tasks are pruned on the next capture.
sub sentryRetainTask(task as object)
    holder = invalid
    scene = m.top.getScene()
    if scene <> invalid
        holder = scene.findNode("sentryTasks")
    end if

    if holder = invalid
        if m.sentryTasks = invalid
            m.sentryTasks = []
        end if
        activeTasks = []
        for each activeTask in m.sentryTasks
            if activeTask.done = false
                activeTasks.push(activeTask)
            end if
        end for
        activeTasks.push(task)
        m.sentryTasks = activeTasks
        return
    end if

    for i = holder.getChildCount() - 1 to 0 step -1
        child = holder.getChild(i)
        if child.done
            holder.removeChildIndex(i)
        end if
    end for
    holder.appendChild(task)
end sub

function sentryCreateEvent(message as string, level as string) as object
    deviceInfo = CreateObject("roDeviceInfo")
    appInfo = CreateObject("roAppInfo")
    appVersion = appInfo.getVersion()
    osVersion = sentryFormatOsVersion(deviceInfo.getOSVersion())
    model = deviceInfo.getModel()
    modelName = deviceInfo.getModelDisplayName()
    if modelName = invalid or modelName = ""
        modelName = model
    end if

    event = {
        event_id: sentryEventId(deviceInfo),
        timestamp: CreateObject("roDateTime").asSeconds(),
        platform: "other",
        logger: "putio-roku",
        level: level,
        message: message,
        release: "putio-roku@" + appVersion,
        environment: buildConfigVariant(),
        sdk: {
            name: "putio-roku",
            version: appVersion,
        },
        contexts: {
            app: {
                app_name: "put.io Roku",
                app_version: appVersion,
            },
            device: {
                family: "Roku",
                model: model,
                name: modelName,
                model_id: model,
                screen_resolution: deviceInfo.getVideoMode(),
                connection_type: deviceInfo.getConnectionType(),
            },
            os: {
                name: "Roku OS",
                version: osVersion,
            },
        },
        tags: {
            roku_model: model,
            roku_os: osVersion,
            connection_type: deviceInfo.getConnectionType(),
            video_mode: deviceInfo.getVideoMode(),
        },
        extra: {},
    }

    ' /account/info reports the id as user_id; older payloads used id.
    if m.global <> invalid and m.global.hasField("user") and m.global.user <> invalid
        if m.global.user.user_id <> invalid
            event.user = { id: m.global.user.user_id.toStr() }
        else if m.global.user.id <> invalid
            event.user = { id: m.global.user.id.toStr() }
        end if
    end if

    return event
end function

sub sentryAddTags(event as object, tags as object)
    for each key in tags
        event.tags[key] = sentryTagValue(tags[key])
    end for
end sub

sub sentryAddExtra(event as object, extra as object)
    for each key in extra
        event.extra[key] = extra[key]
    end for
end sub

' Sentry tags are short strings; anything else becomes "unknown"/"none" style text.
function sentryTagValue(value) as string
    if value = invalid
        return "none"
    end if

    valueType = type(value)
    if valueType = "roString" or valueType = "String"
        if value = ""
            return "none"
        end if
        if Len(value) > 200
            return Left(value, 200)
        end if
        return value
    end if

    if valueType = "roBoolean" or valueType = "Boolean"
        if value
            return "true"
        end if
        return "false"
    end if

    if valueType = "roInt" or valueType = "Integer" or valueType = "roInteger" or valueType = "roFloat" or valueType = "Float" or valueType = "roDouble" or valueType = "Double" or valueType = "LongInteger" or valueType = "roLongInteger"
        return value.toStr()
    end if

    return "unknown"
end function

function sentryEventId(deviceInfo as object) as string
    uuid = deviceInfo.getRandomUUID()
    eventId = ""
    for i = 1 to Len(uuid)
        char = Mid(uuid, i, 1)
        if char <> "-"
            eventId = eventId + LCase(char)
        end if
    end for

    return eventId
end function

function sentryFormatOsVersion(osVersion as object) as string
    if osVersion = invalid
        return "unknown"
    end if

    parts = []
    for each key in ["major", "minor", "revision", "build"]
        if osVersion[key] <> invalid and osVersion[key].toStr() <> ""
            parts.push(osVersion[key].toStr())
        end if
    end for

    if parts.count() = 0
        return "unknown"
    end if

    version = parts[0]
    for i = 1 to parts.count() - 1
        version = version + "." + parts[i]
    end for

    return version
end function
