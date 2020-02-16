#!/usr/bin/env luajit

local json = require 'cjson'
local ins = require 'inspect'

local stackshots = {}
local processid

-- KC comes from KCData.py by AAPL, which parses the stackshot data from syscall
local function process_kcobjects(objs)
    for _, obj in ipairs(objs) do
        -- take care of the first process only
        local procid, process = next(obj.kcdata_stackshot.task_snapshots)
        if (not processid or processid == procid) and process then
            processid = procid
            for threadid, thread in pairs(process.thread_snapshots) do
                local frames = {}
                for i = #thread.user_stack_frames, 1, -1 do
                    table.insert(frames, thread.user_stack_frames[i].lr)
                end
                print('frames:', ins(frames))
                local stackshot = table.concat(frames, ';')
                if not stackshots[threadid] then stackshots[threadid] = {} end
                stackshots[threadid][stackshot] = (stackshots[threadid][stackshot] or 0) + 1
            end
        else
            print("stackshots for process " .. procid .. " are ignored")
        end
    end

end

local function main()

    for i, val in ipairs(arg) do
        print(val)
        local f = io.open(val)
        local jsondata = f:read('*a')
        process_kcobjects(json.decode(jsondata))
        f:close()
    end

    for threadid, shots in pairs(stackshots) do
        local filename = './' .. processid .. 't' .. threadid .. '.folded'
        local f = io.open(filename, 'w')
        for stackshot, count in pairs(shots) do
            f:write(stackshot .. ' ' .. count .. '\n')
        end
        print('Wrote file ' .. filename)
        f:close()
    end
end

main()