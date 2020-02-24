#!/usr/bin/env luajit

local json = require "cjson"
local ins = require "inspect"

local stackshots = {}
local processid
local symcache = {}
local addrs = {}

function string:split(sep)
    local tokens = {}
    local pattern = string.format("([^%s]+)", sep or ':')
    self:gsub(pattern, function(c) table.insert(tokens, c) end)
    return tokens
end

local function test()
end

local function parse_atos(addr, line)
    local symbol
    local func, mod, offset = string.match(line, "(.*)%s+%(in%s+([^ ]+)%)%s+(.*)")
    if func and mod and offset then
        offset = offset:gsub("%s+", "") -- remove all spaces
        if string.match(func, "^0x") then
            symbol = func .. " " .. mod .. offset
        else
            symbol = mod .. "`" .. func .. offset
        end
    else
        symbol = addr
    end
    -- print(addr, symbol)
    return symbol
end

local function do_load_symbols(batch, symcache)
    if not next(batch) then
        return
    end

    local cmd = "atos -p " .. processid .. " " .. table.concat(batch, " ") .. " 2>/dev/null"
    -- print(cmd)

    local i = 0
    -- local f = io.popen(cmd)
    for line in io.popen(cmd):lines() do
        i = i + 1
        local addr = batch[i]
        local symbol = parse_atos(addr, line)
        symcache[addr] = symbol
    end
end

local BATCH_SIZE = 100
local function load_symbols(addrs, symcache)
    local n = 0
    local batch = {}
    for k, _ in pairs(addrs) do
        n = n + 1
        batch[n] = k

        if n > BATCH_SIZE then
            do_load_symbols(batch, symcache)

            n = 0
            batch = {}
        end
    end
    -- print('batch:', ins(batch))
    do_load_symbols(batch, symcache)
end

local function get_addr_symbol(addr)
    if symcache[addr] then
        return symcache[addr]
    else
        local cmd = "atos -p " .. processid .. " " .. addr .. " 2>/dev/null"
        -- print(cmd)
        local output = io.popen(cmd):read("*a")
        -- print('output:' .. output .. '.')
        local symbol = parse_atos(addr, output)
        symcache[addr] = symbol
        return symbol
    end
end

-- KC comes from KCData.py by AAPL, which parses the stackshot data from syscall
local function process_kcobjects(objs)
    for _, obj in ipairs(objs) do
        processid = processid or obj.kcdata_stackshot.stackshot_in_pid
        for _, process in pairs(obj.kcdata_stackshot.task_snapshots) do
            if process then
                local pid = process.task_snapshot.ts_pid
                if pid == processid then
                    for threadid, thread in pairs(process.thread_snapshots) do
                        if not stackshots[threadid] then
                            stackshots[threadid] = {}
                        end

                        local frames = {}
                        for i = #thread.user_stack_frames, 1, -1 do
                            local frame = string.format("%x", thread.user_stack_frames[i].lr)
                            if not addrs[frame] then
                                addrs[frame] = true
                            end
                            table.insert(frames, frame)
                        end

                        local stackshot = table.concat(frames,';')
                        -- print(stackshot)
                        stackshots[threadid][stackshot] = (stackshots[threadid][stackshot] or 0) + 1
                        -- print(threadid, ins(stackshots[threadid]))
                    end
                else
                    print("stackshots for process " .. pid .. " are ignored")
                end
            end
        end
    end
end

local function main()
    -- print("size:" .. #arg, ins(arg))
    if #arg ~= 1 then
        print("Usage: " .. arg[0] .. " <stackshot-file>")
        return 1
    end

    local workdir = string.match(arg[1], "^([^.]+)/")
    -- print("workdir:", workdir)
    for i, val in ipairs(arg) do
        print("file: " .. val)
        local f = assert(io.open(val))
        local jsondata = f:read("*a")
        process_kcobjects(json.decode(jsondata))
        f:close()
    end

    load_symbols(addrs, symcache)
    for threadid, shots in pairs(stackshots) do
        local filename = workdir .. "/" .. processid .. "t" .. threadid .. ".folded"
        local f = assert(io.open(filename, "w"))
        for stackshot, count in pairs(shots) do
            local symbols = {}
            local frames = string.split(stackshot, ';')
            for _, val in ipairs(frames) do
                table.insert(symbols, get_addr_symbol(val))
            end
            f:write(table.concat(symbols, ";") .. " " .. count .. "\n")
        end
        print("Wrote file " .. filename)
        f:close()
    end
end

if pcall(debug.getlocal, 4, 1) then
    return {
        test = test,
        main = main
    }
else
    main()
end
