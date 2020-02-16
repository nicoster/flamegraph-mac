//usr/bin/make "${0%.*}" -f <(echo "LDFLAGS=-g") && ./"${0%.*}" "$@"; exit $? 

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <kern/kcdata.h> // for the KCData format
#include <time.h>
#include <unistd.h>
#include <uuid/uuid.h>

useconds_t
/**
 * Stackshot for 10.11/9 (XNU 32xx) and later:
 *
 * Uses the new (and still undocumented) syscall #491 in place of #365 which
 * has been removed.
 *
 * Obviously requires root access to run. Provides full stack traces - both
 * kernel and user - of all threads in the system.
 *
 * Compiles cleanly for iOS and MacOS, so I'm leaving it as source rather
 * than provide a binary.
 *
 *
 * (AAPL will likely slap an entitlement on this in MacOS 13/iOS 11 anyway..
 * Use/copy freely while you can - but a little acknowledgment wouldn't hurt :-)
 *   
 * The full explanation of how to use this is in MOXiI Vol. I (debugging)
 * The full explanation of how it works (kernel-side, pretty darn ingenious)
 *   is in MOXiI Vol. II
 *
 * So stay tuned. More coming.
 *
 * Jonathan Levin, 11/01/2016
 *
 */

// As with the previous version, we have to rip the typedefs and structs from the kernel
// headers, as they are "private" and not exported...

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
	// and there's more, but I don't use them..
};

#define STACKSHOT_CONFIG_TYPE 1

// As well as the definition of the system call itself, which is a wrapper over the generic syscall(2)

int stack_snapshot_with_config(int stackshot_config_version, stackshot_config_t *stackshot_config, uint32_t stackshot_config_size) {

  // AAPL "deprecates" syscall(2) in 10.12. And I say, if you deprecate it, at least expose the 
  // syscall header to user mode! 
  return (syscall (491, stackshot_config_version, (uint64_t) stackshot_config, stackshot_config_size));

}




// Convenience function hiding the implementation - in case AAPL changes it yet again
int get_stackshot (pid_t Pid, char **Addr, uint64_t *Size, uint64_t Flags)
{

	stackshot_config_t	stconf = { 0 };
	stconf.sc_pid =  Pid;  
	stconf.sc_buffer = 0; // buf;
	stconf.sc_size   =  0; // 4096;
	stconf.sc_flags  = STACKSHOT_KCDATA_FORMAT | Flags;
 
	stconf.sc_out_buffer_addr = (uint64_t) Addr;  
	stconf.sc_out_size_addr =  (uint64_t) Size;
  
  	return (syscall (491, STACKSHOT_CONFIG_TYPE, (uint64_t) &stconf, sizeof(stconf)));
} // get_stackshot

int main (int argc, char **argv)
{

	char *addr;
	uint64_t size;
	int pid = -1;
    int freq = 99;
    int t = 1;

	printf("Press a key to continue ...\n");
	getchar();
	printf("Cool. Let's go\n");

	printf("sizeof stackshot_config:%d\n", sizeof(struct stackshot_config));

	// Sorry , people. Stackshot requires root privileges :-|

	// if (geteuid())  {
	// 	fprintf(stderr,"You're wasting my time, little man. Come back as root.\n");
	// 	exit(1);
	// }

	if (argc >= 2) pid = atoi(argv[1]);
    if (argc >= 3) freq = atoi(argv[2]);
    if (argc >= 4) t = atoi(argv[3]);

	int Flags = STACKSHOT_GET_GLOBAL_MEM_STATS | STACKSHOT_GET_DQ  | STACKSHOT_SAVE_LOADINFO | STACKSHOT_SAVE_KEXT_LOADINFO | STACKSHOT_SAVE_IMP_DONATION_PIDS;
   

	int rc = get_stackshot (pid, &addr, &size, Flags);


	if (rc < 0)  { 	
	perror ("stack_snapshot_with_config");
	exit(1);
		}

   // If you want the buffer for hexdumping, etc:
   fprintf(stderr,"RC: %d - Got %d bytes in %p\n", rc, size, addr);
   write (1, addr, size);

	return 0;

}


// typedef struct {
//      int a, b;
//      double d;
// } structparm;
// structparm s;
// int e, f, g, h, i, j, k; long double ld;
// double m, n;
// __m256 y; 
// extern void func (int e, int f,
//     structparm s, int g, int h,
//     long double ld, double m, __m256 y,
// 	double n, int i, int j, int k); 
// func (e, f, s, g, h, ld, m, y, n, i, j, k);