local lfs = require("lfs")

--- @param str string
--- @param start string
--- @return boolean
local function starts_with(str, start) return str:sub(1, #start) == start end

--- @param str string
--- @param ending string
--- @return boolean
local function ends_with(str, ending) return ending == "" or str:sub(-#ending) == ending end

--- @param str string
--- @return boolean
local function is_whitespace_or_nil(str)
    if not str then
        return true
    end

    return str:match("^%s*$")
end

--- @param ... string
--- @return string
local function path_combine(...)
    local args = { ... }
    local res = args[1]
    for i = 2, #args do
        local segment = args[i]
        local rew = ends_with(res, "/")
        local ssw = starts_with(segment, "/")

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
local function file_exists(path)
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
local function fprintf(stream, str, ...) stream:write(string.format(str, ...)) end

--- @param path string
--- @return string|nil, string|nil
local function file_read(path)
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
local function file_write(path, contents)
    local fd, err = io.open(path, "w")

    if fd then
        fd:write(contents)
        fd:close()
    else
        fprintf(io.stderr, "Failed to write to file %s, error: %s\n", path, err)
        os.exit(1, true)
    end
end

--- @param str string
--- @param delimiter string
--- @return string[]
local function split(str, delimiter)
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
local function find_in_table_str(tbl, pattern)
    for i, v in ipairs(tbl) do
        if v:find(pattern) then
            return i
        end
    end

    return nil
end

local function tbl_join(tbl, delim, s, e)
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
local function tbl_contains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end

    return false
end

local function get_script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end

local function popen_and_wait(...)
    local args = { ... }
    fprintf(io.stdout, "Running command %s\n", args[1])
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
local function transform(tbl, func)
    local ret = {}

    for k, v in pairs(tbl) do
        ret[k] = func(k, v)
    end

    return ret
end

--- @param segment string
--- @param matches string[]
--- @return boolean
local function matches_any(segment, matches)
    if not matches then
        return false
    end

    for _, match in ipairs(matches) do
        if segment:find(match) then
            return true
        end
    end

    return false
end

--- @param line string
--- @param match string
--- @return string
local function remove_match(line, match)
    local ret = line
    local vs, ve = ret:find(match)
    if vs and ve then
        ret = ret:sub(1, vs - 1) .. ret:sub(ve + 1, #ret)
    end

    return ret
end

-- SCRIPT BEGINS HERE!!

local defs = {
    gtk4 = {
        headers = "/usr/include/gtk-4.0/gtk/",
        name = "gtk",
        clear_headers = false,
        lib_headers = { "GTK4/gtk.h" },
        candidates = { "libgtk-4.so" }, -- TODO: Windows, mac
        match_access = { "GDK_[A-Z0-9_]+" },
        skip_dirs = { "a11y", "deprecated", "print" },
        prefix = "gtk_", -- Function prefix, such as the gtk_ in gtk_init()
        trim_prefix = true, -- Remove the prefix from function names. This allows for them to be called as gtk->init() instead of gtk->gtk_init()
    },
    glib = { -- Includes gio, gmodule, gobject, girepository
        headers = "/usr/include/glib-2.0/",
        name = "glib",
        clear_headers = false,
        lib_headers = {
            "glib.h",
            "glib-unix.h",
            "glib/gstdio.h",
            "gio/gio.h",
            "girepository/girepository.h",
            "girepository/girffi.h",
        },
        candidates = { "libglib-2.0.so" }, -- TODO: Windows, mac
        match_access = {
            "GLIB_[A-Z0-9_]+",
            "GIO_[A-Z0-9_]+",
            "GI_[A-Z0-9_]+",
            "GOBJECT_[A-Z0-9_]+",
            "G_MODULE_EXPORT[A-Z0-9_]*",
            "G_NORETURN",
            "GMODULE_[A-Z0-9_]+",
        },
        skip_files = { "%.c$" },
        extra_headers = {
            { "/usr/include/ffi.h", "girepository/ffi.h" },
            { "/usr/include/ffitarget.h", "girepository/ffitarget.h" },
        },
        fix_headers = true,
        prefix = "g_",
        trim_prefix = true,
    },
}

local script_path = get_script_path() or "./"

-- Templates
local stub_c_path = path_combine(script_path, "stub.c-template")
local stub_h_path = path_combine(script_path, "stub.h-template")
local stub_c, err_c = file_read(stub_c_path)
local stub_h, err_h = file_read(stub_h_path)

if not stub_c or not stub_h then
    fprintf(io.stderr, "Unable to read stub.c-template or stub.h-template, error: %s\n", err_c or err_h)
    os.exit(1, true)
end

for stub, stub_spec in pairs(defs) do
    local name = stub_spec.name
    local name_u = stub_spec.name:upper()
    local headers_path = stub_spec.headers
    local stub_dir = path_combine(script_path, stub .. "-stub")
    local headers_dest = path_combine(stub_dir, stub:upper())
    local clear_headers = stub_spec.clear_headers

    local names = {}

    local stub_c_out_path = path_combine(stub_dir, stub .. "_stub.c")
    local stub_h_out_path = path_combine(stub_dir, stub .. "_stub.h")

    if not file_exists(headers_path) then
        fprintf(io.stdout, "%s header path %s does not exist or does not have read access!\n", stub, headers_path)
        os.exit(1, true)
    end

    -- Make main stub directory
    if not file_exists(stub_dir) then
        assert(lfs.mkdir(stub_dir))
    end

    -- Copy headers
    do
        -- Clear headers if they exist and it's set to clear
        if clear_headers and file_exists(headers_dest) then
            -- luafilesystem also does not have recursive delete!!
            fprintf(io.stdout, "Clearing directory %s\n", headers_dest)
            local _ = popen_and_wait("rm -r " .. headers_dest)
        end

        -- Copy headers if they are not already there
        if not file_exists(headers_dest) then
            fprintf(io.stdout, "Copying %s header files from %s into %s\n", stub, headers_path, headers_dest)
            assert(lfs.mkdir(headers_dest))
            -- Unfortunately, luafilesystem does not have a copy function... this is
            -- already platform specific so I don't care for now!
            local _ = popen_and_wait(string.format('sh -c "cp -r %s/* %s"', headers_path, headers_dest))
        end

        if stub_spec.extra_headers then
            fprintf(io.stdout, "Copying additional headers for %s\n", stub)

            for _, h in ipairs(stub_spec.extra_headers) do
                local src = h[1]
                local dest = path_combine(headers_dest, h[2])

                if not file_exists(dest) then
                    popen_and_wait(string.format('sh -c "cp %s %s"', src, dest))
                end
            end
        end

        if stub_spec.fix_headers then
            local fixed_up_marker = path_combine(headers_dest, ".fixed_up")
            if not file_exists(fixed_up_marker) then
                fprintf(io.stdout, "Fixing up headers for %s!\n", stub)
                file_write(fixed_up_marker, "")

                print(popen_and_wait(string.format('sh -c "./patch_headers.sh %s"', headers_dest)))
            end
        end
    end

    -- Generation
    do
        -- Replace placeholder text
        local lib_headers = tbl_join(
            transform(stub_spec.lib_headers, function(_, v) return string.format('#include "%s"', v) end),
            "\n"
        )

        local stub_h_copy = stub_h:gsub("::LIB_HEADERS::", lib_headers)

        local stub_c_copy = stub_c:gsub("::NAME_UPPER::", name_u)
        stub_h_copy = stub_h_copy:gsub("::NAME_UPPER::", name_u)

        stub_c_copy = stub_c_copy:gsub("::NAME::", name)
        stub_h_copy = stub_h_copy:gsub("::NAME::", name)

        stub_c_copy = stub_c_copy:gsub("::LIB_NAME::", stub)
        stub_c_copy = stub_c_copy:gsub("::STUB_HEADER::", string.format('#include "%s_stub.h"', stub))
        stub_c_copy = stub_c_copy:gsub(
            "::CANDIDATES::",
            tbl_join(transform(stub_spec.candidates, function(_, v) return string.format('"%s"', v) end), ", ")
        )

        -- Resplit every time just because this also copies the table. Only have to read the templates once
        local stub_c_split = split(stub_c_copy, "\n")
        local stub_h_split = split(stub_h_copy, "\n")

        local stub_c_start = find_in_table_str(stub_c_split, "INIT_HERE") + 1
        local stub_h_start = find_in_table_str(stub_h_split, "SYMS_HERE") + 1

        local count = 1

        local function process_header(path)
            fprintf(io.stdout, "\27[36mProcessing header %s, header number %s\n\27[0m", path, count)
            -- fprintf(io.stdout, "Processing header %s, header number %s\n", path, count)
            count = count + 1

            local header_split = split(assert(file_read(path)), "\n")
            local start = find_in_table_str(header_split, "G_BEGIN_DECLS")
            local stop = find_in_table_str(header_split, "G_END_DECLS")

            if not start or not stop then
                fprintf(io.stdout, "Missing G_BEGIN_DECLS or G_END_DECLS in header %s, skipping\n", path)
                return
            end

            local collected = {}

            local in_thing_to_ignore = false
            local curly_depth = 0
            local skip_next = false
            local in_multiline_comment = false

            for i = start + 1, stop - 1 do
                local line = header_split[i]

                -- Skip comments and #defines
                if
                    starts_with(line, "#")
                    or starts_with(line, "//")
                    or is_whitespace_or_nil(line) -- Only whitespace
                    or line == "" -- Empty
                    or skip_next
                then
                    skip_next = false
                    if ends_with(line, "\\") then
                        skip_next = true
                    end
                    goto continue
                end

                if line:match("/%*") and line:match("%*/") then
                    local s, _ = line:find("/%*")
                    local _, e = line:find("%*/")

                    line = line:sub(1, s - 1) .. line:sub(e + 1, #line)

                    if is_whitespace_or_nil(line) then
                        goto continue
                    end
                end

                if line:match("^[ ]*/%*") and not line:match("[ ]*%*/") then
                    in_multiline_comment = true
                end

                if in_multiline_comment and line:match("[ ]*%*/") then
                    in_multiline_comment = false
                    goto continue
                end

                if in_multiline_comment then
                    goto continue
                end

                if
                    starts_with(line, "typedef")
                    or starts_with(line, "struct")
                    or starts_with(line, "union")
                    or starts_with(line, "enum")
                then
                    if header_split[i + 1]:find("{") then
                        goto continue
                    elseif not line:find("{") then
                        in_thing_to_ignore = true
                    end
                end

                if in_thing_to_ignore then
                    if line:find(";") then
                        in_thing_to_ignore = false
                    end

                    goto continue
                end

                if line:match("{") then
                    curly_depth = curly_depth + 1
                end

                if curly_depth > 0 and line:match("}") then
                    curly_depth = curly_depth - 1

                    if curly_depth == 0 then
                        goto continue
                    end
                end

                if curly_depth > 0 then
                    goto continue
                end

                local s, e = line:find(";")

                if not s or not e then
                    collected[#collected] = (collected[#collected] or "") .. " " .. line
                else
                    collected[#collected] = (collected[#collected] or "") .. " " .. line:sub(1, s)
                    collected[#collected + 1] = line:sub(e + 1, #line)
                end

                ::continue::
            end

            collected = transform(collected, function(_, v) return v:gsub("%s+", " ") end)

            --- @param _line string
            --- @return string, string, string
            local function crack_line(_line)
                local ret_type, fname, args
                local line = _line

                -- Would be nice not to just eat stuff off of the end of the
                -- line, but if it has parentheses then it'd break so I'll just
                -- keep doing this even if it's bad
                line = remove_match(line, " G_GNUC_CONST")
                line = remove_match(line, " G_GNUC_PRINTF[ ]*%([0-9, ]*%)")
                line = remove_match(line, " G_GNUC_NULL_TERMINATED")
                line = remove_match(line, " G_GNUC_MALLOC")
                line = remove_match(line, " G_GNUC_FORMAT[ ]*%([0-9, ]*%)")
                line = remove_match(line, " G_GNUC_ALLOC_SIZE[ ]*%([0-9, ]*%)")
                line = remove_match(line, " G_GNUC_ALLOC_SIZE2[ ]*%([0-9, ]*%)")
                line = remove_match(line, " G_ANALYZER_NORETURN")
                line = remove_match(line, " G_GNUC_WARN_UNUSED_RESULT")

                local line_split = split(line, " ")

                local in_paren_block = false
                local paren_start_idx
                local next_segment_name = false
                local ret_type_start_idx

                for i = #line_split, 1, -1 do
                    local segment = line_split[i]

                    if next_segment_name then
                        fname = segment
                        next_segment_name = false
                        ret_type_start_idx = i - 1
                        goto continue
                    end

                    if not args and not in_paren_block and segment:find("%)") then
                        in_paren_block = true
                        paren_start_idx = i
                    end

                    if in_paren_block and segment:find("%(") then
                        in_paren_block = false
                        args = tbl_join(line_split, " ", i, paren_start_idx)

                        if starts_with(args, "(") then
                            next_segment_name = true
                        else
                            local name_and_args = split(args, "%(")
                            fname = name_and_args[1]
                            args = "(" .. name_and_args[2]
                            ret_type_start_idx = i - 1
                        end
                    end

                    if
                        matches_any(segment, stub_spec.match_access)
                        or (args and ret_type_start_idx and segment:find("%)"))
                        or i == 1
                    then
                        ret_type = tbl_join(line_split, " ", i + 1, ret_type_start_idx)
                        break
                    end

                    ::continue::
                end

                while starts_with(fname, "*") do
                    fname = fname:sub(2, #fname)
                    ret_type = ret_type .. "*"
                end

                -- Handle weird edge case for when no space is left between the
                -- type and the function name
                local as, ae = fname:find("[%*]+")

                if as and ae then
                    local temp = fname
                    fname = temp:sub(ae + 1, #fname)
                    ret_type = temp:sub(1, ae)
                end

                local args_trimmed = args:sub(2, #args - 2)
                if #args_trimmed == 0 then
                    args_trimmed = "void"
                end

                return ret_type, fname, args_trimmed
            end

            for _, _v in pairs(collected) do
                local v = _v

                if
                    v:match("G_DECLARE_INTERFACE")
                    or v:match("G_DEFINE_AUTOPTR_CLEANUP_FUNC")
                    or v:match("G_TYPE_CHECK")
                    or v:match("G_GNUC_[A-Z]*_IGNORE_DEPRECATIONS")
                    or v:match("GMODULE_[A-Z]*_ENUMERATOR")
                    or v:match("GLIB_[A-Z]*_ENUMERATOR")
                    or v:match("GIO_[A-Z]*_TYPE_IN")
                    or v:match("GLIB_VAR")
                    or v:match("GOBJECT_VAR")
                    -- Broken ass function I'm not fixing my fragile parser for
                    or v:match("g_win32_get_system_data_dirs_for_module")
                then
                    goto continue
                end

                if not is_whitespace_or_nil(v) then
                    print(v)
                    local ret_type, fname, args = crack_line(v)

                    fprintf(io.stdout, "ret: %s\nname: %s\nargs: %s\n", ret_type, fname, args)

                    assert(not is_whitespace_or_nil(ret_type))
                    assert(not is_whitespace_or_nil(fname))
                    assert(not is_whitespace_or_nil(args))

                    -- Someone put parenthesis around their function name...
                    if fname:find("%)") then
                        fname = fname:gsub("%)", "")
                    end

                    if fname:find("%(") then
                        fname = fname:gsub("%(", "")
                    end

                    if tbl_contains(names, fname) then
                        fprintf(io.stderr, "Duplicate name %s found in header %s\n", fname, path)
                        goto continue
                    else
                        table.insert(names, fname)
                    end

                    if ret_type:find("static inline ") then
                        goto continue
                    end

                    ret_type = remove_match(ret_type, "static ")

                    local fname_trimmed = stub_spec.trim_prefix and fname:gsub("^" .. stub_spec.prefix, "") or fname

                    local stub_c_line = string.format(
                        '        .%s = cosmo_dlsym(%s, "%s"),',
                        fname_trimmed,
                        stub_spec.name .. "_lib_ptr",
                        fname
                    )
                    local stub_h_line = string.format("    %s (*%s)(%s);", ret_type, fname_trimmed, args)

                    table.insert(stub_c_split, stub_c_start, stub_c_line)
                    table.insert(stub_h_split, stub_h_start, stub_h_line)

                    fprintf(io.stdout, "stub_c_line: %s\n", stub_c_line)
                    fprintf(io.stdout, "stub_h_line: %s\n", stub_h_line)
                    print("\n")

                    stub_c_start = stub_c_start + 1
                    stub_h_start = stub_h_start + 1
                end

                ::continue::
            end
        end

        local function process_dir(path)
            fprintf(io.stdout, "Processing directory %s\n", path)
            for entry in lfs.dir(path) do
                if entry ~= "." and entry ~= ".." then
                    local full_path = path_combine(path, entry)
                    local attr = lfs.attributes(full_path)

                    if attr.mode == "directory" and not matches_any(entry, stub_spec.skip_dirs) then
                        process_dir(full_path)
                    elseif attr.mode == "file" and not matches_any(entry, stub_spec.skip_files) then
                        process_header(full_path)
                    end
                end
            end
        end

        process_dir(headers_dest)

        local stub_c_out = tbl_join(stub_c_split, "\n")
        local stub_h_out = tbl_join(stub_h_split, "\n")

        fprintf(io.stdout, "Writing %s_stub.c\n", stub)
        file_write(stub_c_out_path, stub_c_out)
        fprintf(io.stdout, "Writing %s_stub.h\n", stub)
        file_write(stub_h_out_path, stub_h_out)
    end
end

print("Creating stub archive")
popen_and_wait('sh -c "tar cvf ./stubs.tar.gz *-stub"')