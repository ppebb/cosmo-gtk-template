local utils = require("scripts.utils")

local M = {}

local count = 1
local names = {}

function M.reset()
    count = 1
    names = {}
end

--- @class func
--- @field ret string
--- @field name string
--- @field args string

--- @param path string
--- @param match_access string[]
--- @param prefix string
--- @param trim_prefix boolean
--- @return func[]|nil
function M.process_header(path, match_access, prefix, trim_prefix)
    local ret = {}

    utils.fprintf(io.stdout, "\27[36mProcessing header %s, header number %s\n\27[0m", path, count)
    -- fprintf(io.stdout, "Processing header %s, header number %s\n", path, count)
    count = count + 1

    local header_split = utils.split(assert(utils.file_read(path)), "\n")
    local start = utils.find_in_table_str(header_split, "G_BEGIN_DECLS")
    local stop = utils.find_in_table_str(header_split, "G_END_DECLS")

    if not start or not stop then
        utils.fprintf(io.stdout, "Missing G_BEGIN_DECLS or G_END_DECLS in header %s, skipping\n", path)
        return nil
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
            utils.starts_with(line, "#")
            or utils.starts_with(line, "//")
            or utils.is_whitespace_or_nil(line) -- Only whitespace
            or line == "" -- Empty
            or skip_next
        then
            skip_next = false
            if utils.ends_with(line, "\\") then
                skip_next = true
            end
            goto continue
        end

        if line:match("/%*") and line:match("%*/") then
            local s, _ = line:find("/%*")
            local _, e = line:find("%*/")

            line = line:sub(1, s - 1) .. line:sub(e + 1, #line)

            if utils.is_whitespace_or_nil(line) then
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
            utils.starts_with(line, "typedef")
            or (utils.starts_with(line, "struct") and not line:match("[%(%)]"))
            or utils.starts_with(line, "union")
            or utils.starts_with(line, "enum")
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

    collected = utils.transform(collected, function(_, v) return v:gsub("%s+", " ") end)

    --- @param _line string
    --- @return string, string, string
    local function crack_line(_line)
        local ret_type, fname, args
        local line = _line

        -- Would be nice not to just eat stuff off of the end of the
        -- line, but if it has parentheses then it'd break so I'll just
        -- keep doing this even if it's bad
        line = utils.remove_match(line, " G_GNUC_CONST")
        line = utils.remove_match(line, " G_GNUC_PRINTF[ ]*%([0-9, ]*%)")
        line = utils.remove_match(line, " G_GNUC_NULL_TERMINATED")
        line = utils.remove_match(line, " G_GNUC_MALLOC")
        line = utils.remove_match(line, " G_GNUC_FORMAT[ ]*%([0-9, ]*%)")
        line = utils.remove_match(line, " G_GNUC_ALLOC_SIZE[ ]*%([0-9, ]*%)")
        line = utils.remove_match(line, " G_GNUC_ALLOC_SIZE2[ ]*%([0-9, ]*%)")
        line = utils.remove_match(line, " G_ANALYZER_NORETURN")
        line = utils.remove_match(line, " G_GNUC_WARN_UNUSED_RESULT")

        local line_split = utils.split(line, " ")

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
                args = utils.tbl_join(line_split, " ", i, paren_start_idx)

                if utils.starts_with(args, "(") then
                    next_segment_name = true
                else
                    local name_and_args = utils.split(args, "%(")
                    fname = name_and_args[1]
                    args = "(" .. name_and_args[2]
                    ret_type_start_idx = i - 1
                end
            end

            if
                utils.matches_any(segment, match_access)
                or (args and ret_type_start_idx and segment:find("%)"))
                or i == 1
            then
                ret_type = utils.tbl_join(line_split, " ", i + 1, ret_type_start_idx)
                break
            end

            ::continue::
        end

        while utils.starts_with(fname, "*") do
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

        if not utils.is_whitespace_or_nil(v) then
            print(v)
            local ret_type, fname, args = crack_line(v)

            utils.fprintf(io.stdout, "ret: %s\nname: %s\nargs: %s\n\n", ret_type, fname, args)

            assert(not utils.is_whitespace_or_nil(ret_type))
            assert(not utils.is_whitespace_or_nil(fname))
            assert(not utils.is_whitespace_or_nil(args))

            -- Someone put parenthesis around their function name...
            if fname:find("%)") then
                fname = fname:gsub("%)", "")
            end

            if fname:find("%(") then
                fname = fname:gsub("%(", "")
            end

            if utils.tbl_contains(names, fname) then
                utils.fprintf(io.stderr, "Duplicate name %s found in header %s\n", fname, path)
                goto continue
            else
                table.insert(names, fname)
            end

            if ret_type:find("static inline ") then
                goto continue
            end

            ret_type = utils.remove_match(ret_type, "static ")

            fname = trim_prefix and fname:gsub("^" .. prefix, "") or fname

            table.insert(ret, { ret = ret_type, name = fname, args = args })
        end

        ::continue::
    end

    return ret
end

return M