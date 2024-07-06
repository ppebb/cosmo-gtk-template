local lfs = require("lfs")
local parser = require("scripts.parse_header")
local utils = require("scripts.utils")

local M = {}
M.__index = M

M.copied_headers = {}

local function copy_headers(lib_name, source, dest, force)
    table.insert(M.copied_headers, string.format("%s;%s", source, dest))
    -- Check source exists or else something is very wrong
    if not utils.file_exists(source) then
        utils.fprintf(io.stdout, "%s header path %s does not exist or does not have read access!\n", lib_name, source)
        os.exit(1, true)
    end

    -- Copy headers if they are not already there
    if force or not utils.file_exists(dest) then
        utils.fprintf(io.stdout, "Copying %s header file(s) from %s into %s\n", lib_name, source, dest)

        -- Unfortunately, luafilesystem does not have a copy function... this is
        -- already platform specific so I don't care for now!
        local _ = utils.popen_and_wait(string.format('sh -c "cp -r %s %s"', source, dest))
    else
        utils.fprintf(io.stdout, "Header files for %s already present at %s\n", lib_name, dest)
    end
end

local INIT_LIB_TEMPLATE = [[
    char *candidates_::NAME::[] = { ::CANDIDATES:: };
    ::NAME:: = try_find_lib(candidates_::NAME::, LEN(candidates_::NAME::));

    if (!::NAME::) {
        fprintf(stderr, "Unable to locate ::NAME::, exiting!");
        exit(1);
    }
]]

local RAYO_COSMICO = " __builtin_unreachable(); /* oops rayo cosmico */ "

--- @param args string
--- @return string[]
local function args_split(args)
    local ret = {}

    for arg_name in (args .. ","):gmatch("[ *]([A-Za-z_0-9]+)[%[0-9%]]*,") do
        table.insert(ret, arg_name)
    end

    return ret
end

--- @param names_to_args table<string, string>
--- @param fname string
--- @param fargs string[]
--- @return string|nil, string|nil, string|nil, string|nil
function M:try_find_va_equivalent(names_to_args, fname, fargs)
    local prefixless = self.prefix and utils.remove_match(fname, self.prefix) or nil
    local f_split = utils.split(prefixless or fname, "_")
    local patterns = {}

    table.insert(patterns, fname .. "[_]*va*$")
    table.insert(patterns, fname .. "[_]*valist$")

    for i = 1, #f_split do
        local prefix_vfname = ""

        for j, segment in ipairs(f_split) do
            prefix_vfname = prefix_vfname .. (j ~= 1 and "_" or "") .. (j == i and "v" or "") .. segment
        end

        table.insert(patterns, (self.prefix or "") .. prefix_vfname)
    end

    local matched, pattern, err
    local function print_err(name, args)
        utils.fprintf(
            io.stderr,
            "Found va_equiv for func %s as func %s(%s) with pattern %s, but err: %s\n",
            fname,
            name,
            args,
            pattern,
            err
        )
    end

    for name, args in pairs(names_to_args) do
        for _, p_temp in ipairs(patterns) do
            if name:match(p_temp) then
                if not args:match("va_list") then
                    matched = name
                    pattern = p_temp
                    err = "va_list missing"
                    print_err(name, args)
                else
                    if #args_split(args) ~= #fargs + 1 then
                        matched = name
                        pattern = p_temp
                        err = "args count mismatch"
                        print_err(name, args)
                    else
                        return name, p_temp, args:match("va_list[ ]*%*") and "ptr" or "", nil
                    end
                end
            end
        end
    end

    return matched, pattern, nil, err
end

function M:with_shared_object(name, candidates)
    self.current_shared_object = name

    local init = INIT_LIB_TEMPLATE:gsub("::NAME::", name)
    init = init:gsub(
        "::CANDIDATES::",
        utils.tbl_join(utils.transform(candidates, function(_, v) return string.format('"%s"', v) end), ", ")
    )

    table.insert(self.c_lib_defs, string.format("void *%s;", name))
    table.insert(self.c_lib_init, init)
    table.insert(self.c_lib_free, string.format("cosmo_dlclose(%s);", name))

    return self
end

function M:use_shared_object(name)
    self.current_shared_object = name

    return self
end

function M:with_lib_headers(lib_headers)
    local joined =
        utils.tbl_join(utils.transform(lib_headers, function(_, v) return string.format("#include <%s>", v) end), "\n")

    self.h = joined .. "\n" .. self.h

    return self
end

function M:with_extra_headers(headers, dest)
    for _, header in ipairs(headers) do
        copy_headers(self.name, header, utils.path_combine(dest, utils.fname(header)))
    end

    return self
end

function M:set_prefix(prefix)
    self.prefix = prefix
    return self
end

function M:set_trim_prefix(trim_prefix)
    self.trim_prefix = trim_prefix
    return self
end

function M:set_skip_dirs(dirs)
    self.skip_dirs = dirs
    return self
end

function M:set_skip_files(files)
    self.skip_files = files
    return self
end

function M:set_match_access(m)
    self.match_access = m
    return self
end

function M:set_skip_funcs(fs)
    self.skip_funcs = fs
    return self
end

function M:process_headers(headers)
    local function process_dir(path)
        utils.fprintf(io.stdout, "Processing directory %s\n", path)
        for entry in lfs.dir(path) do
            if entry ~= "." and entry ~= ".." then
                self:process_headers({ utils.path_combine(path, entry) })
            end
        end
    end

    for _, header in ipairs(headers) do
        local attr = lfs.attributes(header)

        if not attr then
            utils.fprintf(io.stderr, "Header %s does not exist or could not be accessed!", header)
        end

        if attr.mode == "directory" and not utils.matches_any(header, self.skip_dirs) then
            process_dir(header)
        elseif attr.mode == "file" and not utils.matches_any(header, self.skip_files) then
            local funcs =
                self.parser:process_header(header, self.match_access, self.prefix, self.trim_prefix, self.skip_funcs)

            if not funcs then
                goto continue
            end

            table.insert(self.c_struct_defs, "// Header " .. header)
            table.insert(self.c_struct_inst, "// Header " .. header)
            table.insert(self.h_func_defs, "// Header " .. header)

            for _, func in ipairs(funcs) do
                local ret = func.ret
                local name = func.name
                local args = func.args
                local extras = func.extras

                local arg_names = args_split(args)

                local sig = string.format("%s (%s)(%s)", ret, name, args)

                if not args:find("%.%.%.") then
                    table.insert(self.c_struct_defs, string.format("%s (*ptr_%s)(%s);", ret, name, args))
                    table.insert(
                        self.c_struct_inst,
                        string.format(
                            'stub_funcs.ptr_%s = try_find_sym(%s, "%s");',
                            name,
                            self.current_shared_object,
                            name
                        )
                    )
                    table.insert(
                        self.c_func_impls,
                        string.format(
                            sig .. " { %sstub_funcs.ptr_%s(%s);%s }",
                            ret ~= "void" and "return " or "",
                            name,
                            utils.tbl_join(arg_names, ", "),
                            extras.no_return and RAYO_COSMICO or ""
                        )
                    )
                    table.insert(self.h_func_defs, sig .. ";")
                else
                    local va_equiv, pattern, info, err =
                        self:try_find_va_equivalent(self.parser.names_to_args, name, arg_names)

                    if not va_equiv then
                        local msg = "Unable to locate va_equiv for " .. name
                        table.insert(self.c_func_impls, "// " .. msg)
                        utils.fprintf(io.stderr, "%s\n", msg)
                    elseif err then
                        table.insert(
                            self.c_func_impls,
                            string.format(
                                "// Found va_equiv for func %s as func %s with pattern %s, but err: %s",
                                name,
                                va_equiv,
                                pattern,
                                err
                            )
                        )
                    else
                        local nonvoid = ret ~= "void"
                        table.insert(
                            self.c_func_impls,
                            string.format(
                                sig
                                    .. " { %sva_list vaargs; va_start(vaargs, %s); %sstub_funcs.ptr_%s(%s); va_end(vaargs); %s}",
                                nonvoid and (ret .. " ret; ") or "",
                                arg_names[#arg_names],
                                nonvoid and "ret = " or "",
                                va_equiv,
                                utils.tbl_join(arg_names, ", ")
                                    .. string.format(", %svaargs", info == "ptr" and "&" or ""),
                                extras.no_return and RAYO_COSMICO or nonvoid and "return ret; " or ""
                            )
                        )
                        utils.fprintf(
                            io.stdout,
                            "Found va_equiv for func %s as func %s with pattern %s\n",
                            name,
                            va_equiv,
                            pattern
                        )
                    end
                end
            end
        end

        ::continue::
    end

    return self
end

function M:write()
    local c_out = self.c
        .. "\n\n"
        .. string.format("static struct %sFuncs {\n    ", self.name)
        .. utils.tbl_join(self.c_struct_defs, "\n    ")
        .. "\n} stub_funcs;\n\n"
        .. utils.tbl_join(self.c_lib_defs, "\n")
        .. "\n\n"
        .. string.format("void initialize_%s(void) {\n", self.name)
        .. utils.tbl_join(self.c_lib_init, "\n")
        .. "\n    "
        .. utils.tbl_join(self.c_struct_inst, "\n    ")
        .. "\n}\n\n"
        .. utils.tbl_join(self.c_func_impls, "\n")
        .. string.format("\n\nvoid close_%s(void) {\n    ", self.name)
        .. utils.tbl_join(self.c_lib_free, "\n    ")
        .. "\n}"

    local h_out = self.h
        .. string.format("\nvoid initialize_%s(void);", self.name)
        .. string.format("\nvoid close_%s(void);\n\n", self.name)
        .. utils.tbl_join(self.h_func_defs, "\n")

    utils.fprintf(io.stdout, "Writing %s_stub.c\n", self.name)
    utils.file_write(self.c_out_path, c_out)
    utils.fprintf(io.stdout, "Writing %s_stub.h\n", self.name)
    utils.file_write(self.h_out_path, h_out)
end

function M.new(stubs_root, stub_name)
    local stub = {}

    stub.parser = parser.new()
    stub.name = stub_name
    stub.dir = utils.path_combine(stubs_root, stub.name .. "-stub")

    -- Make main stub directory
    if not utils.file_exists(stub.dir) then
        assert(lfs.mkdir(stub.dir))
    end

    stub.c_out_path = utils.path_combine(stub.dir, stub.name .. "_stub.c")
    stub.h_out_path = utils.path_combine(stub.dir, stub.name .. "_stub.h")

    stub.h = ""
    stub.h_func_defs = {} -- Header function definitions
    stub.c = utils.tbl_join({
        string.format('#include "%s_stub.h"', stub_name),
        '#include "../stub.h"',
        "#include <stdbool.h>",
        "#include <stdio.h>",
        "#include <stdlib.h>",
        "",
        "#define _COMSO_SOURCE",
        "#include <libc/dlopen/dlfcn.h>",
    }, "\n")
    stub.c_lib_defs = {} -- Library variable definitions
    stub.c_lib_init = {} -- Library initialization code
    stub.c_lib_free = {} -- Free library handles
    stub.c_struct_defs = {} -- Function definitions
    stub.c_struct_inst = {} -- Store function pointers in the struct
    stub.c_func_impls = {} -- Function implementation that calls the pointer stored in the struct

    stub.current_shared_object = nil

    return setmetatable(stub, M)
end

return M
