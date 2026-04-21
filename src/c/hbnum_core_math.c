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

#include <string.h>

#include "hbnum_native_internal.h"

#define HBNUM_ROOT_GUARD_DIGITS   8
#define HBNUM_LOG_GUARD_DIGITS    8
#define HBNUM_MAX_ROOT_ITERATIONS 128
#define HBNUM_MAX_LOG_STEPS       256
#define HBNUM_MAX_E_TERMS         2048

static void hbnum_native_set_small( HB_MAXINT nValue, HBNumNative * pNum )
{
   HB_MAXUINT nWork;
   HB_SIZE nCap;
   HB_SIZE nUsed;

   hbnum_native_init( pNum );

   if( nValue == 0 )
      return;

   pNum->sign = nValue < 0 ? -1 : 1;
   pNum->scale = 0;

   nWork = ( HB_MAXUINT ) ( nValue < 0 ? -nValue : nValue );
   nCap = 0;

   do
   {
      ++nCap;
      nWork /= HBNUM_BASE;
   }
   while( nWork > 0 );

   pNum->limbs = ( HB_U32 * ) hb_xgrab( sizeof( HB_U32 ) * nCap );
   nUsed = 0;
   nWork = ( HB_MAXUINT ) ( nValue < 0 ? -nValue : nValue );

   while( nWork > 0 )
   {
      pNum->limbs[ nUsed++ ] = ( HB_U32 ) ( nWork % HBNUM_BASE );
      nWork /= HBNUM_BASE;
   }

   pNum->used = nUsed;
   hbnum_native_normalize( pNum );
}

static void hbnum_native_set_one( HBNumNative * pNum )
{
   hbnum_native_set_small( 1, pNum );
}

static HB_BOOL hbnum_native_is_integer( const HBNumNative * pNum )
{
   return pNum->used == 0 || pNum->scale == 0;
}

static void hbnum_native_abs_clone( const HBNumNative * pSrc, HBNumNative * pDst )
{
   hbnum_native_clone( pSrc, pDst );
   if( pDst->used > 0 )
      pDst->sign = 1;
}

static void hbnum_native_replace( HBNumNative * pDst, HBNumNative * pSrc )
{
   hbnum_native_release( pDst );
   *pDst = *pSrc;
   hbnum_native_init( pSrc );
}

static HB_BOOL hbnum_native_is_one_value( const HBNumNative * pNum )
{
   HBNumNative nOne;
   int nCmp;

   hbnum_native_init( &nOne );
   hbnum_native_set_one( &nOne );
   nCmp = hbnum_native_compare( pNum, &nOne );
   hbnum_native_release( &nOne );

   return nCmp == 0;
}

static HB_BOOL hbnum_native_is_zero_value( const HBNumNative * pNum )
{
   return pNum->used == 0;
}

static HB_BOOL hbnum_native_to_small_int( const HBNumNative * pNum, HB_MAXINT * pnValue )
{
   char * szText;
   const char * szPos;
   HB_MAXINT nValue;
   int iSign;

   if( ! hbnum_native_is_integer( pNum ) )
      return HB_FALSE;

   szText = hbnum_native_to_string( pNum );
   szPos = szText;
   iSign = 1;
   nValue = 0;

   if( *szPos == '-' )
   {
      iSign = -1;
      ++szPos;
   }

   if( *szPos == '\0' )
   {
      hb_xfree( szText );
      return HB_FALSE;
   }

   while( *szPos != '\0' )
   {
      if( *szPos < '0' || *szPos > '9' )
      {
         hb_xfree( szText );
         return HB_FALSE;
      }

      nValue = nValue * 10 + ( HB_MAXINT ) ( *szPos - '0' );
      ++szPos;
   }

   hb_xfree( szText );
   *pnValue = iSign < 0 ? -nValue : nValue;
   return HB_TRUE;
}

static HB_MAXUINT hbnum_native_abs_maxuint( HB_MAXINT nValue )
{
   return ( HB_MAXUINT ) ( nValue < 0 ? -nValue : nValue );
}

static HB_MAXUINT hbnum_native_gcd_maxuint( HB_MAXUINT nA, HB_MAXUINT nB )
{
   HB_MAXUINT nTmp;

   while( nB != 0 )
   {
      nTmp = nA % nB;
      nA = nB;
      nB = nTmp;
   }

   return nA;
}

static HB_BOOL hbnum_native_div_terminating_ratio( HB_MAXINT nNumerator, HB_MAXINT nDenominator, HBNumNative * pResult )
{
   HB_MAXUINT nNumAbs;
   HB_MAXUINT nDenAbs;
   HB_MAXUINT nGcd;
   HB_SIZE nPow2;
   HB_SIZE nPow5;
   HB_SIZE nPrecision;
   HBNumNative nNum;
   HBNumNative nDen;
   HB_BOOL fOk;

   hbnum_native_init( pResult );

   if( nDenominator == 0 )
      return HB_FALSE;

   if( nNumerator == 0 )
      return HB_TRUE;

   nNumAbs = hbnum_native_abs_maxuint( nNumerator );
   nDenAbs = hbnum_native_abs_maxuint( nDenominator );
   nGcd = hbnum_native_gcd_maxuint( nNumAbs, nDenAbs );

   if( nGcd > 1 )
   {
      nNumAbs /= nGcd;
      nDenAbs /= nGcd;
   }

   nPow2 = 0;
   nPow5 = 0;

   while( ( nDenAbs % 2 ) == 0 )
   {
      nDenAbs /= 2;
      ++nPow2;
   }

   while( ( nDenAbs % 5 ) == 0 )
   {
      nDenAbs /= 5;
      ++nPow5;
   }

   if( nDenAbs != 1 )
      return HB_FALSE;

   nPrecision = nPow2 > nPow5 ? nPow2 : nPow5;

   hbnum_native_init( &nNum );
   hbnum_native_init( &nDen );

   hbnum_native_set_small( nNumerator < 0 ? -( HB_MAXINT ) nNumAbs : ( HB_MAXINT ) nNumAbs, &nNum );
   hbnum_native_set_small( ( HB_MAXINT ) ( hbnum_native_abs_maxuint( nDenominator ) / nGcd ), &nDen );
   fOk = hbnum_native_div( &nNum, &nDen, nPrecision, pResult );

   hbnum_native_release( &nNum );
   hbnum_native_release( &nDen );
   return fOk;
}

static HB_BOOL hbnum_native_pow_int_nonneg( const HBNumNative * pBase, HB_SIZE nExp, HBNumNative * pResult )
{
   HBNumNative nAcc;
   HBNumNative nPow;
   HBNumNative nTmp;

   hbnum_native_init( pResult );
   hbnum_native_init( &nAcc );
   hbnum_native_init( &nPow );
   hbnum_native_init( &nTmp );

   hbnum_native_set_one( &nAcc );
   hbnum_native_clone( pBase, &nPow );

   while( nExp > 0 )
   {
      if( ( nExp & 1 ) != 0 )
      {
         hbnum_native_mul( &nAcc, &nPow, &nTmp );
         hbnum_native_replace( &nAcc, &nTmp );
      }

      nExp >>= 1;

      if( nExp > 0 )
      {
         hbnum_native_mul( &nPow, &nPow, &nTmp );
         hbnum_native_replace( &nPow, &nTmp );
      }
   }

   hbnum_native_clone( &nAcc, pResult );

   hbnum_native_release( &nAcc );
   hbnum_native_release( &nPow );
   hbnum_native_release( &nTmp );
   return HB_TRUE;
}

static HB_BOOL hbnum_native_set_power_of_ten( HB_SIZE nExp, HBNumNative * pNum )
{
   HBNumNative nTen;

   hbnum_native_init( &nTen );
   hbnum_native_init( pNum );
   hbnum_native_set_small( 10, &nTen );
   hbnum_native_pow_int_nonneg( &nTen, nExp, pNum );
   hbnum_native_release( &nTen );
   return HB_TRUE;
}

static HB_BOOL hbnum_native_mul_small( const HBNumNative * pA, HB_SIZE nFactor, HBNumNative * pResult )
{
   HBNumNative nB;

   hbnum_native_init( &nB );
   hbnum_native_set_small( ( HB_MAXINT ) nFactor, &nB );
   hbnum_native_mul( pA, &nB, pResult );
   hbnum_native_release( &nB );
   return HB_TRUE;
}

static HB_BOOL hbnum_native_div_small( const HBNumNative * pA, HB_SIZE nFactor, HB_SIZE nPrecision, HBNumNative * pResult )
{
   HBNumNative nB;

   hbnum_native_init( &nB );
   hbnum_native_set_small( ( HB_MAXINT ) nFactor, &nB );
   hbnum_native_div( pA, &nB, nPrecision, pResult );
   hbnum_native_release( &nB );
   return HB_TRUE;
}

static HB_BOOL hbnum_native_increment_one( HBNumNative * pNum )
{
   HBNumNative nOne;
   HBNumNative nTmp;

   hbnum_native_init( &nOne );
   hbnum_native_init( &nTmp );
   hbnum_native_set_one( &nOne );
   hbnum_native_add( pNum, &nOne, &nTmp );
   hbnum_native_replace( pNum, &nTmp );
   hbnum_native_release( &nOne );
   hbnum_native_release( &nTmp );
   return HB_TRUE;
}

static HB_BOOL hbnum_native_decrement_one( HBNumNative * pNum )
{
   HBNumNative nOne;
   HBNumNative nTmp;

   hbnum_native_init( &nOne );
   hbnum_native_init( &nTmp );
   hbnum_native_set_one( &nOne );
   hbnum_native_sub( pNum, &nOne, &nTmp );
   hbnum_native_replace( pNum, &nTmp );
   hbnum_native_release( &nOne );
   hbnum_native_release( &nTmp );
   return HB_TRUE;
}

static HB_BOOL hbnum_native_make_initial_root_guess( const HBNumNative * pA, HB_SIZE nDegree, HBNumNative * pGuess )
{
   char * szText;
   char * szStart;
   char * szDot;
   char * szPos;
   HB_SIZE nIntDigits;
   HB_SIZE nLeadingZeros;
   HB_SIZE nGuessExp;
   HB_SIZE nGuessScale;

   hbnum_native_init( pGuess );

   if( pA->used == 0 )
      return HB_TRUE;

   szText = hbnum_native_to_string( pA );
   szStart = szText;

   if( *szStart == '-' )
      ++szStart;

   szDot = strchr( szStart, '.' );

   if( szDot == NULL || szStart[ 0 ] != '0' || szDot != szStart + 1 )
   {
      if( szDot == NULL )
         nIntDigits = ( HB_SIZE ) strlen( szStart );
      else
         nIntDigits = ( HB_SIZE ) ( szDot - szStart );

      if( nIntDigits == 0 )
         nIntDigits = 1;

      nGuessExp = ( nIntDigits - 1 ) / nDegree;
      hbnum_native_set_power_of_ten( nGuessExp, pGuess );
      hb_xfree( szText );
      return HB_TRUE;
   }

   nLeadingZeros = 0;
   szPos = szDot + 1;

   while( *szPos == '0' )
   {
      ++nLeadingZeros;
      ++szPos;
   }

   hbnum_native_set_one( pGuess );
   nGuessScale = ( nLeadingZeros + 1 + nDegree - 1 ) / nDegree;
   pGuess->scale = nGuessScale;

   hb_xfree( szText );
   return HB_TRUE;
}

static HB_BOOL hbnum_native_integer_nth_root_floor( const HBNumNative * pA, HB_SIZE nDegree, HBNumNative * pResult )
{
   HBNumNative nGuess;
   HBNumNative nNext;
   HBNumNative nPow;
   HBNumNative nQuot;
   HBNumNative nScaledGuess;
   HBNumNative nSum;
   HBNumNative nPowCheck;
   HBNumNative nNextGuess;
   HBNumNative nOne;
   HBNumNative nDegreeNum;
   HBNumNative nDegreeMinusOne;
   HB_SIZE nIter;
   int nCmp;
   HB_BOOL fOk = HB_FALSE;

   hbnum_native_init( pResult );
   hbnum_native_init( &nGuess );
   hbnum_native_init( &nNext );
   hbnum_native_init( &nPow );
   hbnum_native_init( &nQuot );
   hbnum_native_init( &nScaledGuess );
   hbnum_native_init( &nSum );
   hbnum_native_init( &nPowCheck );
   hbnum_native_init( &nNextGuess );
   hbnum_native_init( &nOne );
   hbnum_native_init( &nDegreeNum );
   hbnum_native_init( &nDegreeMinusOne );

   if( nDegree == 0 || ! hbnum_native_is_integer( pA ) || pA->sign < 0 )
      goto cleanup_fail;

   if( pA->used == 0 )
   {
      fOk = HB_TRUE;
      goto cleanup_ok;
   }

   if( nDegree == 1 )
   {
      hbnum_native_clone( pA, pResult );
      fOk = HB_TRUE;
      goto cleanup_ok;
   }

   hbnum_native_make_initial_root_guess( pA, nDegree, &nGuess );
   if( nGuess.used == 0 )
      hbnum_native_set_one( &nGuess );

   hbnum_native_set_one( &nOne );
   hbnum_native_set_small( ( HB_MAXINT ) nDegree, &nDegreeNum );
   hbnum_native_set_small( ( HB_MAXINT ) ( nDegree - 1 ), &nDegreeMinusOne );

   for( nIter = 0; nIter < HBNUM_MAX_ROOT_ITERATIONS; ++nIter )
   {
      hbnum_native_pow_int_nonneg( &nGuess, nDegree - 1, &nPow );
      if( nPow.used == 0 )
         goto cleanup_fail;

      hbnum_native_div( pA, &nPow, 0, &nQuot );
      hbnum_native_mul( &nGuess, &nDegreeMinusOne, &nScaledGuess );
      hbnum_native_add( &nScaledGuess, &nQuot, &nSum );
      hbnum_native_div( &nSum, &nDegreeNum, 0, &nNext );

      nCmp = hbnum_native_compare( &nNext, &nGuess );
      if( nCmp >= 0 )
         break;

      hbnum_native_replace( &nGuess, &nNext );
      hbnum_native_release( &nPow );
      hbnum_native_release( &nQuot );
      hbnum_native_release( &nScaledGuess );
      hbnum_native_release( &nSum );
   }

   hbnum_native_pow_int_nonneg( &nGuess, nDegree, &nPowCheck );
   while( hbnum_native_compare( &nPowCheck, pA ) > 0 && nGuess.used > 0 )
   {
      hbnum_native_decrement_one( &nGuess );
      hbnum_native_release( &nPowCheck );
      hbnum_native_pow_int_nonneg( &nGuess, nDegree, &nPowCheck );
   }

   hbnum_native_clone( &nGuess, &nNextGuess );
   hbnum_native_increment_one( &nNextGuess );
   hbnum_native_pow_int_nonneg( &nNextGuess, nDegree, &nPow );

   while( hbnum_native_compare( &nPow, pA ) <= 0 )
   {
      hbnum_native_replace( &nGuess, &nNextGuess );
      hbnum_native_set_one( &nOne );
      hbnum_native_clone( &nGuess, &nNextGuess );
      hbnum_native_increment_one( &nNextGuess );
      hbnum_native_release( &nPow );
      hbnum_native_pow_int_nonneg( &nNextGuess, nDegree, &nPow );
   }

   hbnum_native_clone( &nGuess, pResult );
   fOk = HB_TRUE;

cleanup_ok:
   hbnum_native_release( &nGuess );
   hbnum_native_release( &nNext );
   hbnum_native_release( &nPow );
   hbnum_native_release( &nQuot );
   hbnum_native_release( &nScaledGuess );
   hbnum_native_release( &nSum );
   hbnum_native_release( &nPowCheck );
   hbnum_native_release( &nNextGuess );
   hbnum_native_release( &nOne );
   hbnum_native_release( &nDegreeNum );
   hbnum_native_release( &nDegreeMinusOne );
   return fOk;

cleanup_fail:
   hbnum_native_release( pResult );
   goto cleanup_ok;
}

static HB_BOOL hbnum_native_nth_root_exact( const HBNumNative * pA, HB_SIZE nDegree, HBNumNative * pResult )
{
   HBNumNative nInput;
   HBNumNative nScaledTen;
   HBNumNative nTmp;
   HBNumNative nRootInt;
   HBNumNative nPowCheck;
   HB_SIZE nAdjust;
   HB_SIZE nRootScale;
   int nSign;
   HB_BOOL fOk = HB_FALSE;

   hbnum_native_init( pResult );
   hbnum_native_init( &nInput );
   hbnum_native_init( &nScaledTen );
   hbnum_native_init( &nTmp );
   hbnum_native_init( &nRootInt );
   hbnum_native_init( &nPowCheck );

   if( nDegree == 0 )
      goto cleanup_fail;

   if( pA->used == 0 )
   {
      fOk = HB_TRUE;
      goto cleanup_ok;
   }

   if( pA->sign < 0 && ( nDegree % 2 ) == 0 )
      goto cleanup_fail;

   if( nDegree == 1 )
   {
      hbnum_native_clone( pA, pResult );
      fOk = HB_TRUE;
      goto cleanup_ok;
   }

   nSign = pA->sign;
   hbnum_native_abs_clone( pA, &nInput );

   nAdjust = nInput.scale % nDegree;
   if( nAdjust != 0 )
      nAdjust = nDegree - nAdjust;

   if( nAdjust > 0 )
   {
      hbnum_native_set_power_of_ten( nAdjust, &nScaledTen );
      hbnum_native_mul( &nInput, &nScaledTen, &nTmp );
      hbnum_native_replace( &nInput, &nTmp );
   }

   nInput.scale = 0;
   hbnum_native_integer_nth_root_floor( &nInput, nDegree, &nRootInt );
   hbnum_native_pow_int_nonneg( &nRootInt, nDegree, &nPowCheck );

   if( hbnum_native_compare( &nPowCheck, &nInput ) != 0 )
      goto cleanup_fail;

   nRootScale = ( pA->scale + nAdjust ) / nDegree;
   hbnum_native_clone( &nRootInt, pResult );
   pResult->scale = nRootScale;
   if( pResult->used > 0 )
      pResult->sign = nSign;
   hbnum_native_normalize( pResult );
   fOk = HB_TRUE;

cleanup_ok:
   hbnum_native_release( &nInput );
   hbnum_native_release( &nScaledTen );
   hbnum_native_release( &nTmp );
   hbnum_native_release( &nRootInt );
   hbnum_native_release( &nPowCheck );
   return fOk;

cleanup_fail:
   hbnum_native_release( pResult );
   hbnum_native_init( pResult );
   goto cleanup_ok;
}

static HB_BOOL hbnum_native_nth_root_approx( const HBNumNative * pA, HB_SIZE nDegree, HB_SIZE nPrecision, HBNumNative * pResult )
{
   HBNumNative nValue;
   HBNumNative nGuess;
   HBNumNative nPow;
   HBNumNative nTerm;
   HBNumNative nScaledGuess;
   HBNumNative nSum;
   HBNumNative nNext;
   HBNumNative nDiff;
   HBNumNative nEpsilon;
   HBNumNative nDegreeNum;
   HBNumNative nDegreeMinusOne;
   HB_SIZE nWorkPrecision;
   HB_SIZE nIter;
   HB_BOOL fOk = HB_FALSE;

   hbnum_native_init( pResult );
   hbnum_native_init( &nValue );
   hbnum_native_init( &nGuess );
   hbnum_native_init( &nPow );
   hbnum_native_init( &nTerm );
   hbnum_native_init( &nScaledGuess );
   hbnum_native_init( &nSum );
   hbnum_native_init( &nNext );
   hbnum_native_init( &nDiff );
   hbnum_native_init( &nEpsilon );
   hbnum_native_init( &nDegreeNum );
   hbnum_native_init( &nDegreeMinusOne );

   if( nDegree == 0 )
      goto cleanup_fail;

   if( pA->used == 0 )
   {
      fOk = HB_TRUE;
      goto cleanup_ok;
   }

   if( pA->sign < 0 && ( nDegree % 2 ) == 0 )
      goto cleanup_fail;

   if( nDegree == 1 )
   {
      hbnum_native_truncate( pA, nPrecision, pResult );
      fOk = HB_TRUE;
      goto cleanup_ok;
   }

   nWorkPrecision = nPrecision + HBNUM_ROOT_GUARD_DIGITS;
   hbnum_native_abs_clone( pA, &nValue );
   hbnum_native_make_initial_root_guess( &nValue, nDegree, &nGuess );
   if( nGuess.used == 0 )
      hbnum_native_set_one( &nGuess );

   hbnum_native_set_small( ( HB_MAXINT ) nDegree, &nDegreeNum );
   hbnum_native_set_small( ( HB_MAXINT ) ( nDegree - 1 ), &nDegreeMinusOne );
   hbnum_native_set_one( &nEpsilon );
   nEpsilon.scale = nWorkPrecision;

   for( nIter = 0; nIter < HBNUM_MAX_ROOT_ITERATIONS; ++nIter )
   {
      hbnum_native_pow_int_nonneg( &nGuess, nDegree - 1, &nPow );
      if( nPow.used == 0 )
         goto cleanup_fail;

      hbnum_native_div( &nValue, &nPow, nWorkPrecision, &nTerm );
      hbnum_native_mul( &nGuess, &nDegreeMinusOne, &nScaledGuess );
      hbnum_native_add( &nScaledGuess, &nTerm, &nSum );
      hbnum_native_div( &nSum, &nDegreeNum, nWorkPrecision, &nNext );
      hbnum_native_sub( &nNext, &nGuess, &nDiff );

      if( nDiff.sign < 0 && nDiff.used > 0 )
         nDiff.sign = 1;

      if( hbnum_native_compare( &nDiff, &nEpsilon ) <= 0 || hbnum_native_compare( &nNext, &nGuess ) == 0 )
      {
         hbnum_native_replace( &nGuess, &nNext );
         break;
      }

      hbnum_native_replace( &nGuess, &nNext );
      hbnum_native_release( &nPow );
      hbnum_native_release( &nTerm );
      hbnum_native_release( &nScaledGuess );
      hbnum_native_release( &nSum );
      hbnum_native_release( &nDiff );
   }

   if( pA->sign < 0 && nGuess.used > 0 )
      nGuess.sign = -1;

   hbnum_native_truncate( &nGuess, nPrecision, pResult );
   fOk = HB_TRUE;

cleanup_ok:
   hbnum_native_release( &nValue );
   hbnum_native_release( &nGuess );
   hbnum_native_release( &nPow );
   hbnum_native_release( &nTerm );
   hbnum_native_release( &nScaledGuess );
   hbnum_native_release( &nSum );
   hbnum_native_release( &nNext );
   hbnum_native_release( &nDiff );
   hbnum_native_release( &nEpsilon );
   hbnum_native_release( &nDegreeNum );
   hbnum_native_release( &nDegreeMinusOne );
   return fOk;

cleanup_fail:
   hbnum_native_release( pResult );
   goto cleanup_ok;
}

static HB_BOOL hbnum_native_build_e_constant( HB_SIZE nPrecision, HBNumNative * pResult )
{
   HBNumNative nAcc;
   HBNumNative nTerm;
   HBNumNative nNextTerm;
   HBNumNative nNextAcc;
   HBNumNative nEpsilon;
   HB_SIZE nWorkPrecision;
   HB_SIZE nK;

   hbnum_native_init( pResult );
   hbnum_native_init( &nAcc );
   hbnum_native_init( &nTerm );
   hbnum_native_init( &nNextTerm );
   hbnum_native_init( &nNextAcc );
   hbnum_native_init( &nEpsilon );

   nWorkPrecision = nPrecision + HBNUM_LOG_GUARD_DIGITS;
   hbnum_native_set_one( &nAcc );
   hbnum_native_set_one( &nTerm );
   hbnum_native_set_one( &nEpsilon );
   nEpsilon.scale = nWorkPrecision;

   for( nK = 1; nK <= HBNUM_MAX_E_TERMS; ++nK )
   {
      hbnum_native_div_small( &nTerm, nK, nWorkPrecision, &nNextTerm );
      if( nNextTerm.used == 0 )
         break;

      hbnum_native_add( &nAcc, &nNextTerm, &nNextAcc );
      hbnum_native_replace( &nAcc, &nNextAcc );
      hbnum_native_replace( &nTerm, &nNextTerm );

      if( hbnum_native_compare( &nTerm, &nEpsilon ) <= 0 )
         break;
   }

   hbnum_native_truncate( &nAcc, nWorkPrecision, pResult );

   hbnum_native_release( &nAcc );
   hbnum_native_release( &nTerm );
   hbnum_native_release( &nNextTerm );
   hbnum_native_release( &nNextAcc );
   hbnum_native_release( &nEpsilon );
   return HB_TRUE;
}

static HB_BOOL hbnum_native_log10_exact( const HBNumNative * pX, HBNumNative * pResult )
{
   char * szText;
   char * szStart;
   char * szDot;
   char * szPos;
   char * szWalk;
   HB_BOOL fAllZeros;
   HB_ISIZ nExponent;

   hbnum_native_init( pResult );

   if( pX->sign <= 0 )
      return HB_FALSE;

   szText = hbnum_native_to_string( pX );
   szStart = szText;

   if( *szStart == '-' )
   {
      hb_xfree( szText );
      return HB_FALSE;
   }

   szDot = strchr( szStart, '.' );

   if( szDot == NULL )
   {
      if( szStart[ 0 ] != '1' )
      {
         hb_xfree( szText );
         return HB_FALSE;
      }

      for( szWalk = szStart + 1; *szWalk != '\0'; ++szWalk )
      {
         if( *szWalk != '0' )
         {
            hb_xfree( szText );
            return HB_FALSE;
         }
      }

      nExponent = ( HB_ISIZ ) strlen( szStart ) - 1;
      hbnum_native_set_small( ( HB_MAXINT ) nExponent, pResult );
      hb_xfree( szText );
      return HB_TRUE;
   }

   fAllZeros = HB_TRUE;
   for( szWalk = szStart; szWalk < szDot; ++szWalk )
   {
      if( *szWalk != '0' )
      {
         fAllZeros = HB_FALSE;
         break;
      }
   }

   if( ! fAllZeros )
   {
      if( szStart[ 0 ] != '1' )
      {
         hb_xfree( szText );
         return HB_FALSE;
      }

      for( szWalk = szStart + 1; szWalk < szDot; ++szWalk )
      {
         if( *szWalk != '0' )
         {
            hb_xfree( szText );
            return HB_FALSE;
         }
      }

      for( szWalk = szDot + 1; *szWalk != '\0'; ++szWalk )
      {
         if( *szWalk != '0' )
         {
            hb_xfree( szText );
            return HB_FALSE;
         }
      }

      nExponent = ( HB_ISIZ ) ( szDot - szStart ) - 1;
      hbnum_native_set_small( ( HB_MAXINT ) nExponent, pResult );
      hb_xfree( szText );
      return HB_TRUE;
   }

   nExponent = 0;
   szPos = szDot + 1;

   while( *szPos == '0' )
   {
      --nExponent;
      ++szPos;
   }

   if( *szPos != '1' )
   {
      hb_xfree( szText );
      return HB_FALSE;
   }

   ++szPos;
   while( *szPos != '\0' )
   {
      if( *szPos != '0' )
      {
         hb_xfree( szText );
         return HB_FALSE;
      }
      ++szPos;
   }

   hbnum_native_set_small( ( HB_MAXINT ) nExponent, pResult );
   hb_xfree( szText );
   return HB_TRUE;
}

static HB_BOOL hbnum_native_log_integer_power_exact( const HBNumNative * pX, const HBNumNative * pBase, HBNumNative * pResult )
{
   HBNumNative nOne;
   HBNumNative nTemp;
   HBNumNative nNext;
   HB_ISIZ nExp;
   int nCmpBaseOne;
   int nCmpXOne;

   hbnum_native_init( pResult );
   hbnum_native_init( &nOne );
   hbnum_native_init( &nTemp );
   hbnum_native_init( &nNext );

   if( pX->sign <= 0 || pBase->sign <= 0 )
      goto cleanup_fail;

   hbnum_native_set_one( &nOne );
   nCmpBaseOne = hbnum_native_compare( pBase, &nOne );
   nCmpXOne = hbnum_native_compare( pX, &nOne );

   if( nCmpBaseOne == 0 )
      goto cleanup_fail;

   if( nCmpXOne == 0 )
      goto cleanup_ok;

   nExp = 0;

   if( nCmpBaseOne > 0 )
   {
      if( nCmpXOne > 0 )
      {
         hbnum_native_set_one( &nTemp );

         while( hbnum_native_compare( &nTemp, pX ) < 0 )
         {
            hbnum_native_mul( &nTemp, pBase, &nNext );
            hbnum_native_replace( &nTemp, &nNext );
            ++nExp;
         }

         if( hbnum_native_compare( &nTemp, pX ) != 0 )
            goto cleanup_fail;

         hbnum_native_set_small( ( HB_MAXINT ) nExp, pResult );
      }
      else
      {
         hbnum_native_clone( pX, &nTemp );

         while( hbnum_native_compare( &nTemp, &nOne ) < 0 )
         {
            hbnum_native_mul( &nTemp, pBase, &nNext );
            hbnum_native_replace( &nTemp, &nNext );
            ++nExp;
         }

         if( hbnum_native_compare( &nTemp, &nOne ) != 0 )
            goto cleanup_fail;

         hbnum_native_set_small( -( HB_MAXINT ) nExp, pResult );
      }
   }
   else
   {
      if( nCmpXOne < 0 )
      {
         hbnum_native_set_one( &nTemp );

         while( hbnum_native_compare( &nTemp, pX ) > 0 )
         {
            hbnum_native_mul( &nTemp, pBase, &nNext );
            hbnum_native_replace( &nTemp, &nNext );
            ++nExp;
         }

         if( hbnum_native_compare( &nTemp, pX ) != 0 )
            goto cleanup_fail;

         hbnum_native_set_small( ( HB_MAXINT ) nExp, pResult );
      }
      else
      {
         hbnum_native_clone( pX, &nTemp );

         while( hbnum_native_compare( &nTemp, &nOne ) > 0 )
         {
            hbnum_native_mul( &nTemp, pBase, &nNext );
            hbnum_native_replace( &nTemp, &nNext );
            ++nExp;
         }

         if( hbnum_native_compare( &nTemp, &nOne ) != 0 )
            goto cleanup_fail;

         hbnum_native_set_small( -( HB_MAXINT ) nExp, pResult );
      }
   }

cleanup_ok:
   hbnum_native_release( &nOne );
   hbnum_native_release( &nTemp );
   hbnum_native_release( &nNext );
   return HB_TRUE;

cleanup_fail:
   hbnum_native_release( pResult );
   hbnum_native_release( &nOne );
   hbnum_native_release( &nTemp );
   hbnum_native_release( &nNext );
   hbnum_native_init( pResult );
   return HB_FALSE;
}

static HB_BOOL hbnum_native_log_power_of_ten_ratio_exact( const HBNumNative * pX, const HBNumNative * pBase, HBNumNative * pResult )
{
   HBNumNative nXExponent;
   HBNumNative nBaseExponent;
   HB_MAXINT nXValue;
   HB_MAXINT nBaseValue;
   HB_BOOL fOk;

   hbnum_native_init( pResult );
   hbnum_native_init( &nXExponent );
   hbnum_native_init( &nBaseExponent );

   if( ! hbnum_native_log10_exact( pX, &nXExponent ) || ! hbnum_native_log10_exact( pBase, &nBaseExponent ) )
      goto cleanup_fail;

   if( ! hbnum_native_to_small_int( &nXExponent, &nXValue ) || ! hbnum_native_to_small_int( &nBaseExponent, &nBaseValue ) )
      goto cleanup_fail;

   fOk = hbnum_native_div_terminating_ratio( nXValue, nBaseValue, pResult );

   hbnum_native_release( &nXExponent );
   hbnum_native_release( &nBaseExponent );
   return fOk;

cleanup_fail:
   hbnum_native_release( pResult );
   hbnum_native_release( &nXExponent );
   hbnum_native_release( &nBaseExponent );
   hbnum_native_init( pResult );
   return HB_FALSE;
}

static HB_BOOL hbnum_native_log_approx( const HBNumNative * pX, const HBNumNative * pBase, HB_SIZE nPrecision, HBNumNative * pResult )
{
   HBNumNative nOne;
   HBNumNative nX;
   HBNumNative nBaseWork;
   HBNumNative nAccum;
   HBNumNative nFactor;
   HBNumNative nTmp;
   HBNumNative nPrevBase;
   HBNumNative nEpsilon;
   HB_SIZE nWorkPrecision;
   HB_SIZE nRootPrecision;
   HB_SIZE nStep;
   HB_BOOL fNegate;
   HB_BOOL fOk = HB_FALSE;

   hbnum_native_init( pResult );
   hbnum_native_init( &nOne );
   hbnum_native_init( &nX );
   hbnum_native_init( &nBaseWork );
   hbnum_native_init( &nAccum );
   hbnum_native_init( &nFactor );
   hbnum_native_init( &nTmp );
   hbnum_native_init( &nPrevBase );
   hbnum_native_init( &nEpsilon );

   if( pX->sign <= 0 || pBase->sign <= 0 )
      goto cleanup_fail;

   hbnum_native_set_one( &nOne );

   if( hbnum_native_compare( pBase, &nOne ) == 0 )
      goto cleanup_fail;

   if( hbnum_native_compare( pX, &nOne ) == 0 )
   {
      fOk = HB_TRUE;
      goto cleanup_ok;
   }

   nWorkPrecision = nPrecision + HBNUM_LOG_GUARD_DIGITS;
   nRootPrecision = nWorkPrecision + 2;
   fNegate = HB_FALSE;

   hbnum_native_abs_clone( pX, &nX );
   hbnum_native_abs_clone( pBase, &nBaseWork );

   if( hbnum_native_compare( &nX, &nOne ) < 0 )
   {
      hbnum_native_div( &nOne, &nX, nWorkPrecision, &nTmp );
      hbnum_native_replace( &nX, &nTmp );
      fNegate = ! fNegate;
   }

   if( hbnum_native_compare( &nBaseWork, &nOne ) < 0 )
   {
      hbnum_native_div( &nOne, &nBaseWork, nWorkPrecision, &nTmp );
      hbnum_native_replace( &nBaseWork, &nTmp );
      fNegate = ! fNegate;
   }

   if( hbnum_native_compare( &nX, &nBaseWork ) == 0 )
   {
      hbnum_native_set_one( pResult );
      if( fNegate && pResult->used > 0 )
         pResult->sign = -1;
      fOk = HB_TRUE;
      goto cleanup_ok;
   }

   hbnum_native_set_one( &nFactor );
   hbnum_native_set_one( &nEpsilon );
   nEpsilon.scale = nWorkPrecision;

   while( hbnum_native_compare( &nX, &nBaseWork ) > 0 )
   {
      hbnum_native_add( &nAccum, &nFactor, &nTmp );
      hbnum_native_replace( &nAccum, &nTmp );
      hbnum_native_div( &nX, &nBaseWork, nWorkPrecision, &nTmp );
      hbnum_native_replace( &nX, &nTmp );
   }

   hbnum_native_nth_root_approx( &nBaseWork, 2, nRootPrecision, &nTmp );
   hbnum_native_replace( &nBaseWork, &nTmp );
   hbnum_native_div_small( &nFactor, 2, nWorkPrecision, &nTmp );
   hbnum_native_replace( &nFactor, &nTmp );

   for( nStep = 0; nStep < HBNUM_MAX_LOG_STEPS; ++nStep )
   {
      if( hbnum_native_compare( &nBaseWork, &nOne ) <= 0 || hbnum_native_compare( &nFactor, &nEpsilon ) <= 0 )
         break;

      while( hbnum_native_compare( &nX, &nBaseWork ) > 0 )
      {
         hbnum_native_add( &nAccum, &nFactor, &nTmp );
         hbnum_native_replace( &nAccum, &nTmp );
         hbnum_native_div( &nX, &nBaseWork, nWorkPrecision, &nTmp );
         hbnum_native_replace( &nX, &nTmp );
      }

      hbnum_native_clone( &nBaseWork, &nPrevBase );
      hbnum_native_nth_root_approx( &nBaseWork, 2, nRootPrecision, &nTmp );
      hbnum_native_replace( &nBaseWork, &nTmp );

      if( hbnum_native_compare( &nBaseWork, &nPrevBase ) == 0 )
         break;

      hbnum_native_div_small( &nFactor, 2, nWorkPrecision, &nTmp );
      hbnum_native_replace( &nFactor, &nTmp );
      hbnum_native_release( &nPrevBase );
   }

   if( fNegate && nAccum.used > 0 )
      nAccum.sign = -1;

   hbnum_native_truncate( &nAccum, nPrecision, pResult );
   fOk = HB_TRUE;

cleanup_ok:
   hbnum_native_release( &nOne );
   hbnum_native_release( &nX );
   hbnum_native_release( &nBaseWork );
   hbnum_native_release( &nAccum );
   hbnum_native_release( &nFactor );
   hbnum_native_release( &nTmp );
   hbnum_native_release( &nPrevBase );
   hbnum_native_release( &nEpsilon );
   return fOk;

cleanup_fail:
   hbnum_native_release( pResult );
   goto cleanup_ok;
}

HB_FUNC( HBNUM_CORE_SQRT )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   HB_SIZE nPrecision = hb_parns( 2 );
   HBNumNative nA;
   HBNumNative nR;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nA );
   hbnum_native_init( &nR );

   hbnum_native_from_hash( pA, &nA );

   if( ! hbnum_native_nth_root_approx( &nA, 2, nPrecision, &nR ) )
   {
      hbnum_native_release( &nA );
      hbnum_native_release( &nR );
      hb_errRT_BASE( EG_ARG, 0, "Square root is undefined for negative numbers in the real domain", HB_ERR_FUNCNAME, 0 );
      return;
   }

   pHashResult = hbnum_native_to_hash( &nR );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nA );
   hbnum_native_release( &nR );
}

HB_FUNC( HBNUM_CORE_SQRT_AUTO )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   HBNumNative nA;
   HBNumNative nR;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nA );
   hbnum_native_init( &nR );
   hbnum_native_from_hash( pA, &nA );

   if( nA.sign < 0 )
   {
      hbnum_native_release( &nA );
      hbnum_native_release( &nR );
      hb_errRT_BASE( EG_ARG, 0, "Square root is undefined for negative numbers in the real domain", HB_ERR_FUNCNAME, 0 );
      return;
   }

   if( ! hbnum_native_nth_root_exact( &nA, 2, &nR ) )
   {
      hbnum_native_release( &nA );
      hbnum_native_release( &nR );
      hb_errRT_BASE( EG_ARG, 0, "Non-terminating square root requires explicit precision or HBNumContext root precision", HB_ERR_FUNCNAME, 0 );
      return;
   }

   pHashResult = hbnum_native_to_hash( &nR );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nA );
   hbnum_native_release( &nR );
}

HB_FUNC( HBNUM_CORE_NTHROOT )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   HB_SIZE nDegree = hb_parns( 2 );
   HB_SIZE nPrecision = hb_parns( 3 );
   HBNumNative nA;
   HBNumNative nR;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nA );
   hbnum_native_init( &nR );
   hbnum_native_from_hash( pA, &nA );

   if( nDegree == 0 )
   {
      hbnum_native_release( &nA );
      hbnum_native_release( &nR );
      hb_errRT_BASE( EG_ARG, 0, "NthRoot degree must be > 0", HB_ERR_FUNCNAME, 0 );
      return;
   }

   if( nA.sign < 0 && ( nDegree % 2 ) == 0 )
   {
      hbnum_native_release( &nA );
      hbnum_native_release( &nR );
      hb_errRT_BASE( EG_ARG, 0, "Even-degree root of a negative number is undefined in the real domain", HB_ERR_FUNCNAME, 0 );
      return;
   }

   if( ! hbnum_native_nth_root_approx( &nA, nDegree, nPrecision, &nR ) )
   {
      hbnum_native_release( &nA );
      hbnum_native_release( &nR );
      hb_errRT_BASE( EG_ARG, 0, "NthRoot failed to converge", HB_ERR_FUNCNAME, 0 );
      return;
   }

   pHashResult = hbnum_native_to_hash( &nR );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nA );
   hbnum_native_release( &nR );
}

HB_FUNC( HBNUM_CORE_NTHROOT_AUTO )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   HB_SIZE nDegree = hb_parns( 2 );
   HBNumNative nA;
   HBNumNative nR;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nA );
   hbnum_native_init( &nR );
   hbnum_native_from_hash( pA, &nA );

   if( nDegree == 0 )
   {
      hbnum_native_release( &nA );
      hbnum_native_release( &nR );
      hb_errRT_BASE( EG_ARG, 0, "NthRoot degree must be > 0", HB_ERR_FUNCNAME, 0 );
      return;
   }

   if( nA.sign < 0 && ( nDegree % 2 ) == 0 )
   {
      hbnum_native_release( &nA );
      hbnum_native_release( &nR );
      hb_errRT_BASE( EG_ARG, 0, "Even-degree root of a negative number is undefined in the real domain", HB_ERR_FUNCNAME, 0 );
      return;
   }

   if( ! hbnum_native_nth_root_exact( &nA, nDegree, &nR ) )
   {
      hbnum_native_release( &nA );
      hbnum_native_release( &nR );
      hb_errRT_BASE( EG_ARG, 0, "Non-terminating nth root requires explicit precision or HBNumContext root precision", HB_ERR_FUNCNAME, 0 );
      return;
   }

   pHashResult = hbnum_native_to_hash( &nR );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nA );
   hbnum_native_release( &nR );
}

HB_FUNC( HBNUM_CORE_LOG )
{
   PHB_ITEM pX = hb_param( 1, HB_IT_HASH );
   PHB_ITEM pBase = hb_param( 2, HB_IT_HASH );
   HB_SIZE nPrecision = hb_parns( 3 );
   HBNumNative nX;
   HBNumNative nBase;
   HBNumNative nR;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nX );
   hbnum_native_init( &nBase );
   hbnum_native_init( &nR );

   hbnum_native_from_hash( pX, &nX );
   hbnum_native_from_hash( pBase, &nBase );

   if( ! hbnum_native_log_approx( &nX, &nBase, nPrecision, &nR ) )
   {
      hbnum_native_release( &nX );
      hbnum_native_release( &nBase );
      hbnum_native_release( &nR );
      hb_errRT_BASE( EG_ARG, 0, "Logarithm requires x > 0 and base > 0 with base != 1", HB_ERR_FUNCNAME, 0 );
      return;
   }

   pHashResult = hbnum_native_to_hash( &nR );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nX );
   hbnum_native_release( &nBase );
   hbnum_native_release( &nR );
}

HB_FUNC( HBNUM_CORE_LOG_AUTO )
{
   PHB_ITEM pX = hb_param( 1, HB_IT_HASH );
   PHB_ITEM pBase = hb_param( 2, HB_IT_HASH );
   HBNumNative nX;
   HBNumNative nBase;
   HBNumNative nOne;
   HBNumNative nR;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nX );
   hbnum_native_init( &nBase );
   hbnum_native_init( &nOne );
   hbnum_native_init( &nR );

   hbnum_native_from_hash( pX, &nX );
   hbnum_native_from_hash( pBase, &nBase );
   hbnum_native_set_one( &nOne );

   if( nX.sign <= 0 || nBase.sign <= 0 || hbnum_native_compare( &nBase, &nOne ) == 0 )
   {
      hbnum_native_release( &nX );
      hbnum_native_release( &nBase );
      hbnum_native_release( &nOne );
      hbnum_native_release( &nR );
      hb_errRT_BASE( EG_ARG, 0, "Logarithm requires x > 0 and base > 0 with base != 1", HB_ERR_FUNCNAME, 0 );
      return;
   }

   if( hbnum_native_is_one_value( &nX ) )
   {
      hbnum_native_init( &nR );
   }
   else if( hbnum_native_compare( &nBase, &nX ) == 0 )
      hbnum_native_set_one( &nR );
   else if( ! hbnum_native_log_integer_power_exact( &nX, &nBase, &nR ) &&
            ! hbnum_native_log_power_of_ten_ratio_exact( &nX, &nBase, &nR ) )
   {
      hbnum_native_release( &nX );
      hbnum_native_release( &nBase );
      hbnum_native_release( &nOne );
      hbnum_native_release( &nR );
      hb_errRT_BASE( EG_ARG, 0, "Non-terminating logarithm requires explicit precision or HBNumContext log precision", HB_ERR_FUNCNAME, 0 );
      return;
   }

   pHashResult = hbnum_native_to_hash( &nR );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nX );
   hbnum_native_release( &nBase );
   hbnum_native_release( &nOne );
   hbnum_native_release( &nR );
}

HB_FUNC( HBNUM_CORE_LOG10 )
{
   PHB_ITEM pX = hb_param( 1, HB_IT_HASH );
   HB_SIZE nPrecision = hb_parns( 2 );
   HBNumNative nX;
   HBNumNative nBase;
   HBNumNative nR;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nX );
   hbnum_native_init( &nBase );
   hbnum_native_init( &nR );

   hbnum_native_from_hash( pX, &nX );
   hbnum_native_set_small( 10, &nBase );

   if( ! hbnum_native_log_approx( &nX, &nBase, nPrecision, &nR ) )
   {
      hbnum_native_release( &nX );
      hbnum_native_release( &nBase );
      hbnum_native_release( &nR );
      hb_errRT_BASE( EG_ARG, 0, "Base-10 logarithm requires x > 0", HB_ERR_FUNCNAME, 0 );
      return;
   }

   pHashResult = hbnum_native_to_hash( &nR );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nX );
   hbnum_native_release( &nBase );
   hbnum_native_release( &nR );
}

HB_FUNC( HBNUM_CORE_LOG10_AUTO )
{
   PHB_ITEM pX = hb_param( 1, HB_IT_HASH );
   HBNumNative nX;
   HBNumNative nR;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nX );
   hbnum_native_init( &nR );
   hbnum_native_from_hash( pX, &nX );

   if( nX.sign <= 0 )
   {
      hbnum_native_release( &nX );
      hbnum_native_release( &nR );
      hb_errRT_BASE( EG_ARG, 0, "Base-10 logarithm requires x > 0", HB_ERR_FUNCNAME, 0 );
      return;
   }

   if( hbnum_native_is_one_value( &nX ) )
      hbnum_native_init( &nR );
   else if( ! hbnum_native_log10_exact( &nX, &nR ) )
   {
      hbnum_native_release( &nX );
      hbnum_native_release( &nR );
      hb_errRT_BASE( EG_ARG, 0, "Non-terminating base-10 logarithm requires explicit precision or HBNumContext log precision", HB_ERR_FUNCNAME, 0 );
      return;
   }

   pHashResult = hbnum_native_to_hash( &nR );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nX );
   hbnum_native_release( &nR );
}

HB_FUNC( HBNUM_CORE_LN )
{
   PHB_ITEM pX = hb_param( 1, HB_IT_HASH );
   HB_SIZE nPrecision = hb_parns( 2 );
   HBNumNative nX;
   HBNumNative nE;
   HBNumNative nR;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nX );
   hbnum_native_init( &nE );
   hbnum_native_init( &nR );

   hbnum_native_from_hash( pX, &nX );
   hbnum_native_build_e_constant( nPrecision, &nE );

   if( ! hbnum_native_log_approx( &nX, &nE, nPrecision, &nR ) )
   {
      hbnum_native_release( &nX );
      hbnum_native_release( &nE );
      hbnum_native_release( &nR );
      hb_errRT_BASE( EG_ARG, 0, "Natural logarithm requires x > 0", HB_ERR_FUNCNAME, 0 );
      return;
   }

   pHashResult = hbnum_native_to_hash( &nR );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nX );
   hbnum_native_release( &nE );
   hbnum_native_release( &nR );
}

HB_FUNC( HBNUM_CORE_LN_AUTO )
{
   PHB_ITEM pX = hb_param( 1, HB_IT_HASH );
   HBNumNative nX;
   HBNumNative nR;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nX );
   hbnum_native_init( &nR );
   hbnum_native_from_hash( pX, &nX );

   if( nX.sign <= 0 )
   {
      hbnum_native_release( &nX );
      hbnum_native_release( &nR );
      hb_errRT_BASE( EG_ARG, 0, "Natural logarithm requires x > 0", HB_ERR_FUNCNAME, 0 );
      return;
   }

   if( ! hbnum_native_is_one_value( &nX ) )
   {
      hbnum_native_release( &nX );
      hbnum_native_release( &nR );
      hb_errRT_BASE( EG_ARG, 0, "Non-terminating natural logarithm requires explicit precision or HBNumContext log precision", HB_ERR_FUNCNAME, 0 );
      return;
   }

   pHashResult = hbnum_native_to_hash( &nR );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nX );
   hbnum_native_release( &nR );
}

HB_FUNC( HBNUM_CORE_MOD )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   PHB_ITEM pB = hb_param( 2, HB_IT_HASH );
   HBNumNative nA;
   HBNumNative nB;
   HBNumNative nR;
   PHB_ITEM pHashResult;
   HB_BOOL fOk;

   hbnum_native_init( &nA );
   hbnum_native_init( &nB );
   hbnum_native_init( &nR );

   hbnum_native_from_hash( pA, &nA );
   hbnum_native_from_hash( pB, &nB );

   fOk = hbnum_native_mod( &nA, &nB, &nR );
   if( !fOk )
   {
      hb_errRT_BASE( EG_ZERODIV, 0, "Division by zero", HB_ERR_FUNCNAME, 0 );
   }

   pHashResult = hbnum_native_to_hash( &nR );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nA );
   hbnum_native_release( &nB );
   hbnum_native_release( &nR );
}

HB_FUNC( HBNUM_CORE_POWINT )
{
   PHB_ITEM pBaseHash = hb_param( 1, HB_IT_HASH );
   HB_MAXINT nExp = hb_parnint( 2 );
   HBNumNative nBase;
   HBNumNative nResult;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nBase );
   hbnum_native_init( &nResult );

   hbnum_native_from_hash( pBaseHash, &nBase );

   if( nExp < 0 )
   {
      hbnum_native_release( &nBase );
      hbnum_native_release( &nResult );
      hb_errRT_BASE( EG_ARG, 0, "PowInt exponent must be >= 0", HB_ERR_FUNCNAME, 0 );
      return;
   }

   hbnum_native_pow_int_nonneg( &nBase, ( HB_SIZE ) nExp, &nResult );
   hbnum_native_normalize( &nResult );

   pHashResult = hbnum_native_to_hash( &nResult );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nBase );
   hbnum_native_release( &nResult );
}

HB_FUNC( HBNUM_CORE_ROUND )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   HB_SIZE nPrecision = hb_parns( 2 );
   HBNumNative nA;
   HBNumNative nR;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nA );
   hbnum_native_init( &nR );

   hbnum_native_from_hash( pA, &nA );
   hbnum_native_round( &nA, nPrecision, &nR );

   pHashResult = hbnum_native_to_hash( &nR );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nA );
   hbnum_native_release( &nR );
}

HB_FUNC( HBNUM_CORE_TRUNC )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   HB_SIZE nPrecision = hb_parns( 2 );
   HBNumNative nA;
   HBNumNative nR;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nA );
   hbnum_native_init( &nR );

   hbnum_native_from_hash( pA, &nA );
   hbnum_native_truncate( &nA, nPrecision, &nR );

   pHashResult = hbnum_native_to_hash( &nR );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nA );
   hbnum_native_release( &nR );
}

HB_FUNC( HBNUM_CORE_FLOOR )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   HB_SIZE nPrecision = hb_parns( 2 );
   HBNumNative nA;
   HBNumNative nR;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nA );
   hbnum_native_init( &nR );

   hbnum_native_from_hash( pA, &nA );
   hbnum_native_floor( &nA, nPrecision, &nR );

   pHashResult = hbnum_native_to_hash( &nR );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nA );
   hbnum_native_release( &nR );
}

HB_FUNC( HBNUM_CORE_CEILING )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   HB_SIZE nPrecision = hb_parns( 2 );
   HBNumNative nA;
   HBNumNative nR;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nA );
   hbnum_native_init( &nR );

   hbnum_native_from_hash( pA, &nA );
   hbnum_native_ceiling( &nA, nPrecision, &nR );

   pHashResult = hbnum_native_to_hash( &nR );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nA );
   hbnum_native_release( &nR );
}
