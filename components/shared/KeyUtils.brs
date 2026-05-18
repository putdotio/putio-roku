function isOptionsKey(key as string) as boolean
    normalizedKey = LCase(key)
    return normalizedKey = "options" or normalizedKey = "info"
end function
