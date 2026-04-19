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
#include "hbapiitm.h"
#include "hbapierr.h"

#include "hbnum_native_internal.h"

#include <ctype.h>
#include <string.h>

#define HBNUM_DEC_CHUNK 1000000000UL

void hbnum_native_init( HBNumNative * pNum )
{
   pNum->sign = 0;
   pNum->scale = 0;
   pNum->used = 0;
   pNum->limbs = NULL;
}

void hbnum_native_release( HBNumNative * pNum )
{
   if( pNum->limbs != NULL )
   {
      hb_xfree( pNum->limbs );
      pNum->limbs = NULL;
   }

   pNum->sign = 0;
   pNum->scale = 0;
   pNum->used = 0;
}

static HB_U32 * hbnum_limbs_dup( const HB_U32 * pSrc, HB_SIZE nUsed )
{
   HB_U32 * pDst;

   if( nUsed == 0 )
      return NULL;

   pDst = ( HB_U32 * ) hb_xgrab( sizeof( HB_U32 ) * nUsed );
   memcpy( pDst, pSrc, sizeof( HB_U32 ) * nUsed );

   return pDst;
}

void hbnum_native_normalize( HBNumNative * pNum )
{
   while( pNum->used > 0 && pNum->limbs[ pNum->used - 1 ] == 0 )
      --pNum->used;

   if( pNum->used == 0 )
   {
      pNum->sign = 0;
      pNum->scale = 0;
   }
   else
   {
      pNum->sign = pNum->sign < 0 ? -1 : 1;
   }
}

HB_BOOL hbnum_native_clone( const HBNumNative * pSrc, HBNumNative * pDst )
{
   hbnum_native_init( pDst );
   pDst->sign = pSrc->sign;
   pDst->scale = pSrc->scale;
   pDst->used = pSrc->used;
   pDst->limbs = hbnum_limbs_dup( pSrc->limbs, pSrc->used );
   return HB_TRUE;
}

static int hbnum_mag_cmp( const HB_U32 * pA, HB_SIZE nAUsed, const HB_U32 * pB, HB_SIZE nBUsed )
{
   HB_SIZE nPos;

   if( nAUsed > nBUsed )
      return 1;
   if( nAUsed < nBUsed )
      return -1;

   for( nPos = nAUsed; nPos > 0; --nPos )
   {
      HB_U32 nALimb = pA[ nPos - 1 ];
      HB_U32 nBLimb = pB[ nPos - 1 ];

      if( nALimb > nBLimb )
         return 1;
      if( nALimb < nBLimb )
         return -1;
   }

   return 0;
}

static HB_BOOL hbnum_mag_add( const HB_U32 * pA, HB_SIZE nAUsed, const HB_U32 * pB, HB_SIZE nBUsed, HB_U32 ** ppOut, HB_SIZE * pnOutUsed )
{
   HB_SIZE nMax = nAUsed > nBUsed ? nAUsed : nBUsed;
   HB_U32 * pOut = ( HB_U32 * ) hb_xgrab( sizeof( HB_U32 ) * ( nMax + 1 ) );
   HB_U64 nCarry = 0;
   HB_SIZE nPos;

   for( nPos = 0; nPos < nMax; ++nPos )
   {
      HB_U64 nValue = nCarry;

      if( nPos < nAUsed )
         nValue += pA[ nPos ];
      if( nPos < nBUsed )
         nValue += pB[ nPos ];

      pOut[ nPos ] = ( HB_U32 ) ( nValue & HBNUM_MASK );
      nCarry = nValue >> HBNUM_LIMB_BITS;
   }

   if( nCarry != 0 )
      pOut[ nPos++ ] = ( HB_U32 ) nCarry;

   *ppOut = pOut;
   *pnOutUsed = nPos;
   return HB_TRUE;
}

static void hbnum_mag_sub_inplace( HB_U32 * pA, HB_SIZE * pnAUsed, const HB_U32 * pB, HB_SIZE nBUsed )
{
   HB_U64 nBorrow = 0;
   HB_U64 nBase = ( HB_U64 ) HBNUM_BASE;
   HB_SIZE nPos;

   for( nPos = 0; nPos < *pnAUsed; ++nPos )
   {
      HB_U64 nALimb = pA[ nPos ];
      HB_U64 nBLimb = nPos < nBUsed ? pB[ nPos ] : 0;
      HB_U64 nSub = nBLimb + nBorrow;

      if( nALimb < nSub )
      {
         pA[ nPos ] = ( HB_U32 ) ( nALimb + nBase - nSub );
         nBorrow = 1;
      }
      else
      {
         pA[ nPos ] = ( HB_U32 ) ( nALimb - nSub );
         nBorrow = 0;
      }
   }

   while( *pnAUsed > 0 && pA[ *pnAUsed - 1 ] == 0 )
      --( *pnAUsed );
}

static HB_BOOL hbnum_mag_sub( const HB_U32 * pA, HB_SIZE nAUsed, const HB_U32 * pB, HB_SIZE nBUsed, HB_U32 ** ppOut, HB_SIZE * pnOutUsed )
{
   HB_U32 * pOut = hbnum_limbs_dup( pA, nAUsed );
   HB_SIZE nUsed = nAUsed;

   hbnum_mag_sub_inplace( pOut, &nUsed, pB, nBUsed );

   *ppOut = pOut;
   *pnOutUsed = nUsed;
   return HB_TRUE;
}

static HB_BOOL hbnum_mag_mul( const HB_U32 * pA, HB_SIZE nAUsed, const HB_U32 * pB, HB_SIZE nBUsed, HB_U32 ** ppOut, HB_SIZE * pnOutUsed )
{
   HB_SIZE nPosA;
   HB_U32 * pOut;
   HB_SIZE nCap;

   if( nAUsed == 0 || nBUsed == 0 )
   {
      *ppOut = NULL;
      *pnOutUsed = 0;
      return HB_TRUE;
   }

   nCap = nAUsed + nBUsed;
   pOut = ( HB_U32 * ) hb_xgrab( sizeof( HB_U32 ) * nCap );
   memset( pOut, 0, sizeof( HB_U32 ) * nCap );

   for( nPosA = 0; nPosA < nAUsed; ++nPosA )
   {
      HB_SIZE nPosB;
      HB_U64 nCarry = 0;

      for( nPosB = 0; nPosB < nBUsed; ++nPosB )
      {
         HB_SIZE nOutPos = nPosA + nPosB;
         HB_U64 nValue = ( HB_U64 ) pOut[ nOutPos ] + ( HB_U64 ) pA[ nPosA ] * pB[ nPosB ] + nCarry;

         pOut[ nOutPos ] = ( HB_U32 ) ( nValue & HBNUM_MASK );
         nCarry = nValue >> HBNUM_LIMB_BITS;
      }

      if( nCarry != 0 )
      {
         HB_SIZE nOutPos = nPosA + nBUsed;
         HB_U64 nValue = ( HB_U64 ) pOut[ nOutPos ] + nCarry;

         pOut[ nOutPos ] = ( HB_U32 ) ( nValue & HBNUM_MASK );
         nCarry = nValue >> HBNUM_LIMB_BITS;

         while( nCarry != 0 )
         {
            ++nOutPos;
            nValue = ( HB_U64 ) pOut[ nOutPos ] + nCarry;
            pOut[ nOutPos ] = ( HB_U32 ) ( nValue & HBNUM_MASK );
            nCarry = nValue >> HBNUM_LIMB_BITS;
         }
      }
   }

   nCap = nAUsed + nBUsed;
   while( nCap > 0 && pOut[ nCap - 1 ] == 0 )
      --nCap;

   *ppOut = pOut;
   *pnOutUsed = nCap;
   return HB_TRUE;
}

static HB_BOOL hbnum_mag_mul_small_inplace( HB_U32 * pLimbs, HB_SIZE * pnUsed, HB_SIZE nCap, HB_U32 nFactor )
{
   HB_U64 nCarry = 0;
   HB_SIZE nPos;

   if( *pnUsed == 0 || nFactor == 0 )
   {
      *pnUsed = 0;
      return HB_TRUE;
   }

   for( nPos = 0; nPos < *pnUsed; ++nPos )
   {
      HB_U64 nValue = ( HB_U64 ) pLimbs[ nPos ] * nFactor + nCarry;

      pLimbs[ nPos ] = ( HB_U32 ) ( nValue & HBNUM_MASK );
      nCarry = nValue >> HBNUM_LIMB_BITS;
   }

   while( nCarry != 0 )
   {
      if( *pnUsed >= nCap )
         return HB_FALSE;

      pLimbs[ *pnUsed ] = ( HB_U32 ) ( nCarry & HBNUM_MASK );
      nCarry >>= HBNUM_LIMB_BITS;
      ++( *pnUsed );
   }

   return HB_TRUE;
}

static HB_BOOL hbnum_mag_mul_pow10( const HB_U32 * pSrc, HB_SIZE nSrcUsed, HB_SIZE nExp, HB_U32 ** ppOut, HB_SIZE * pnOutUsed )
{
   HB_U32 * pOut;
   HB_SIZE nCap;
   HB_SIZE nUsed;
   HB_SIZE nPos;

   if( nSrcUsed == 0 )
   {
      *ppOut = NULL;
      *pnOutUsed = 0;
      return HB_TRUE;
   }

   nCap = nSrcUsed + ( nExp / 8 ) + 8;
   pOut = ( HB_U32 * ) hb_xgrab( sizeof( HB_U32 ) * nCap );
   memset( pOut, 0, sizeof( HB_U32 ) * nCap );
   memcpy( pOut, pSrc, sizeof( HB_U32 ) * nSrcUsed );
   nUsed = nSrcUsed;

   for( nPos = 0; nPos < nExp; ++nPos )
   {
      if( !hbnum_mag_mul_small_inplace( pOut, &nUsed, nCap, 10 ) )
      {
         hb_xfree( pOut );
         *ppOut = NULL;
         *pnOutUsed = 0;
         return HB_FALSE;
      }
   }

   while( nUsed > 0 && pOut[ nUsed - 1 ] == 0 )
      --nUsed;

   *ppOut = pOut;
   *pnOutUsed = nUsed;
   return HB_TRUE;
}

static HB_U32 hbnum_mag_div_small_inplace( HB_U32 * pLimbs, HB_SIZE * pnUsed, HB_U32 nDivisor )
{
   HB_U32 nRemainder = 0;
   HB_SIZE nPos;

   for( nPos = *pnUsed; nPos > 0; --nPos )
   {
      HB_U64 nValue = ( ( HB_U64 ) nRemainder << HBNUM_LIMB_BITS ) | pLimbs[ nPos - 1 ];

      pLimbs[ nPos - 1 ] = ( HB_U32 ) ( nValue / nDivisor );
      nRemainder = ( HB_U32 ) ( nValue % nDivisor );
   }

   while( *pnUsed > 0 && pLimbs[ *pnUsed - 1 ] == 0 )
      --( *pnUsed );

   return nRemainder;
}

static HB_U32 hbnum_mag_mod_small( const HB_U32 * pLimbs, HB_SIZE nUsed, HB_U32 nDivisor )
{
   HB_U32 nRemainder = 0;
   HB_SIZE nPos;

   for( nPos = nUsed; nPos > 0; --nPos )
   {
      HB_U64 nValue = ( ( HB_U64 ) nRemainder << HBNUM_LIMB_BITS ) | pLimbs[ nPos - 1 ];

      nRemainder = ( HB_U32 ) ( nValue % nDivisor );
   }

   return nRemainder;
}

static HB_SIZE hbnum_mag_bitlen( const HB_U32 * pLimbs, HB_SIZE nUsed )
{
   HB_SIZE nBits = 0;

   if( nUsed > 0 )
   {
      HB_U32 nTop = pLimbs[ nUsed - 1 ];

      nBits = ( nUsed - 1 ) * HBNUM_LIMB_BITS;

      while( nTop != 0 )
      {
         ++nBits;
         nTop >>= 1;
      }
   }

   return nBits;
}

static HB_BOOL hbnum_mag_shift_left_bits( const HB_U32 * pSrc, HB_SIZE nSrcUsed, HB_SIZE nBits, HB_U32 ** ppOut, HB_SIZE * pnOutUsed )
{
   HB_SIZE nWordShift = nBits / HBNUM_LIMB_BITS;
   HB_SIZE nBitShift = nBits % HBNUM_LIMB_BITS;
   HB_SIZE nCap = nSrcUsed + nWordShift + 1;
   HB_U32 * pOut = ( HB_U32 * ) hb_xgrab( sizeof( HB_U32 ) * nCap );
   HB_SIZE nPos;

   memset( pOut, 0, sizeof( HB_U32 ) * nCap );

   if( nBitShift == 0 )
   {
      for( nPos = 0; nPos < nSrcUsed; ++nPos )
         pOut[ nPos + nWordShift ] = pSrc[ nPos ];
   }
   else
   {
      HB_U32 nCarry = 0;

      for( nPos = 0; nPos < nSrcUsed; ++nPos )
      {
         HB_U64 nValue = ( ( HB_U64 ) pSrc[ nPos ] << nBitShift ) | nCarry;

         pOut[ nPos + nWordShift ] = ( HB_U32 ) ( nValue & HBNUM_MASK );
         nCarry = ( HB_U32 ) ( nValue >> HBNUM_LIMB_BITS );
      }

      pOut[ nSrcUsed + nWordShift ] = nCarry;
   }

   nCap = nSrcUsed + nWordShift + 1;
   while( nCap > 0 && pOut[ nCap - 1 ] == 0 )
      --nCap;

   *ppOut = pOut;
   *pnOutUsed = nCap;
   return HB_TRUE;
}

static void hbnum_mag_shift_right_one_inplace( HB_U32 * pLimbs, HB_SIZE * pnUsed )
{
   HB_U32 nCarry = 0;
   HB_SIZE nPos;

   for( nPos = *pnUsed; nPos > 0; --nPos )
   {
      HB_U32 nCurrent = pLimbs[ nPos - 1 ];

      pLimbs[ nPos - 1 ] = ( nCurrent >> 1 ) | ( nCarry << ( HBNUM_LIMB_BITS - 1 ) );
      nCarry = nCurrent & 1U;
   }

   while( *pnUsed > 0 && pLimbs[ *pnUsed - 1 ] == 0 )
      --( *pnUsed );
}

static HB_BOOL hbnum_mag_div( const HB_U32 * pDividend, HB_SIZE nDividendUsed, const HB_U32 * pDivisor, HB_SIZE nDivisorUsed, HB_U32 ** ppQuot, HB_SIZE * pnQuotUsed )
{
   HB_U32 * pRemainder;
   HB_SIZE nRemainderUsed;
   HB_U32 * pShiftedDivisor;
   HB_SIZE nShiftedDivisorUsed;
   HB_SIZE nShift;
   HB_U32 * pQuot;
   HB_SIZE nQuotCap;
   HB_SIZE nLoop;

   if( nDivisorUsed == 0 )
      return HB_FALSE;

   if( nDividendUsed == 0 || hbnum_mag_cmp( pDividend, nDividendUsed, pDivisor, nDivisorUsed ) < 0 )
   {
      *ppQuot = NULL;
      *pnQuotUsed = 0;
      return HB_TRUE;
   }

   nShift = hbnum_mag_bitlen( pDividend, nDividendUsed ) - hbnum_mag_bitlen( pDivisor, nDivisorUsed );
   pRemainder = hbnum_limbs_dup( pDividend, nDividendUsed );
   nRemainderUsed = nDividendUsed;
   hbnum_mag_shift_left_bits( pDivisor, nDivisorUsed, nShift, &pShiftedDivisor, &nShiftedDivisorUsed );

   nQuotCap = ( nShift / HBNUM_LIMB_BITS ) + 1;
   pQuot = ( HB_U32 * ) hb_xgrab( sizeof( HB_U32 ) * nQuotCap );
   memset( pQuot, 0, sizeof( HB_U32 ) * nQuotCap );

   for( nLoop = nShift + 1; nLoop > 0; --nLoop )
   {
      HB_SIZE nBit = nLoop - 1;

      if( hbnum_mag_cmp( pRemainder, nRemainderUsed, pShiftedDivisor, nShiftedDivisorUsed ) >= 0 )
      {
         HB_SIZE nLimb = nBit / HBNUM_LIMB_BITS;
         HB_SIZE nOffset = nBit % HBNUM_LIMB_BITS;

         hbnum_mag_sub_inplace( pRemainder, &nRemainderUsed, pShiftedDivisor, nShiftedDivisorUsed );
         pQuot[ nLimb ] |= ( HB_U32 ) ( 1U << nOffset );
      }

      if( nBit > 0 )
         hbnum_mag_shift_right_one_inplace( pShiftedDivisor, &nShiftedDivisorUsed );
   }

   hb_xfree( pRemainder );
   hb_xfree( pShiftedDivisor );

   while( nQuotCap > 0 && pQuot[ nQuotCap - 1 ] == 0 )
      --nQuotCap;

   *ppQuot = pQuot;
   *pnQuotUsed = nQuotCap;
   return HB_TRUE;
}

static HB_BOOL hbnum_native_clone_scaled( const HBNumNative * pSrc, HB_SIZE nTargetScale, HBNumNative * pDst )
{
   hbnum_native_clone( pSrc, pDst );

   if( nTargetScale > pSrc->scale && pDst->used > 0 )
   {
      HB_U32 * pScaled;
      HB_SIZE nScaledUsed;

      if( !hbnum_mag_mul_pow10( pDst->limbs, pDst->used, nTargetScale - pSrc->scale, &pScaled, &nScaledUsed ) )
      {
         hbnum_native_release( pDst );
         return HB_FALSE;
      }

      hb_xfree( pDst->limbs );
      pDst->limbs = pScaled;
      pDst->used = nScaledUsed;
   }

   pDst->scale = nTargetScale;
   return HB_TRUE;
}

static HB_BOOL hbnum_native_align_scales( const HBNumNative * pA, const HBNumNative * pB, HBNumNative * pAA, HBNumNative * pBB, HB_SIZE * pnScale )
{
   HB_SIZE nScale = pA->scale > pB->scale ? pA->scale : pB->scale;

   if( !hbnum_native_clone_scaled( pA, nScale, pAA ) )
      return HB_FALSE;

   if( !hbnum_native_clone_scaled( pB, nScale, pBB ) )
   {
      hbnum_native_release( pAA );
      return HB_FALSE;
   }

   *pnScale = nScale;
   return HB_TRUE;
}

HB_BOOL hbnum_native_add( const HBNumNative * pA, const HBNumNative * pB, HBNumNative * pResult )
{
   HBNumNative nAA;
   HBNumNative nBB;
   HB_SIZE nScale;
   HB_U32 * pOutLimbs = NULL;
   HB_SIZE nOutUsed = 0;

   hbnum_native_init( pResult );
   hbnum_native_init( &nAA );
   hbnum_native_init( &nBB );

   if( !hbnum_native_align_scales( pA, pB, &nAA, &nBB, &nScale ) )
      return HB_FALSE;

   if( nAA.sign == nBB.sign )
   {
      hbnum_mag_add( nAA.limbs, nAA.used, nBB.limbs, nBB.used, &pOutLimbs, &nOutUsed );
      pResult->sign = nAA.sign;
   }
   else
   {
      int nCmp = hbnum_mag_cmp( nAA.limbs, nAA.used, nBB.limbs, nBB.used );

      if( nCmp == 0 )
      {
         hbnum_native_release( &nAA );
         hbnum_native_release( &nBB );
         return HB_TRUE;
      }

      if( nCmp > 0 )
      {
         hbnum_mag_sub( nAA.limbs, nAA.used, nBB.limbs, nBB.used, &pOutLimbs, &nOutUsed );
         pResult->sign = nAA.sign;
      }
      else
      {
         hbnum_mag_sub( nBB.limbs, nBB.used, nAA.limbs, nAA.used, &pOutLimbs, &nOutUsed );
         pResult->sign = nBB.sign;
      }
   }

   pResult->scale = nScale;
   pResult->used = nOutUsed;
   pResult->limbs = pOutLimbs;
   hbnum_native_normalize( pResult );

   hbnum_native_release( &nAA );
   hbnum_native_release( &nBB );
   return HB_TRUE;
}

HB_BOOL hbnum_native_sub( const HBNumNative * pA, const HBNumNative * pB, HBNumNative * pResult )
{
   HBNumNative nNegB;
   HB_BOOL fOk;

   hbnum_native_init( &nNegB );
   hbnum_native_clone( pB, &nNegB );
   nNegB.sign = -nNegB.sign;

   fOk = hbnum_native_add( pA, &nNegB, pResult );
   hbnum_native_release( &nNegB );
   return fOk;
}

HB_BOOL hbnum_native_mul( const HBNumNative * pA, const HBNumNative * pB, HBNumNative * pResult )
{
   HB_U32 * pOutLimbs = NULL;
   HB_SIZE nOutUsed = 0;

   hbnum_native_init( pResult );
   hbnum_mag_mul( pA->limbs, pA->used, pB->limbs, pB->used, &pOutLimbs, &nOutUsed );

   pResult->sign = pA->sign == pB->sign ? 1 : -1;
   pResult->scale = pA->scale + pB->scale;
   pResult->used = nOutUsed;
   pResult->limbs = pOutLimbs;
   hbnum_native_normalize( pResult );
   return HB_TRUE;
}

HB_BOOL hbnum_native_div( const HBNumNative * pA, const HBNumNative * pB, HB_SIZE nPrecision, HBNumNative * pResult )
{
   HB_U32 * pNumerator;
   HB_SIZE nNumeratorUsed;
   HB_U32 * pDenominator;
   HB_SIZE nDenominatorUsed;
   HB_ISIZ nExponent;
   HB_U32 * pScaled = NULL;
   HB_SIZE nScaledUsed = 0;
   HB_U32 * pQuot = NULL;
   HB_SIZE nQuotUsed = 0;

   hbnum_native_init( pResult );

   if( pB->used == 0 )
      return HB_FALSE;

   if( pA->used == 0 )
      return HB_TRUE;

   pNumerator = hbnum_limbs_dup( pA->limbs, pA->used );
   nNumeratorUsed = pA->used;
   pDenominator = hbnum_limbs_dup( pB->limbs, pB->used );
   nDenominatorUsed = pB->used;

   nExponent = ( HB_ISIZ ) nPrecision + ( HB_ISIZ ) pB->scale - ( HB_ISIZ ) pA->scale;

   if( nExponent > 0 )
   {
      hbnum_mag_mul_pow10( pNumerator, nNumeratorUsed, ( HB_SIZE ) nExponent, &pScaled, &nScaledUsed );
      hb_xfree( pNumerator );
      pNumerator = pScaled;
      nNumeratorUsed = nScaledUsed;
   }
   else if( nExponent < 0 )
   {
      hbnum_mag_mul_pow10( pDenominator, nDenominatorUsed, ( HB_SIZE ) ( -nExponent ), &pScaled, &nScaledUsed );
      hb_xfree( pDenominator );
      pDenominator = pScaled;
      nDenominatorUsed = nScaledUsed;
   }

   hbnum_mag_div( pNumerator, nNumeratorUsed, pDenominator, nDenominatorUsed, &pQuot, &nQuotUsed );

   hb_xfree( pNumerator );
   hb_xfree( pDenominator );

   pResult->sign = pA->sign == pB->sign ? 1 : -1;
   pResult->scale = nPrecision;
   pResult->used = nQuotUsed;
   pResult->limbs = pQuot;
   hbnum_native_normalize( pResult );
   return HB_TRUE;
}

static HB_BOOL hbnum_mag_div_pow10( const HB_U32 * pSrc, HB_SIZE nSrcUsed, HB_SIZE nExp, HB_U32 ** ppQuot, HB_SIZE * pnQuotUsed, HB_BOOL * pfDropped, HB_U32 * pnRoundDigit )
{
   HB_U32 * pQuot;
   HB_SIZE nQuotUsed;
   HB_SIZE nPos;
   HB_BOOL fDropped = HB_FALSE;
   HB_U32 nRoundDigit = 0;

   if( nSrcUsed == 0 )
   {
      *ppQuot = NULL;
      *pnQuotUsed = 0;
      if( pfDropped != NULL )
         *pfDropped = HB_FALSE;
      if( pnRoundDigit != NULL )
         *pnRoundDigit = 0;
      return HB_TRUE;
   }

   pQuot = hbnum_limbs_dup( pSrc, nSrcUsed );
   nQuotUsed = nSrcUsed;

   for( nPos = 0; nPos < nExp; ++nPos )
   {
      HB_U32 nRem = hbnum_mag_div_small_inplace( pQuot, &nQuotUsed, 10 );

      if( nRem != 0 )
         fDropped = HB_TRUE;

      if( nPos + 1 == nExp )
         nRoundDigit = nRem;
   }

   *ppQuot = pQuot;
   *pnQuotUsed = nQuotUsed;

   if( pfDropped != NULL )
      *pfDropped = fDropped;

   if( pnRoundDigit != NULL )
      *pnRoundDigit = nRoundDigit;

   return HB_TRUE;
}

static HB_BOOL hbnum_mag_increment_one( HB_U32 ** ppLimbs, HB_SIZE * pnUsed )
{
   HB_U32 nOne = 1;
   HB_U32 * pOut = NULL;
   HB_SIZE nOutUsed = 0;

   hbnum_mag_add( *ppLimbs, *pnUsed, &nOne, 1, &pOut, &nOutUsed );

   if( *ppLimbs != NULL )
      hb_xfree( *ppLimbs );

   *ppLimbs = pOut;
   *pnUsed = nOutUsed;
   return HB_TRUE;
}

static HB_BOOL hbnum_mag_is_one( const HB_U32 * pLimbs, HB_SIZE nUsed )
{
   return nUsed == 1 && pLimbs[ 0 ] == 1;
}

static HB_BOOL hbnum_mag_mul_factor_pow( const HB_U32 * pSrc, HB_SIZE nSrcUsed, HB_U32 nFactor, HB_SIZE nExp, HB_U32 ** ppOut, HB_SIZE * pnOutUsed )
{
   HB_U32 * pOut;
   HB_SIZE nCap;
   HB_SIZE nUsed;
   HB_SIZE nPos;

   if( nSrcUsed == 0 )
   {
      *ppOut = NULL;
      *pnOutUsed = 0;
      return HB_TRUE;
   }

   if( nExp == 0 )
   {
      *ppOut = hbnum_limbs_dup( pSrc, nSrcUsed );
      *pnOutUsed = nSrcUsed;
      return HB_TRUE;
   }

   nCap = nSrcUsed + nExp + 8;
   pOut = ( HB_U32 * ) hb_xgrab( sizeof( HB_U32 ) * nCap );
   memset( pOut, 0, sizeof( HB_U32 ) * nCap );
   memcpy( pOut, pSrc, sizeof( HB_U32 ) * nSrcUsed );
   nUsed = nSrcUsed;

   for( nPos = 0; nPos < nExp; ++nPos )
   {
      if( !hbnum_mag_mul_small_inplace( pOut, &nUsed, nCap, nFactor ) )
      {
         hb_xfree( pOut );
         *ppOut = NULL;
         *pnOutUsed = 0;
         return HB_FALSE;
      }
   }

   while( nUsed > 0 && pOut[ nUsed - 1 ] == 0 )
      --nUsed;

   *ppOut = pOut;
   *pnOutUsed = nUsed;
   return HB_TRUE;
}

HB_BOOL hbnum_native_truncate( const HBNumNative * pA, HB_SIZE nPrecision, HBNumNative * pResult )
{
   HB_SIZE nDrop;
   HB_U32 * pQuot = NULL;
   HB_SIZE nQuotUsed = 0;

   hbnum_native_init( pResult );

   if( pA->used == 0 )
      return HB_TRUE;

   if( pA->scale <= nPrecision )
      return hbnum_native_clone( pA, pResult );

   nDrop = pA->scale - nPrecision;
   hbnum_mag_div_pow10( pA->limbs, pA->used, nDrop, &pQuot, &nQuotUsed, NULL, NULL );

   pResult->sign = pA->sign;
   pResult->scale = nPrecision;
   pResult->used = nQuotUsed;
   pResult->limbs = pQuot;
   hbnum_native_normalize( pResult );
   return HB_TRUE;
}

HB_BOOL hbnum_native_round( const HBNumNative * pA, HB_SIZE nPrecision, HBNumNative * pResult )
{
   HB_SIZE nDrop;
   HB_U32 * pQuot = NULL;
   HB_SIZE nQuotUsed = 0;
   HB_U32 nRoundDigit = 0;

   hbnum_native_init( pResult );

   if( pA->used == 0 )
      return HB_TRUE;

   if( pA->scale <= nPrecision )
      return hbnum_native_clone( pA, pResult );

   nDrop = pA->scale - nPrecision;
   hbnum_mag_div_pow10( pA->limbs, pA->used, nDrop, &pQuot, &nQuotUsed, NULL, &nRoundDigit );

   if( nRoundDigit >= 5 )
      hbnum_mag_increment_one( &pQuot, &nQuotUsed );

   pResult->sign = pA->sign;
   pResult->scale = nPrecision;
   pResult->used = nQuotUsed;
   pResult->limbs = pQuot;
   hbnum_native_normalize( pResult );
   return HB_TRUE;
}

HB_BOOL hbnum_native_floor( const HBNumNative * pA, HB_SIZE nPrecision, HBNumNative * pResult )
{
   HB_SIZE nDrop;
   HB_U32 * pQuot = NULL;
   HB_SIZE nQuotUsed = 0;
   HB_BOOL fDropped = HB_FALSE;

   hbnum_native_init( pResult );

   if( pA->used == 0 )
      return HB_TRUE;

   if( pA->scale <= nPrecision )
      return hbnum_native_clone( pA, pResult );

   nDrop = pA->scale - nPrecision;
   hbnum_mag_div_pow10( pA->limbs, pA->used, nDrop, &pQuot, &nQuotUsed, &fDropped, NULL );

   if( pA->sign < 0 && fDropped )
      hbnum_mag_increment_one( &pQuot, &nQuotUsed );

   pResult->sign = pA->sign;
   pResult->scale = nPrecision;
   pResult->used = nQuotUsed;
   pResult->limbs = pQuot;
   hbnum_native_normalize( pResult );
   return HB_TRUE;
}

HB_BOOL hbnum_native_ceiling( const HBNumNative * pA, HB_SIZE nPrecision, HBNumNative * pResult )
{
   HB_SIZE nDrop;
   HB_U32 * pQuot = NULL;
   HB_SIZE nQuotUsed = 0;
   HB_BOOL fDropped = HB_FALSE;

   hbnum_native_init( pResult );

   if( pA->used == 0 )
      return HB_TRUE;

   if( pA->scale <= nPrecision )
      return hbnum_native_clone( pA, pResult );

   nDrop = pA->scale - nPrecision;
   hbnum_mag_div_pow10( pA->limbs, pA->used, nDrop, &pQuot, &nQuotUsed, &fDropped, NULL );

   if( pA->sign > 0 && fDropped )
      hbnum_mag_increment_one( &pQuot, &nQuotUsed );

   pResult->sign = pA->sign;
   pResult->scale = nPrecision;
   pResult->used = nQuotUsed;
   pResult->limbs = pQuot;
   hbnum_native_normalize( pResult );
   return HB_TRUE;
}

static HB_BOOL hbnum_native_div_exact( const HBNumNative * pA, const HBNumNative * pB, HBNumNative * pResult )
{
   HBNumNative nNum;
   HBNumNative nDen;
   HBNumNative nG;
   HBNumNative nTmp;
   HB_U32 * pScaled = NULL;
   HB_SIZE nScaledUsed = 0;
   HB_SIZE nTwos = 0;
   HB_SIZE nFives = 0;
   HB_SIZE nScale;

   hbnum_native_init( pResult );
   hbnum_native_init( &nNum );
   hbnum_native_init( &nDen );
   hbnum_native_init( &nG );
   hbnum_native_init( &nTmp );

   if( pB->used == 0 )
      return HB_FALSE;

   if( pA->used == 0 )
      return HB_TRUE;

   hbnum_native_clone( pA, &nNum );
   hbnum_native_clone( pB, &nDen );

   if( nNum.used > 0 )
      nNum.sign = 1;
   if( nDen.used > 0 )
      nDen.sign = 1;

   if( pB->scale > pA->scale )
   {
      if( !hbnum_mag_mul_pow10( nNum.limbs, nNum.used, pB->scale - pA->scale, &pScaled, &nScaledUsed ) )
         goto cleanup_fail;

      hb_xfree( nNum.limbs );
      nNum.limbs = pScaled;
      nNum.used = nScaledUsed;
      pScaled = NULL;
      nScaledUsed = 0;
   }
   else if( pA->scale > pB->scale )
   {
      if( !hbnum_mag_mul_pow10( nDen.limbs, nDen.used, pA->scale - pB->scale, &pScaled, &nScaledUsed ) )
         goto cleanup_fail;

      hb_xfree( nDen.limbs );
      nDen.limbs = pScaled;
      nDen.used = nScaledUsed;
      pScaled = NULL;
      nScaledUsed = 0;
   }

   nNum.scale = 0;
   nDen.scale = 0;

   hbnum_native_gcd_int( &nNum, &nDen, &nG );

   if( nG.used > 0 && ! hbnum_mag_is_one( nG.limbs, nG.used ) )
   {
      hbnum_native_div( &nNum, &nG, 0, &nTmp );
      hbnum_native_release( &nNum );
      nNum = nTmp;
      hbnum_native_init( &nTmp );

      hbnum_native_div( &nDen, &nG, 0, &nTmp );
      hbnum_native_release( &nDen );
      nDen = nTmp;
      hbnum_native_init( &nTmp );
   }

   while( nDen.used > 0 && hbnum_mag_mod_small( nDen.limbs, nDen.used, 2 ) == 0 )
   {
      hbnum_mag_div_small_inplace( nDen.limbs, &nDen.used, 2 );
      ++nTwos;
   }

   while( nDen.used > 0 && hbnum_mag_mod_small( nDen.limbs, nDen.used, 5 ) == 0 )
   {
      hbnum_mag_div_small_inplace( nDen.limbs, &nDen.used, 5 );
      ++nFives;
   }

   if( ! hbnum_mag_is_one( nDen.limbs, nDen.used ) )
      goto cleanup_fail;

   nScale = nTwos > nFives ? nTwos : nFives;

   if( nTwos < nScale )
   {
      if( !hbnum_mag_mul_factor_pow( nNum.limbs, nNum.used, 2, nScale - nTwos, &pScaled, &nScaledUsed ) )
         goto cleanup_fail;

      hb_xfree( nNum.limbs );
      nNum.limbs = pScaled;
      nNum.used = nScaledUsed;
      pScaled = NULL;
      nScaledUsed = 0;
   }

   if( nFives < nScale )
   {
      if( !hbnum_mag_mul_factor_pow( nNum.limbs, nNum.used, 5, nScale - nFives, &pScaled, &nScaledUsed ) )
         goto cleanup_fail;

      hb_xfree( nNum.limbs );
      nNum.limbs = pScaled;
      nNum.used = nScaledUsed;
      pScaled = NULL;
      nScaledUsed = 0;
   }

   pResult->sign = pA->sign == pB->sign ? 1 : -1;
   pResult->scale = nScale;
   pResult->used = nNum.used;
   pResult->limbs = nNum.limbs;
   nNum.limbs = NULL;
   nNum.used = 0;
   hbnum_native_normalize( pResult );

   hbnum_native_release( &nNum );
   hbnum_native_release( &nDen );
   hbnum_native_release( &nG );
   hbnum_native_release( &nTmp );
   return HB_TRUE;

cleanup_fail:
   if( pScaled != NULL )
      hb_xfree( pScaled );
   hbnum_native_release( &nNum );
   hbnum_native_release( &nDen );
   hbnum_native_release( &nG );
   hbnum_native_release( &nTmp );
   hbnum_native_init( pResult );
   return HB_FALSE;
}

int hbnum_native_compare( const HBNumNative * pA, const HBNumNative * pB )
{
   HBNumNative nAA;
   HBNumNative nBB;
   HB_SIZE nScale;
   int nResult;

   if( pA->sign > pB->sign )
      return 1;
   if( pA->sign < pB->sign )
      return -1;
   if( pA->sign == 0 )
      return 0;

   hbnum_native_init( &nAA );
   hbnum_native_init( &nBB );

   if( !hbnum_native_align_scales( pA, pB, &nAA, &nBB, &nScale ) )
      return 0;

   HB_SYMBOL_UNUSED( nScale );
   nResult = hbnum_mag_cmp( nAA.limbs, nAA.used, nBB.limbs, nBB.used );

   hbnum_native_release( &nAA );
   hbnum_native_release( &nBB );

   if( pA->sign < 0 )
      nResult = -nResult;

   return nResult;
}

static char * hbnum_strdup( const char * szText )
{
   HB_SIZE nLen = ( HB_SIZE ) strlen( szText );
   char * szCopy = ( char * ) hb_xgrab( nLen + 1 );

   memcpy( szCopy, szText, nLen + 1 );
   return szCopy;
}

char * hbnum_native_to_string( const HBNumNative * pNum )
{
   HB_U32 * pWork;
   HB_SIZE nWorkUsed;
   HB_U32 * pChunks;
   HB_SIZE nChunkCap;
   HB_SIZE nChunks = 0;
   char szBuf[ 32 ];
   HB_SIZE nDigitsLen;
   char * szDigits;
   HB_SIZE nPos = 0;
   HB_SIZE nScale = pNum->scale;
   HB_SIZE nBodyLen;
   char * szOut;
   HB_SIZE nPad = 0;
   HB_SIZE nIntLen = 0;

   if( pNum->used == 0 )
      return hbnum_strdup( "0" );

   pWork = hbnum_limbs_dup( pNum->limbs, pNum->used );
   nWorkUsed = pNum->used;

   nChunkCap = pNum->used * 2 + 2;
   pChunks = ( HB_U32 * ) hb_xgrab( sizeof( HB_U32 ) * nChunkCap );

   while( nWorkUsed > 0 )
      pChunks[ nChunks++ ] = hbnum_mag_div_small_inplace( pWork, &nWorkUsed, HBNUM_DEC_CHUNK );

   hb_xfree( pWork );

   hb_snprintf( szBuf, sizeof( szBuf ), "%u", pChunks[ nChunks - 1 ] );
   nDigitsLen = ( HB_SIZE ) strlen( szBuf ) + ( nChunks - 1 ) * 9;

   szDigits = ( char * ) hb_xgrab( nDigitsLen + 1 );
   memcpy( szDigits, szBuf, strlen( szBuf ) );
   nPos = ( HB_SIZE ) strlen( szBuf );

   while( nChunks > 1 )
   {
      --nChunks;
      hb_snprintf( szBuf, sizeof( szBuf ), "%09u", pChunks[ nChunks - 1 ] );
      memcpy( szDigits + nPos, szBuf, 9 );
      nPos += 9;
   }

   szDigits[ nPos ] = '\0';
   hb_xfree( pChunks );

   if( nScale == 0 )
   {
      nBodyLen = nDigitsLen;
   }
   else if( nScale >= nDigitsLen )
   {
      nPad = nScale - nDigitsLen;
      nBodyLen = 2 + nPad + nDigitsLen;
   }
   else
   {
      nBodyLen = nDigitsLen + 1;
   }

   szOut = ( char * ) hb_xgrab( nBodyLen + ( pNum->sign < 0 ? 2 : 1 ) );
   nPos = 0;

   if( pNum->sign < 0 )
      szOut[ nPos++ ] = '-';

   if( nScale == 0 )
   {
      memcpy( szOut + nPos, szDigits, nDigitsLen );
      nPos += nDigitsLen;
   }
   else if( nScale >= nDigitsLen )
   {
      szOut[ nPos++ ] = '0';
      szOut[ nPos++ ] = '.';
      memset( szOut + nPos, '0', nPad );
      nPos += nPad;
      memcpy( szOut + nPos, szDigits, nDigitsLen );
      nPos += nDigitsLen;
   }
   else
   {
      nIntLen = nDigitsLen - nScale;
      memcpy( szOut + nPos, szDigits, nIntLen );
      nPos += nIntLen;
      szOut[ nPos++ ] = '.';
      memcpy( szOut + nPos, szDigits + nIntLen, nScale );
      nPos += nScale;
   }

   szOut[ nPos ] = '\0';
   hb_xfree( szDigits );

   return szOut;
}

static HB_BOOL hbnum_parse_decimal( const char * szValue, HBNumNative * pOut )
{
   const char * szBegin = szValue != NULL ? szValue : "";
   const char * szEnd;
   int nSign = 1;
   HB_BOOL fDot = HB_FALSE;
   HB_SIZE nDigits = 0;
   HB_SIZE nScale = 0;
   HB_SIZE nPos;
   char * szDigits;
   HB_SIZE nDigitPos = 0;
   HB_SIZE nFirstNonZero = 0;
   HB_U32 * pLimbs;
   HB_SIZE nCap;
   HB_SIZE nUsed = 0;

   hbnum_native_init( pOut );

   while( *szBegin != '\0' && isspace( ( unsigned char ) *szBegin ) )
      ++szBegin;

   szEnd = szBegin + strlen( szBegin );
   while( szEnd > szBegin && isspace( ( unsigned char ) *( szEnd - 1 ) ) )
      --szEnd;

   if( szBegin < szEnd && ( *szBegin == '+' || *szBegin == '-' ) )
   {
      if( *szBegin == '-' )
         nSign = -1;
      ++szBegin;
   }

   for( ; szBegin < szEnd; ++szBegin )
   {
      if( *szBegin >= '0' && *szBegin <= '9' )
      {
         ++nDigits;
         if( fDot )
            ++nScale;
      }
      else if( *szBegin == '.' && !fDot )
      {
         fDot = HB_TRUE;
      }
      else
      {
         return HB_FALSE;
      }
   }

   if( nDigits == 0 )
      return HB_TRUE;

   szDigits = ( char * ) hb_xgrab( nDigits + 1 );
   szBegin = szValue != NULL ? szValue : "";

   while( *szBegin != '\0' && isspace( ( unsigned char ) *szBegin ) )
      ++szBegin;

   if( *szBegin == '+' || *szBegin == '-' )
      ++szBegin;

   for( ; *szBegin != '\0'; ++szBegin )
   {
      if( *szBegin >= '0' && *szBegin <= '9' )
         szDigits[ nDigitPos++ ] = *szBegin;
      else if( *szBegin == '.' || isspace( ( unsigned char ) *szBegin ) )
      {
      }
      else
      {
         hb_xfree( szDigits );
         return HB_FALSE;
      }
   }

   szDigits[ nDigitPos ] = '\0';

   while( nFirstNonZero < nDigits && szDigits[ nFirstNonZero ] == '0' )
      ++nFirstNonZero;

   if( nFirstNonZero == nDigits )
   {
      hb_xfree( szDigits );
      return HB_TRUE;
   }

   nCap = ( nDigits - nFirstNonZero ) / 8 + 8;
   pLimbs = ( HB_U32 * ) hb_xgrab( sizeof( HB_U32 ) * nCap );
   memset( pLimbs, 0, sizeof( HB_U32 ) * nCap );

   for( nPos = nFirstNonZero; nPos < nDigits; ++nPos )
   {
      HB_U32 nDigit = ( HB_U32 ) ( szDigits[ nPos ] - '0' );
      HB_U64 nCarry = nDigit;
      HB_SIZE nLimbPos;

      for( nLimbPos = 0; nLimbPos < nUsed; ++nLimbPos )
      {
         HB_U64 nValue = ( HB_U64 ) pLimbs[ nLimbPos ] * 10 + nCarry;

         pLimbs[ nLimbPos ] = ( HB_U32 ) ( nValue & HBNUM_MASK );
         nCarry = nValue >> HBNUM_LIMB_BITS;
      }

      while( nCarry != 0 )
      {
         if( nUsed >= nCap )
         {
            hb_xfree( pLimbs );
            hb_xfree( szDigits );
            return HB_FALSE;
         }

         pLimbs[ nUsed ] = ( HB_U32 ) ( nCarry & HBNUM_MASK );
         nCarry >>= HBNUM_LIMB_BITS;
         ++nUsed;
      }
   }

   hb_xfree( szDigits );

   pOut->sign = nSign;
   pOut->scale = nScale;
   pOut->used = nUsed;
   pOut->limbs = pLimbs;
   hbnum_native_normalize( pOut );
   return HB_TRUE;
}

HB_BOOL hbnum_native_from_hash( PHB_ITEM pHash, HBNumNative * pOut )
{
   PHB_ITEM pSign;
   PHB_ITEM pScale;
   PHB_ITEM pUsed;
   PHB_ITEM pLimbs;
   HB_ISIZ nScale;
   HB_ISIZ nUsedRaw;
   HB_SIZE nArrayLen;
   HB_SIZE nRequestedUsed;
   HB_SIZE nUsed;
   HB_SIZE nPos;

   hbnum_native_init( pOut );

   if( pHash == NULL || !HB_IS_HASH( pHash ) )
      return HB_FALSE;

   pSign = hb_hashGetCItemPtr( pHash, HBNUM_SIGN );
   pScale = hb_hashGetCItemPtr( pHash, HBNUM_SCALE );
   pUsed = hb_hashGetCItemPtr( pHash, HBNUM_USED );
   pLimbs = hb_hashGetCItemPtr( pHash, HBNUM_LIMBS );

   pOut->sign = pSign != NULL ? hb_itemGetNI( pSign ) : 0;
   nScale = pScale != NULL ? hb_itemGetNS( pScale ) : 0;
   pOut->scale = nScale > 0 ? ( HB_SIZE ) nScale : 0;

   if( pLimbs == NULL || !HB_IS_ARRAY( pLimbs ) )
      return HB_TRUE;

   nArrayLen = hb_arrayLen( pLimbs );
   nUsedRaw = pUsed != NULL ? hb_itemGetNS( pUsed ) : ( HB_ISIZ ) nArrayLen;
   nRequestedUsed = nUsedRaw > 0 ? ( HB_SIZE ) nUsedRaw : 0;
   nUsed = nRequestedUsed < nArrayLen ? nRequestedUsed : nArrayLen;

   if( nUsed == 0 )
      return HB_TRUE;

   pOut->limbs = ( HB_U32 * ) hb_xgrab( sizeof( HB_U32 ) * nUsed );
   pOut->used = nUsed;

   for( nPos = 0; nPos < nUsed; ++nPos )
   {
      HB_LONG nLimb = hb_arrayGetNI( pLimbs, nPos + 1 );

      if( nLimb < 0 || ( HB_U32 ) nLimb >= HBNUM_BASE )
         pOut->limbs[ nPos ] = 0;
      else
         pOut->limbs[ nPos ] = ( HB_U32 ) nLimb;
   }

   hbnum_native_normalize( pOut );
   return HB_TRUE;
}

static void hbnum_hash_add( PHB_ITEM pHash, const char * szKey, PHB_ITEM pValue )
{
   PHB_ITEM pKey = hb_itemNew( NULL );

   hb_itemPutC( pKey, szKey );
   hb_hashAdd( pHash, pKey, pValue );
   hb_itemRelease( pKey );
}

PHB_ITEM hbnum_native_to_hash( const HBNumNative * pNum )
{
   PHB_ITEM pHash = hb_itemNew( NULL );
   PHB_ITEM pSign = hb_itemPutNI( hb_itemNew( NULL ), pNum->sign );
   PHB_ITEM pScale = hb_itemPutNS( hb_itemNew( NULL ), pNum->scale );
   PHB_ITEM pUsed = hb_itemPutNS( hb_itemNew( NULL ), pNum->used );
   PHB_ITEM pLimbs = hb_itemArrayNew( pNum->used );
   HB_SIZE nPos;

   hb_hashNew( pHash );

   for( nPos = 0; nPos < pNum->used; ++nPos )
      hb_arraySetNI( pLimbs, nPos + 1, ( int ) pNum->limbs[ nPos ] );

   hbnum_hash_add( pHash, HBNUM_SIGN, pSign );
   hbnum_hash_add( pHash, HBNUM_SCALE, pScale );
   hbnum_hash_add( pHash, HBNUM_USED, pUsed );
   hbnum_hash_add( pHash, HBNUM_LIMBS, pLimbs );

   hb_itemRelease( pSign );
   hb_itemRelease( pScale );
   hb_itemRelease( pUsed );
   hb_itemRelease( pLimbs );

   return pHash;
}

HB_FUNC( HBNUM_CORE_FROMSTRING )
{
   const char * szValue = hb_parc( hb_param( 1, HB_IT_HASH ) != NULL ? 2 : 1 );
   HBNumNative nValue;
   PHB_ITEM pHash;

   hbnum_parse_decimal( szValue, &nValue );
   pHash = hbnum_native_to_hash( &nValue );
   hb_itemReturnRelease( pHash );
   hbnum_native_release( &nValue );
}

HB_FUNC( HBNUM_CORE_TOSTRING )
{
   PHB_ITEM pHash = hb_param( 1, HB_IT_HASH );
   HBNumNative nValue;
   char * szValue;

   if( !hbnum_native_from_hash( pHash, &nValue ) )
   {
      hb_retc( "0" );
      return;
   }

   szValue = hbnum_native_to_string( &nValue );
   hb_retc( szValue );

   hb_xfree( szValue );
   hbnum_native_release( &nValue );
}

HB_FUNC( HBNUM_CORE_CLONE )
{
   PHB_ITEM pHash = hb_param( 1, HB_IT_HASH );
   HBNumNative nValue;
   PHB_ITEM pResult;

   hbnum_native_from_hash( pHash, &nValue );
   hbnum_native_normalize( &nValue );

   pResult = hbnum_native_to_hash( &nValue );
   hb_itemReturnRelease( pResult );
   hbnum_native_release( &nValue );
}

HB_FUNC( HBNUM_CORE_NORMALIZE )
{
   PHB_ITEM pHash = hb_param( 1, HB_IT_HASH );
   HBNumNative nValue;
   PHB_ITEM pResult;

   hbnum_native_from_hash( pHash, &nValue );
   hbnum_native_normalize( &nValue );

   pResult = hbnum_native_to_hash( &nValue );
   hb_itemReturnRelease( pResult );
   hbnum_native_release( &nValue );
}

HB_FUNC( HBNUM_CORE_COMPARE )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   PHB_ITEM pB = hb_param( 2, HB_IT_HASH );
   HBNumNative nA;
   HBNumNative nB;
   int nResult = 0;

   hbnum_native_from_hash( pA, &nA );
   hbnum_native_from_hash( pB, &nB );

   nResult = hbnum_native_compare( &nA, &nB );

   hb_retni( nResult );
   hbnum_native_release( &nA );
   hbnum_native_release( &nB );
}

HB_FUNC( HBNUM_CORE_ADD )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   PHB_ITEM pB = hb_param( 2, HB_IT_HASH );
   HBNumNative nA;
   HBNumNative nB;
   HBNumNative nResult;
   PHB_ITEM pHashResult;

   hbnum_native_from_hash( pA, &nA );
   hbnum_native_from_hash( pB, &nB );
   hbnum_native_add( &nA, &nB, &nResult );

   pHashResult = hbnum_native_to_hash( &nResult );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nA );
   hbnum_native_release( &nB );
   hbnum_native_release( &nResult );
}

HB_FUNC( HBNUM_CORE_SUB )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   PHB_ITEM pB = hb_param( 2, HB_IT_HASH );
   HBNumNative nA;
   HBNumNative nB;
   HBNumNative nResult;
   PHB_ITEM pHashResult;

   hbnum_native_from_hash( pA, &nA );
   hbnum_native_from_hash( pB, &nB );
   hbnum_native_sub( &nA, &nB, &nResult );

   pHashResult = hbnum_native_to_hash( &nResult );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nA );
   hbnum_native_release( &nB );
   hbnum_native_release( &nResult );
}

HB_FUNC( HBNUM_CORE_MUL )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   PHB_ITEM pB = hb_param( 2, HB_IT_HASH );
   HBNumNative nA;
   HBNumNative nB;
   HBNumNative nResult;
   PHB_ITEM pHashResult;

   hbnum_native_from_hash( pA, &nA );
   hbnum_native_from_hash( pB, &nB );
   hbnum_native_mul( &nA, &nB, &nResult );

   pHashResult = hbnum_native_to_hash( &nResult );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nA );
   hbnum_native_release( &nB );
   hbnum_native_release( &nResult );
}

HB_FUNC( HBNUM_CORE_DIV )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   PHB_ITEM pB = hb_param( 2, HB_IT_HASH );
   HB_SIZE nPrecision = hb_parns( 3 );
   HBNumNative nA;
   HBNumNative nB;
   HBNumNative nResult;
   PHB_ITEM pHashResult;
   HB_BOOL fOk;

   hbnum_native_from_hash( pA, &nA );
   hbnum_native_from_hash( pB, &nB );

   fOk = hbnum_native_div( &nA, &nB, nPrecision, &nResult );
   if( !fOk )
   {
      hbnum_native_init( &nResult );
      hb_errRT_BASE( EG_ZERODIV, 0, "Division by zero", HB_ERR_FUNCNAME, 0 );
   }

   pHashResult = hbnum_native_to_hash( &nResult );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nA );
   hbnum_native_release( &nB );
   hbnum_native_release( &nResult );
}

HB_FUNC( HBNUM_CORE_DIV_AUTO )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   PHB_ITEM pB = hb_param( 2, HB_IT_HASH );
   HBNumNative nA;
   HBNumNative nB;
   HBNumNative nResult;
   PHB_ITEM pHashResult;
   HB_BOOL fOk;

   hbnum_native_init( &nA );
   hbnum_native_init( &nB );
   hbnum_native_init( &nResult );

   hbnum_native_from_hash( pA, &nA );
   hbnum_native_from_hash( pB, &nB );

   fOk = hbnum_native_div_exact( &nA, &nB, &nResult );
   if( !fOk )
   {
      hbnum_native_init( &nResult );
      if( nB.used == 0 )
         hb_errRT_BASE( EG_ZERODIV, 0, "Division by zero", HB_ERR_FUNCNAME, 0 );
      else
         hb_errRT_BASE( EG_ARG, 0, "Non-terminating decimal division requires explicit precision or HBNumContext precision", HB_ERR_FUNCNAME, 0 );
   }

   pHashResult = hbnum_native_to_hash( &nResult );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nA );
   hbnum_native_release( &nB );
   hbnum_native_release( &nResult );
}

HB_FUNC( HBNUM_CORE_ABS )
{
   PHB_ITEM pHash = hb_param( 1, HB_IT_HASH );
   HBNumNative nValue;
   PHB_ITEM pResult;

   hbnum_native_from_hash( pHash, &nValue );

   if( nValue.used > 0 )
      nValue.sign = 1;
   else
      nValue.sign = 0;

   hbnum_native_normalize( &nValue );
   pResult = hbnum_native_to_hash( &nValue );
   hb_itemReturnRelease( pResult );
   hbnum_native_release( &nValue );
}

HB_FUNC( HBNUM_CORE_NEG )
{
   PHB_ITEM pHash = hb_param( 1, HB_IT_HASH );
   HBNumNative nValue;
   PHB_ITEM pResult;

   hbnum_native_from_hash( pHash, &nValue );

   if( nValue.used > 0 )
      nValue.sign = -nValue.sign;

   hbnum_native_normalize( &nValue );
   pResult = hbnum_native_to_hash( &nValue );
   hb_itemReturnRelease( pResult );
   hbnum_native_release( &nValue );
}

HB_FUNC( HBNUM_CORE_ISZERO )
{
   PHB_ITEM pHash = hb_param( 1, HB_IT_HASH );
   HBNumNative nValue;

   hbnum_native_from_hash( pHash, &nValue );
   hb_retl( nValue.used == 0 );
   hbnum_native_release( &nValue );
}

HB_FUNC( HB_NUM_TEST_ADD )
{
   const char * szA = hb_parc( 1 );
   const char * szB = hb_parc( 2 );
   HBNumNative nA;
   HBNumNative nB;
   HBNumNative nResult;
   char * szOut;

   hbnum_parse_decimal( szA, &nA );
   hbnum_parse_decimal( szB, &nB );
   hbnum_native_add( &nA, &nB, &nResult );

   szOut = hbnum_native_to_string( &nResult );
   hb_retc( szOut );

   hb_xfree( szOut );
   hbnum_native_release( &nA );
   hbnum_native_release( &nB );
   hbnum_native_release( &nResult );
}
