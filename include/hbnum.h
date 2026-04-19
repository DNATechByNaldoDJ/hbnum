/*
 _      _
| |__  | |__   _ __   _   _  _ __ ___
| '_ \ | '_ \ | '_ \ | | | || '_ ` _ \
| | | || |_) || | | || |_| || | | | | |
|_| |_||_.__/ |_| |_| \__,_||_| |_| |_|

hbnum: Released to Public Domain.
--------------------------------------------------------------------------------------

*/
#ifndef HBNUM_H

    #define HBNUM_H

    #include "hbapi.h"
    #include "hbapiitm.h"

    #define HBNUM_LIMB_BITS 30
    #define HBNUM_BASE      (( HB_U32 ) 1073741824UL)
    #define HBNUM_MASK      (( HB_U32 ) 1073741823UL)

    #define HBNUM_SIGN  "nSign"
    #define HBNUM_SCALE "nScale"
    #define HBNUM_USED  "nUsed"
    #define HBNUM_LIMBS "aLimbs"

    HB_FUNC( HBNUM_CORE_FROMSTRING );
    HB_FUNC( HBNUM_CORE_TOSTRING );
    HB_FUNC( HBNUM_CORE_CLONE );
    HB_FUNC( HBNUM_CORE_NORMALIZE );
    HB_FUNC( HBNUM_CORE_COMPARE );
    HB_FUNC( HBNUM_CORE_ADD );
    HB_FUNC( HBNUM_CORE_SUB );
    HB_FUNC( HBNUM_CORE_MUL );
    HB_FUNC( HBNUM_CORE_DIV );
    HB_FUNC( HBNUM_CORE_DIV_AUTO );
    HB_FUNC( HBNUM_CORE_MOD );
    HB_FUNC( HBNUM_CORE_POWINT );
    HB_FUNC( HBNUM_CORE_SQRT );
    HB_FUNC( HBNUM_CORE_SQRT_AUTO );
    HB_FUNC( HBNUM_CORE_NTHROOT );
    HB_FUNC( HBNUM_CORE_NTHROOT_AUTO );
    HB_FUNC( HBNUM_CORE_LOG );
    HB_FUNC( HBNUM_CORE_LOG_AUTO );
    HB_FUNC( HBNUM_CORE_LOG10 );
    HB_FUNC( HBNUM_CORE_LOG10_AUTO );
    HB_FUNC( HBNUM_CORE_LN );
    HB_FUNC( HBNUM_CORE_LN_AUTO );
    HB_FUNC( HBNUM_CORE_ROUND );
    HB_FUNC( HBNUM_CORE_TRUNC );
    HB_FUNC( HBNUM_CORE_FLOOR );
    HB_FUNC( HBNUM_CORE_CEILING );
    HB_FUNC( HBNUM_CORE_GCD );
    HB_FUNC( HBNUM_CORE_LCM );
    HB_FUNC( HBNUM_CORE_FACTORIAL );
    HB_FUNC( HBNUM_CORE_FI );
    HB_FUNC( HBNUM_CORE_MILLERRABIN );
    HB_FUNC( HBNUM_CORE_RANDOMIZE );
    HB_FUNC( HBNUM_CORE_ABS );
    HB_FUNC( HBNUM_CORE_NEG );
    HB_FUNC( HBNUM_CORE_ISZERO );
    HB_FUNC( HB_NUM_TEST_ADD );

#endif
