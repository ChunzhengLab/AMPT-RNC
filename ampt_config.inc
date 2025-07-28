c     AMPT configuration file for conditional compilation
c     Include this file in Fortran sources that need ROOT interface
c
c     Conditional compilation macros:
c     ONLINE_ROOT - Enable online ROOT conversion
c
c     Usage in Fortran code:
c     #ifdef ONLINE_ROOT
c         call INIT_ONLINE_ROOT()
c     #endif

c     ROOT interface control flags
#ifdef ONLINE_ROOT
      logical, parameter :: IROOT_ENABLED = .true.
#else  
      logical, parameter :: IROOT_ENABLED = .false.
#endif