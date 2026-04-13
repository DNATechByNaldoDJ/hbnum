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

static HB_BOOL hbnum_native_is_integer( const HBNumNative * pNum )
{
   return pNum->scale == 0;
}

static void hbnum_native_abs_clone( const HBNumNative * pSrc, HBNumNative * pDst )
{
   hbnum_native_clone( pSrc, pDst );
   pDst->sign = pDst->used > 0 ? 1 : 0;
}

static HB_BOOL hbnum_native_mod_int( const HBNumNative * pA, const HBNumNative * pB, HBNumNative * pResult )
{
   HBNumNative nQ;
   HBNumNative nQB;
   HB_BOOL fOk;

   hbnum_native_init( &nQ );
   hbnum_native_init( &nQB );
   hbnum_native_init( pResult );

   fOk = hbnum_native_div( pA, pB, 0, &nQ );
   if( !fOk )
   {
      hbnum_native_release( &nQ );
      hbnum_native_release( &nQB );
      return HB_FALSE;
   }

   hbnum_native_mul( &nQ, pB, &nQB );
   hbnum_native_sub( pA, &nQB, pResult );
   hbnum_native_normalize( pResult );

   hbnum_native_release( &nQ );
   hbnum_native_release( &nQB );
   return HB_TRUE;
}

static HB_BOOL hbnum_native_gcd_int( const HBNumNative * pA, const HBNumNative * pB, HBNumNative * pResult )
{
   HBNumNative nX;
   HBNumNative nY;
   HBNumNative nR;

   hbnum_native_init( pResult );
   hbnum_native_init( &nX );
   hbnum_native_init( &nY );
   hbnum_native_init( &nR );

   hbnum_native_abs_clone( pA, &nX );
   hbnum_native_abs_clone( pB, &nY );

   if( nX.used == 0 )
   {
      hbnum_native_clone( &nY, pResult );
      hbnum_native_release( &nX );
      hbnum_native_release( &nY );
      hbnum_native_release( &nR );
      return HB_TRUE;
   }

   if( nY.used == 0 )
   {
      hbnum_native_clone( &nX, pResult );
      hbnum_native_release( &nX );
      hbnum_native_release( &nY );
      hbnum_native_release( &nR );
      return HB_TRUE;
   }

   while( nY.used > 0 )
   {
      hbnum_native_mod_int( &nX, &nY, &nR );
      hbnum_native_release( &nX );
      hbnum_native_clone( &nY, &nX );
      hbnum_native_release( &nY );
      hbnum_native_clone( &nR, &nY );
      hbnum_native_release( &nR );
      hbnum_native_init( &nR );
   }

   hbnum_native_clone( &nX, pResult );
   hbnum_native_normalize( pResult );
   if( pResult->used > 0 )
      pResult->sign = 1;

   hbnum_native_release( &nX );
   hbnum_native_release( &nY );
   hbnum_native_release( &nR );
   return HB_TRUE;
}

static HB_BOOL hbnum_native_lcm_int( const HBNumNative * pA, const HBNumNative * pB, HBNumNative * pResult )
{
   HBNumNative nAbsA;
   HBNumNative nAbsB;
   HBNumNative nG;
   HBNumNative nQ;
   HBNumNative nL;

   hbnum_native_init( pResult );
   hbnum_native_init( &nAbsA );
   hbnum_native_init( &nAbsB );
   hbnum_native_init( &nG );
   hbnum_native_init( &nQ );
   hbnum_native_init( &nL );

   hbnum_native_abs_clone( pA, &nAbsA );
   hbnum_native_abs_clone( pB, &nAbsB );

   if( nAbsA.used == 0 || nAbsB.used == 0 )
   {
      hbnum_native_release( &nAbsA );
      hbnum_native_release( &nAbsB );
      hbnum_native_release( &nG );
      hbnum_native_release( &nQ );
      hbnum_native_release( &nL );
      return HB_TRUE;
   }

   hbnum_native_gcd_int( &nAbsA, &nAbsB, &nG );
   hbnum_native_div( &nAbsA, &nG, 0, &nQ );
   hbnum_native_mul( &nQ, &nAbsB, &nL );
   hbnum_native_normalize( &nL );
   if( nL.used > 0 )
      nL.sign = 1;

   hbnum_native_clone( &nL, pResult );

   hbnum_native_release( &nAbsA );
   hbnum_native_release( &nAbsB );
   hbnum_native_release( &nG );
   hbnum_native_release( &nQ );
   hbnum_native_release( &nL );
   return HB_TRUE;
}

HB_FUNC( HBNUM_CORE_GCD )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   PHB_ITEM pB = hb_param( 2, HB_IT_HASH );
   HBNumNative nA;
   HBNumNative nB;
   HBNumNative nResult;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nA );
   hbnum_native_init( &nB );
   hbnum_native_init( &nResult );

   hbnum_native_from_hash( pA, &nA );
   hbnum_native_from_hash( pB, &nB );

   if( !hbnum_native_is_integer( &nA ) || !hbnum_native_is_integer( &nB ) )
   {
      hbnum_native_release( &nA );
      hbnum_native_release( &nB );
      hbnum_native_release( &nResult );
      hb_errRT_BASE( EG_ARG, 0, "GCD requires integer operands (scale = 0)", HB_ERR_FUNCNAME, 0 );
      return;
   }

   hbnum_native_gcd_int( &nA, &nB, &nResult );
   pHashResult = hbnum_native_to_hash( &nResult );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nA );
   hbnum_native_release( &nB );
   hbnum_native_release( &nResult );
}

HB_FUNC( HBNUM_CORE_LCM )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   PHB_ITEM pB = hb_param( 2, HB_IT_HASH );
   HBNumNative nA;
   HBNumNative nB;
   HBNumNative nResult;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nA );
   hbnum_native_init( &nB );
   hbnum_native_init( &nResult );

   hbnum_native_from_hash( pA, &nA );
   hbnum_native_from_hash( pB, &nB );

   if( !hbnum_native_is_integer( &nA ) || !hbnum_native_is_integer( &nB ) )
   {
      hbnum_native_release( &nA );
      hbnum_native_release( &nB );
      hbnum_native_release( &nResult );
      hb_errRT_BASE( EG_ARG, 0, "LCM requires integer operands (scale = 0)", HB_ERR_FUNCNAME, 0 );
      return;
   }

   hbnum_native_lcm_int( &nA, &nB, &nResult );
   pHashResult = hbnum_native_to_hash( &nResult );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nA );
   hbnum_native_release( &nB );
   hbnum_native_release( &nResult );
}
