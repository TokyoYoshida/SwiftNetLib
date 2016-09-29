#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif
/*****************************************************************************

  FILE NAME   : thread_test.c

  PROJECT     : 

  DESCRIPTION : A first thread program is to print out 'Hello World'.

  ----------------------------------------------------------------------------
  RELEASE NOTE : 

   DATE          REV    REMARK
  ============= ====== =======================================================


 *****************************************************************************/

//#include <stdlib.h>
//#include <stdio.h>
//#include <string.h>
//
//#include <semaphore.h>
//#include <pthread.h>
//import SwiftGlibc



//
///* --------------------------------- DEFS ---------------------------------- */
//
struct Thdata {
    var letter :String
    var th     :pthread_t?
    var sync   :UnsafeMutablePointer<sem_t>
    var start  :UnsafeMutablePointer<sem_t>
}

/* ------------------------------------------------------------------------- */



/* ------------------------------- FUNCTIONS ------------------------------- */


/*****************************************************************************

 FUNCTION    : void *thread_function (void *thdata)

 DESCRIPTION : Thread function.

               * Argument
                 void *

               * Return
                 void *

 ATTENTION   :

 *****************************************************************************/
let thread_function: @convention(c)(UnsafeMutablePointer<Void>) -> UnsafeMutablePointer<Void>? = { thdata in
    var priv = UnsafeMutablePointer<Thdata>(thdata)!.pointee

//    /* sync */
    sem_post(priv.sync)
    sem_wait(priv.start)
//
//    /* write my letter */
    for _ in 0...100{
    print(priv.letter, terminator: "")
    }
//
//    /* sync */
    sem_post(priv.sync)
    /* done */
    return nil

}


/* Main 

 *****************************************************************************/
func thread() -> Int32
{

    var                 rtn:CInt = 0
    var hello = "Hello World!"
    let count = hello.characters.count
//    let th =
//    let th2 = th
////    th.th?.pointee.__sig = 100
//    print(th.th?.pointee.__sig)
//    print(th2.th?.pointee.__sig)
//    print("ok")
    var dummy_sem = sem_t()
    var thdat = Array<Thdata>(repeating:Thdata(letter:"", th:pthread_t(nil), sync:&dummy_sem, start:&dummy_sem)
, count: count)

    /* initialize thread data */

    var i = 0
    hello.characters.forEach {
        thdat[i].letter = String($0)
//        if sem_open(&thdat[i].sync, 0, 0) == -1{
//            print("semaphore error!\(errno)")
//            if errno == POSIXError.ENOSYS.rawValue {
////                print ("its ENOSYS")
////            }
//        }
//        sem_init(&thdat[i].start, 0, 0)
        let semaphoreNameSync = "/syncx\(i)"
        let _sync = sem_open(semaphoreNameSync, O_CREAT, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH, 1)
        if _sync == SEM_FAILED {
            print("semaphre error")
        }
        thdat[i].sync  = _sync!
        let semaphoreNameStart = "/startx\(i)"
        let _start = sem_open(semaphoreNameStart, O_CREAT, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH, 1)
        if _start == SEM_FAILED {
            print("semaphre error\(errno)")
        }
        thdat[i].start  = _start!
        rtn = pthread_create(&thdat[i].th, nil, thread_function, &thdat[i])
        if (rtn != 0) {
            print("error")
//            fprintf(stderr, "pthread_create() #%0d failed for %d.", i, rtn)
//            return EXIT_FAILURE
        }
        i += 1
    }


//    /* synchronization */
    i = 0
    hello.characters.forEach { _ in
        sem_wait(thdat[i].sync)
        i += 1
    }
//    /* let thread write his letter */
    i = 0
    hello.characters.forEach { _ in
        sem_post(thdat[i].start)
        sem_wait(thdat[i].sync)
        i += 1
    }
//
//    /* join */
    i = 0
    hello.characters.forEach { _ in
        pthread_join(thdat[i].th!, nil)
        sem_close(thdat[i].sync)
        sem_close(thdat[i].start)
        i += 1
    }

    
//    free(thdat)
//    exit(EXIT_SUCCESS)
    return EXIT_SUCCESS
}
