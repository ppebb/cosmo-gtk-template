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

local INIT_STRUCT_TEMPLATE = [[::NAME:: = calloc(1, sizeof(*::NAME::));
    *::NAME:: = (struct ::NAME::_syms) {
        // STORE_LIB
        // DLSYM_::NAME::_HERE
    };

    // INIT_STRUCT_HERE]]

local INIT_LIB_TEMPLATE = [[char* candidates_::NAME::[] = { ::CANDIDATES:: };
    void *::NAME::_lib_ptr = try_find_lib(candidates_::NAME::, LEN(candidates_::NAME::));

    if (!::NAME::_lib_ptr) {
        fprintf(stderr, "Unable to locate ::NAME::, exiting!");
        exit(1);
    }

    // INIT_LIB_HERE]]

local DEFINE_STRUCT_TEMPLATE = [[struct ::NAME::_syms {
    // STORE_LIB
    // SYMS_::NAME::_HERE
};

// DEFINE_STRUCT_HERE]]

local DEFINE_STRUCT_VAR_TEMPLATE = "extern struct ::NAME::_syms *::NAME::;\n// DEFINE_STRUCT_VAR_HERE"

function M:with_struct(name)
    assert(not self.has_split, "new structs cannot be added after splitting")

    self.current_struct = name

    local init = INIT_STRUCT_TEMPLATE:gsub("::NAME::", name)
    local define = DEFINE_STRUCT_TEMPLATE:gsub("::NAME::", name)
    local define_var = DEFINE_STRUCT_VAR_TEMPLATE:gsub("::NAME::", name)

    self.c = self.c:gsub("// INIT_STRUCT_HERE", init)
    self.c = self.c:gsub("// FREE_STRUCT", string.format("free(%s);\n    // FREE_STRUCT", name))
    self.c =
        self.c:gsub("// C_STRUCT_DEFINITION", string.format("struct %s_syms *%s;\n// C_STRUCT_DEFINITION", name, name))
    self.h = self.h:gsub("// DEFINE_STRUCT_HERE", define)
    self.h = self.h:gsub("// DEFINE_STRUCT_VAR_HERE", define_var)
    return self
end

function M:use_struct(name)
    self.current_struct = name

    if self.has_split then
        self.c_seek = utils.find_in_table_str(self.c_split, string.format("DLSYM_%s_HERE", name)) + 1
        self.h_seek = utils.find_in_table_str(self.h_split, string.format("SYMS_%s_HERE", name)) + 1
    end

    return self
end

function M:with_shared_object(name, candidates)
    assert(not self.has_split, "new shared objects cannot be added after splitting")
    assert(self.current_struct, "a struct must be added before a shared object")

    self.current_shared_object = name

    local init = INIT_LIB_TEMPLATE:gsub("::NAME::", name)
    init = init:gsub(
        "::CANDIDATES::",
        utils.tbl_join(utils.transform(candidates, function(_, v) return string.format('"%s"', v) end), ", ")
    )

    self.c = self.c:gsub("// INIT_LIB_HERE", init)
    self.c = self.c:gsub("// STORE_LIB", string.format(".lib_%s = %s_lib_ptr,\n        // STORE_LIB", name, name))
    self.h = self.h:gsub("// STORE_LIB", string.format("void *lib_%s;\n    // STORE_LIB", name))
    self.c = self.c:gsub(
        "// FREE_LIB",
        string.format("cosmo_dlclose(%s->lib_%s);\n    // FREE_LIB", self.current_struct, name)
    )

    return self
end

function M:use_shared_object(name)
    self.current_shared_object = name

    return self
end

function M:with_lib_headers(lib_headers)
    assert(not self.has_split, "new lib headers cannot be added after splitting")
    local joined =
        utils.tbl_join(utils.transform(lib_headers, function(_, v) return string.format("#include <%s>", v) end), "\n")

    self.h = self.h:gsub("::LIB_HEADERS::", joined)

    return self
end

function M:with_extra_headers(headers, dest)
    assert(not self.has_split, "new extra headers cannot be added after splitting")

    for _, header in ipairs(headers) do
        copy_headers(self.name, header, utils.path_combine(dest, utils.fname(header)))
    end

    return self
end

function M:split()
    self.has_split = true

    self.c_split = utils.split(self.c, "\n")
    self.h_split = utils.split(self.h, "\n")

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
            local funcs = parser.process_header(header, self.match_access, self.prefix, self.trim_prefix)

            if not funcs then
                goto continue
            end

            for _, func in ipairs(funcs) do
                local ret = func.ret
                local name = func.name
                local args = func.args

                local c_line = string.format(
                    '        .%s = try_find_sym(%s, "%s"),',
                    name,
                    self.current_shared_object .. "_lib_ptr",
                    name
                )

                local h_line = string.format("    %s (*%s)(%s);", ret, name, args)

                table.insert(self.c_split, self.c_seek, c_line)
                table.insert(self.h_split, self.h_seek, h_line)

                self.c_seek = self.c_seek + 1
                self.h_seek = self.h_seek + 1
            end
        end

        ::continue::
    end

    return self
end

function M:write()
    local c_out = self.has_split and utils.tbl_join(self.c_split, "\n") or self.c
    local h_out = self.has_split and utils.tbl_join(self.h_split, "\n") or self.h

    utils.fprintf(io.stdout, "Writing %s_stub.c\n", self.name)
    utils.file_write(self.c_out_path, c_out)
    utils.fprintf(io.stdout, "Writing %s_stub.h\n", self.name)
    utils.file_write(self.h_out_path, h_out)
end

function M.new(stubs_root, stub_name)
    local stub = {}

    -- Read in templates
    local stub_c_path = utils.path_combine(stubs_root, "stub.c-template")
    local stub_h_path = utils.path_combine(stubs_root, "stub.h-template")
    local stub_c, err_c = utils.file_read(stub_c_path)
    local stub_h, err_h = utils.file_read(stub_h_path)

    if not stub_c or not stub_h then
        utils.fprintf(io.stderr, "Unable to read stub.c-template or stub.h-template, error: %s\n", err_c or err_h)
        os.exit(1, true)
    end

    stub.name = stub_name
    stub.dir = utils.path_combine(stubs_root, stub.name .. "-stub")

    -- Make main stub directory
    if not utils.file_exists(stub.dir) then
        assert(lfs.mkdir(stub.dir))
    end

    stub.c = stub_c
    stub.h = stub_h
    stub.c_split = nil
    stub.h_split = nil
    stub.c_out_path = utils.path_combine(stub.dir, stub.name .. "_stub.c")
    stub.h_out_path = utils.path_combine(stub.dir, stub.name .. "_stub.h")
    stub.c_seek = 0
    stub.h_seek = 0

    stub.c = stub.c:gsub("::STUB_NAME::", stub_name)
    stub.c = stub.c:gsub("::STUB_HEADER::", string.format('#include "%s_stub.h"', stub_name))

    stub.h = stub.h:gsub("::STUB_NAME::", stub_name)
    stub.h = stub.h:gsub("::STUB_NAME_UPPER::", stub_name:upper())

    stub.current_struct = nil
    stub.current_shared_object = nil

    return setmetatable(stub, M)
end

return M
