#!/usr/bin/env luajit

local json = require 'cjson'
local ins = require 'inspect'

local stackshots = {}
local processid
local symcache = {}
local addrs = {}

local compare_mt = {__eq = function(lhs, rhs)
    print(lhs, rhs)
    if #lhs ~= #rhs then return false end
    for i = 1, #lhs do
        if lhs[i] ~= rhs[i] then return false end
    end
    return true
end}

local deep_cmp_table = setmetatable({}, {
    __call = function(...)
        return setmetatable({select(2, ...)}, compare_mt)
    end
})

local function test()
    local t1 = deep_cmp_table(1,2,3)
    local t2 = deep_cmp_table(1,2)
    print(ins(t1), ins(t2))
    print(t1 == t2)
    table.insert(t2, 3)
    print(t1 == t2)
end

local function parse_atos(addr, line)
    local symbol
    local func, mod, offset = string.match(line, "(.*)%s+%(in%s+([^ ]+)%)%s+(.*)")
    if func and mod and offset then
        if string.match(func, '^0x') then
            symbol = func .. ' ' .. mod .. offset
        else
            symbol = mod .. '`' .. func .. offset
        end
    else 
        symbol = addr
    end
    print(addr, symbol)
    return symbol
end

local function do_load_symbols(batch, symcache)
    if not next(batch) then return end

    local cmd = 'atos -p ' .. processid .. ' ' .. table.concat(batch, ' ') .. ' 2>/dev/null'
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
        local cmd = 'atos -p ' .. processid .. ' ' .. addr .. ' 2>/dev/null'
        -- print(cmd)
        local output = io.popen(cmd):read('*a')
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
                        if not stackshots[threadid] then stackshots[threadid] = {} end

                        local frames = deep_cmp_table()
                        for i = #thread.user_stack_frames, 1, -1 do
                            local frame = string.format("%x", thread.user_stack_frames[i].lr)
                            if not addrs[frame] then
                                addrs[frame] = true
                                -- print(frame)
                            end
                            table.insert(frames, frame)
                        end

                        stackshots[threadid][frames] = (stackshots[threadid][frames] or 0) + 1
                    end
                else
                    print("stackshots for process " .. pid .. " are ignored")
                end
            end
        end
    end

end

local function main()
    print('size:' .. #arg, ins(arg))
    if #arg ~= 1 then
        print('Usage: ' .. arg[0] .. ' <stackshot-file>')
        return 1
    end

    local workdir = string.match(arg[1], '^([^.]+)/')
    print('workdir:', workdir)
    for i, val in ipairs(arg) do
        print('file:', val)
        local f = assert(io.open(val))
        local jsondata = f:read('*a')
        process_kcobjects(json.decode(jsondata))
        f:close()
    end

    load_symbols(addrs, symcache)
    for threadid, shots in pairs(stackshots) do
        local filename = workdir .. '/' .. processid .. 't' .. threadid .. '.folded'
        local f = assert(io.open(filename, 'w'))
        for stackshot, count in pairs(shots) do
            local symbols = {}
            for _, val in ipairs(stackshot) do
                table.insert(symbols, get_addr_symbol(val))
            end
            f:write(table.concat(symbols, ';') .. ' ' .. count .. '\n')
        end
        print('Wrote file ' .. filename)
        f:close()
    end
end

main()
-- test()