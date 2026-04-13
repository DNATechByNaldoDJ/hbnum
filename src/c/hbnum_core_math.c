/*
 _      _
| |__  | |__   _ __   _   _  _ __ ___
| '_ \ | '_ \ | '_ \ | | | || '_ ` _ \
| | | || |_) || | | || |_| || | | | | |
|_| |_||_.__/ |_| |_| \__,_||_| |_| |_|

hbnum: Released to Public Domain.
--------------------------------------------------------------------------------------

*/

#include "hbapi.h"
#include "hbapierr.h"

#include "hbnum_native_internal.h"

static void hbnum_native_set_one( HBNumNative * pNum )
{
   hbnum_native_init( pNum );
   pNum->sign = 1;
   pNum->scale = 0;
   pNum->used = 1;
   pNum->limbs = ( HB_U32 * ) hb_xgrab( sizeof( HB_U32 ) );
   pNum->limbs[ 0 ] = 1;
}

HB_FUNC( HBNUM_CORE_MOD )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   PHB_ITEM pB = hb_param( 2, HB_IT_HASH );
   HBNumNative nA;
   HBNumNative nB;
   HBNumNative nQ;
   HBNumNative nQB;
   HBNumNative nR;
   PHB_ITEM pHashResult;
   HB_BOOL fOk;

   hbnum_native_init( &nA );
   hbnum_native_init( &nB );
   hbnum_native_init( &nQ );
   hbnum_native_init( &nQB );
   hbnum_native_init( &nR );

   hbnum_native_from_hash( pA, &nA );
   hbnum_native_from_hash( pB, &nB );

   fOk = hbnum_native_div( &nA, &nB, 0, &nQ );
   if( !fOk )
   {
      hb_errRT_BASE( EG_ZERODIV, 0, "Division by zero", HB_ERR_FUNCNAME, 0 );
   }
   else
   {
      hbnum_native_mul( &nQ, &nB, &nQB );
      hbnum_native_sub( &nA, &nQB, &nR );
      hbnum_native_normalize( &nR );
   }

   pHashResult = hbnum_native_to_hash( &nR );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nA );
   hbnum_native_release( &nB );
   hbnum_native_release( &nQ );
   hbnum_native_release( &nQB );
   hbnum_native_release( &nR );
}

HB_FUNC( HBNUM_CORE_POWINT )
{
   PHB_ITEM pBaseHash = hb_param( 1, HB_IT_HASH );
   HB_MAXINT nExp = hb_parnint( 2 );
   HBNumNative nBase;
   HBNumNative nAcc;
   HBNumNative nPow;
   HBNumNative nTmp;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nBase );
   hbnum_native_init( &nAcc );
   hbnum_native_init( &nPow );
   hbnum_native_init( &nTmp );

   hbnum_native_from_hash( pBaseHash, &nBase );

   if( nExp < 0 )
   {
      hb_errRT_BASE( EG_ARG, 0, "PowInt exponent must be >= 0", HB_ERR_FUNCNAME, 0 );
      pHashResult = hbnum_native_to_hash( &nAcc );
      hb_itemReturnRelease( pHashResult );

      hbnum_native_release( &nBase );
      hbnum_native_release( &nAcc );
      hbnum_native_release( &nPow );
      hbnum_native_release( &nTmp );
      return;
   }

   hbnum_native_set_one( &nAcc );
   hbnum_native_clone( &nBase, &nPow );

   while( nExp > 0 )
   {
      if( ( nExp & 1 ) != 0 )
      {
         hbnum_native_mul( &nAcc, &nPow, &nTmp );
         hbnum_native_release( &nAcc );
         nAcc = nTmp;
         hbnum_native_init( &nTmp );
      }

      nExp >>= 1;

      if( nExp > 0 )
      {
         hbnum_native_mul( &nPow, &nPow, &nTmp );
         hbnum_native_release( &nPow );
         nPow = nTmp;
         hbnum_native_init( &nTmp );
      }
   }

   hbnum_native_normalize( &nAcc );
   pHashResult = hbnum_native_to_hash( &nAcc );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nBase );
   hbnum_native_release( &nAcc );
   hbnum_native_release( &nPow );
   hbnum_native_release( &nTmp );
}
