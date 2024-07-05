local M = {}

--- @param str string
--- @param start string
--- @return boolean
function M.starts_with(str, start) return str:sub(1, #start) == start end

--- @param str string
--- @param ending string
--- @return boolean
function M.ends_with(str, ending) return ending == "" or str:sub(-#ending) == ending end

--- @param path string
--- @return string
function M.fname(path) return path:match("([^/]+)$") end

--- @param str string
--- @return boolean
function M.is_whitespace_or_nil(str)
    if not str then
        return true
    end

    return str:match("^%s*$")
end

--- @param ... string
--- @return string
function M.path_combine(...)
    local args = { ... }
    local res = args[1]
    for i = 2, #args do
        local segment = args[i]
        local rew = M.ends_with(res, "/")
        local ssw = M.starts_with(segment, "/")

        if rew and ssw then
            segment = segment:sub(2)
        elseif not rew and not ssw then
            segment = "/" .. segment
        end

        res = res .. segment
    end

    return res
end

--- @param path string
--- @return boolean
function M.file_exists(path)
    local fd, _ = io.open(path, "r")

    if fd then
        fd:close()
        return true
    else
        return false
    end
end

--- @param str string
--- @param ... any
function M.fprintf(stream, str, ...) stream:write(string.format(str, ...)) end

--- @param path string
--- @return string|nil, string|nil
function M.file_read(path)
    local fd, err = io.open(path, "r")

    if fd then
        local ret = fd:read("a")
        fd:close()
        return ret, nil
    else
        return nil, err
    end
end

---
--- @param path string
--- @param contents string|number
function M.file_write(path, contents)
    local fd, err = io.open(path, "w")

    if fd then
        fd:write(contents)
        fd:close()
    else
        M.fprintf(io.stderr, "Failed to write to file %s, error: %s\n", path, err)
        os.exit(1, true)
    end
end

--- @param str string
--- @param delimiter string
--- @return string[]
function M.split(str, delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = str:find(delimiter, from)
    while delim_from do
        table.insert(result, str:sub(from, delim_from - 1))
        from = delim_to + 1
        delim_from, delim_to = str:find(delimiter, from)
    end
    table.insert(result, str:sub(from))
    return result
end

--- @param tbl string[]
--- @param pattern string
--- @return number|nil
function M.find_in_table_str(tbl, pattern)
    for i, v in ipairs(tbl) do
        if v:find(pattern) then
            return i
        end
    end

    return nil
end

function M.tbl_join(tbl, delim, s, e)
    local ret = ""
    local finish = e or #tbl

    for i = (s or 1), finish do
        ret = ret .. tbl[i] .. (i == finish and "" or delim)
    end

    return ret
end

--- @param tbl table
--- @param value any
--- @return boolean
function M.tbl_contains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end

    return false
end

--- @param tbl table
--- @param value any
--- @return boolean
function M.tbl_keys_contains(tbl, key)
    for k, _ in pairs(tbl) do
        if k == key then
            return true
        end
    end

    return false
end

function M.get_script_dir()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end

function M.popen_and_wait(...)
    local args = { ... }
    M.fprintf(io.stdout, "Running command %s\n", args[1])
    local fd = assert(io.popen(...))

    local out = ""

    while true do
        local line = fd:read("*L")

        if line then
            out = out .. line
        else
            break
        end
    end

    fd:close()
    return out
end

--- Applies `func` to each key-value pair in the table, providing the key and
--- value as arguments
--- @param tbl table
--- @param func function
--- @return table
function M.transform(tbl, func)
    local ret = {}

    for k, v in pairs(tbl) do
        ret[k] = func(k, v)
    end

    return ret
end

--- @param segment string
--- @param matches string[]
--- @return boolean, string|nil
function M.matches_any(segment, matches)
    if not matches then
        return false
    end

    for _, match in ipairs(matches) do
        if segment:find(match) then
            return true, match
        end
    end

    return false, nil
end

--- @param line string
--- @param match string
--- @return string, boolean
function M.remove_match(line, match)
    local ret = line
    local vs, ve = ret:find(match)
    if vs and ve then
        ret = ret:sub(1, vs - 1) .. ret:sub(ve + 1, #ret)
    end

    return ret, #ret ~= #line
end

return M
