#!/usr/bin/env luajit

local ffi = require 'ffi'
local argparse = require "argparse"
local ins = require('inspect')


ffi.cdef [[
    // from kern/debug.h
    enum {
        STACKSHOT_GET_DQ                           = 0x01,
        STACKSHOT_SAVE_LOADINFO                    = 0x02,
        STACKSHOT_GET_GLOBAL_MEM_STATS             = 0x04,
        STACKSHOT_SAVE_KEXT_LOADINFO               = 0x08,
        STACKSHOT_GET_MICROSTACKSHOT               = 0x10,
        STACKSHOT_GLOBAL_MICROSTACKSHOT_ENABLE     = 0x20,
        STACKSHOT_GLOBAL_MICROSTACKSHOT_DISABLE    = 0x40,
        STACKSHOT_SET_MICROSTACKSHOT_MARK          = 0x80,
        STACKSHOT_ACTIVE_KERNEL_THREADS_ONLY       = 0x100,
        STACKSHOT_GET_BOOT_PROFILE                 = 0x200,
        STACKSHOT_SAVE_IMP_DONATION_PIDS           = 0x2000,
        STACKSHOT_SAVE_IN_KERNEL_BUFFER            = 0x4000,
        STACKSHOT_RETRIEVE_EXISTING_BUFFER         = 0x8000,
        STACKSHOT_KCDATA_FORMAT                    = 0x10000,
        STACKSHOT_ENABLE_BT_FAULTING               = 0x20000,
        STACKSHOT_COLLECT_DELTA_SNAPSHOT           = 0x40000,
    };
    
    enum {STACKSHOT_CONFIG_TYPE=1};

    typedef struct stackshot_config {
		/* Input options */
		int             sc_pid;                 /* PID to trace, or -1 for the entire system */
		uint32_t        sc_flags;               /* Stackshot flags */
		uint64_t        sc_delta_timestamp;     /* Retrieve a delta stackshot of system state that has changed since this time */
		
		/* Stackshot results */
		uint64_t        sc_buffer;              /* Pointer to stackshot buffer */
		uint32_t        sc_size;                /* Length of the stackshot buffer */
		
		/* Internals */ 
		uint64_t        sc_out_buffer_addr;     /* Location where the kernel should copy the address of the newly mapped buffer in user space */   
		uint64_t        sc_out_size_addr;       /* Location where the kernel should copy the size of the stackshot buffer */
    } stackshot_config_t;

    void    perror(const char *);
    int     syscall(int, ...);
    int	    getchar(void);

    int usleep(uint32_t microseconds);
    typedef struct timeval {
        long tv_sec;
        long tv_usec;
    } timeval;

    int gettimeofday(struct timeval* t, void* tzp);

    /* signal.h */
    typedef void (*sig_t) (int);
    sig_t signal(int sig, sig_t func);
    int32_t getpid(void);
    int unlink(const char *path);
]]

local SIGINT = 2
local SIG_ERR = -1

local C = ffi.C

local timeval = ffi.new("struct timeval")
local function gettimeofday()
    C.gettimeofday(timeval, nil)
    return tonumber(timeval.tv_sec) * 1000 + tonumber(timeval.tv_usec) / 1000
end

local function uint64(x)
    return ffi.cast("uint64_t", x)
end

local function get_stackshot(pid)
    local addr, len = ffi.new('void*[1]'), ffi.new('uint64_t[1]', 0)
    local st = ffi.new('stackshot_config_t', {pid, 0, 0, 0, 0, uint64(addr), uint64(len)})

    st.sc_flags = C.STACKSHOT_KCDATA_FORMAT + 
        C.STACKSHOT_GET_GLOBAL_MEM_STATS + 
        C.STACKSHOT_GET_DQ + 
        C.STACKSHOT_SAVE_LOADINFO +
        C.STACKSHOT_SAVE_KEXT_LOADINFO +
        C.STACKSHOT_SAVE_IMP_DONATION_PIDS
 
    -- print('stconf:', ins(stconf), ins(stconf.sc_out_buffer_addr), ins(stconf.sc_out_size_addr))
  
    local rc = C.syscall(491, uint64(C.STACKSHOT_CONFIG_TYPE), 
        uint64(ffi.cast("void *", st)), uint64(ffi.sizeof(st)));
	return rc, addr[0], len[0]
end

-- https://argparse.readthedocs.io/en/stable/arguments.html
local function parse_args()
    local parser = argparse("Stackshots", "Take stackshots of a process")
    parser:argument("pid", "the id of the process to be taken stackshots")
    parser:option("-f --freq", "how often to take stackshots (unit: hz, 100 max)", 50)
    parser:option("-t --time", "how long to take stackshots for (unit: second)", 10)
    parser:flag("-s --stop", "stop on entry (for attaching debuggers)", false)
    return parser:parse()
end

-- set when ctrl+break is pressed
local ctrlc = false
local pidfilename = 'stackshots.pid'

local function main()
    local args = parse_args()
    local f = tonumber(args.freq)
    args.interval = 1000 / (f and f < 50 and f or 50)

    local resultname = 'stackshots-' .. args.pid .. '.out'
    C.unlink(resultname)
    
    -- print('args:', ins(args))

    assert(SIG_ERR ~= C.signal(SIGINT, function() ctrlc = true end))

    if args.stop then
        print("Press a key to continue ...")
        C.getchar()
    end

    local pidfile = io.open(pidfilename, 'w')
    pidfile:write(C.getpid())
    pidfile:close()

    local filename = 'pid' .. args.pid .. '_' .. math.floor(gettimeofday()) .. '.stackshot'
    local file = io.open(filename, 'w')
    local stop_run = args.time * 1000 + gettimeofday()
    local count = 0
    repeat
        local start = gettimeofday()
        -- print(start)
        local rc, buf, len = get_stackshot(tonumber(args.pid))
        count = count + 1

        if rc < 0 then
            C.perror ("stack_snapshot");
            return 1
        end
        local result = ffi.string(buf, len)
        file:write(result)

        local ends = gettimeofday()
        local remain = args.interval - (ends - start)
        if remain > 0 and not ctrlc then
            C.usleep(remain * 1000)
        end
    until (ends > stop_run or ctrlc)
    file:close()
    C.unlink(pidfilename)

    io.open(resultname, 'w'):write(filename)

    print("\nWrote " .. count .. ' stackshots to ' .. filename)
end

main()