local fs, imgui, io, json, log, math, os, pcall, re, sdk, string, table, thread, tonumber, tostring, type, ValueType, Vector2f, Vector3f, Vector4f, xpcall = fs, imgui, io, json, log, math, os, pcall, re, sdk, string, table, thread, tonumber, tostring, type, ValueType, Vector2f, Vector3f, Vector4f, xpcall

local this = {}

function this.count(ary)
    if (type(ary) ~= "table") then return 0 end

    local count = 0
    for _ in pairs(ary) do 
        count = count + 1 
    end
    return count
end

function this.is_equal(a, b)
    if (type(a) ~= "table") or (type(b) ~= "table") then return false end
    if (this.count(a) ~= this.count(b))             then return false end

    for key, value in pairs(a) do
        if (type(value) == "table") then 
            if not this.is_equal(value, b[key]) then return false end
        elseif (b[key] ~= value)                then return false end
    end
    for key in pairs(b) do 
        if (a[key] == nil) then return false end
    end
    return true
end

function this.deep_copy(from)
    local ary = {}
    if (from == nil)           then return ary  end
    if (type(from) ~= "table") then return from end
    for key, value in pairs(from) do 
        if (type(value) == "table") then ary[key] = this.deep_copy(value) 
        else                             ary[key] = value                 end
    end
    return ary
end

-- This custom merge function is intentionally designed to perform a defensive deep update. 
-- It only maps values from the source if the corresponding key already exists in the target table. 
-- This ensures data integrity and prevents outdated or corrupted legacy entries from persisting after a major data structure refactor.
function this.merge(target, from)
    if (type(target) ~= "table") or (type(from) ~= "table") then return end

    for key, value in pairs(target) do
        if (from[key] ~= nil) then 
            if (type(value) == "table") and (type(from[key]) == "table") then this.merge(value, from[key])
            else                                                              target[key] = from[key]     end
        end
    end
end

function this.is_contains(array, element)
    if (type(array) ~= "table") or (element == nil) then return false end
    for _, value in pairs(array) do
        if (value == element) then return true end
    end
    return false
end

return this