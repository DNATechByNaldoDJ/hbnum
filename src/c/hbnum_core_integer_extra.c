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

#define HBNUM_RANDOM_DEFAULT_MAX "99999999999999999999999999999999"
#define HBNUM_MR_DEFAULT_ROUNDS  2

static HB_BOOL hbnum_native_is_integer( const HBNumNative * pNum )
{
   return pNum->used == 0 || pNum->scale == 0;
}

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

static void hbnum_native_replace( HBNumNative * pDst, HBNumNative * pSrc )
{
   hbnum_native_release( pDst );
   *pDst = *pSrc;
   hbnum_native_init( pSrc );
}

static HB_BOOL hbnum_native_is_zero_value( const HBNumNative * pNum )
{
   return pNum->used == 0;
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

static HB_BOOL hbnum_native_is_even_value( const HBNumNative * pNum )
{
   return pNum->used == 0 || ( pNum->limbs[ 0 ] & 1U ) == 0;
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

static HB_BOOL hbnum_native_mod_int( const HBNumNative * pA, const HBNumNative * pB, HBNumNative * pResult )
{
   return hbnum_native_mod( pA, pB, pResult );
}

static HB_BOOL hbnum_native_set_integer_text( const char * szText, HBNumNative * pNum )
{
   HBNumNative nTmp;
   HBNumNative nDigit;
   int iSign;

   hbnum_native_init( pNum );
   hbnum_native_init( &nTmp );
   hbnum_native_init( &nDigit );

   if( szText == NULL || *szText == '\0' )
      return HB_FALSE;

   iSign = 1;

   if( *szText == '+' )
      ++szText;
   else if( *szText == '-' )
   {
      iSign = -1;
      ++szText;
   }

   if( *szText == '\0' )
      return HB_FALSE;

   while( *szText != '\0' )
   {
      if( *szText < '0' || *szText > '9' )
      {
         hbnum_native_release( &nTmp );
         hbnum_native_release( &nDigit );
         hbnum_native_release( pNum );
         hbnum_native_init( pNum );
         return HB_FALSE;
      }

      hbnum_native_mul_small( pNum, 10, &nTmp );
      hbnum_native_replace( pNum, &nTmp );

      if( *szText != '0' )
      {
         hbnum_native_set_small( ( HB_MAXINT ) ( *szText - '0' ), &nDigit );
         hbnum_native_add( pNum, &nDigit, &nTmp );
         hbnum_native_replace( pNum, &nTmp );
         hbnum_native_release( &nDigit );
         hbnum_native_init( &nDigit );
      }

      ++szText;
   }

   if( iSign < 0 && pNum->used > 0 )
      pNum->sign = -1;

   hbnum_native_release( &nTmp );
   hbnum_native_release( &nDigit );
   return HB_TRUE;
}

static HB_BOOL hbnum_native_integer_clone( const HBNumNative * pSrc, HBNumNative * pDst )
{
   if( ! hbnum_native_is_integer( pSrc ) )
      return HB_FALSE;

   return hbnum_native_clone( pSrc, pDst );
}

static int hbnum_native_random_digit( int nMaxDigit )
{
   int nDigit = ( int ) ( hb_random_num_secure() * ( double ) ( nMaxDigit + 1 ) );

   if( nDigit > nMaxDigit )
      nDigit = nMaxDigit;

   return nDigit;
}

static HB_BOOL hbnum_native_random_below( const HBNumNative * pMax, HBNumNative * pResult )
{
   char * szMax;
   HB_SIZE nDigits;
   HB_SIZE nPos;
   HBNumNative nTmp;
   HBNumNative nDigit;

   hbnum_native_init( pResult );
   hbnum_native_init( &nTmp );
   hbnum_native_init( &nDigit );

   if( hbnum_native_is_zero_value( pMax ) )
      return HB_TRUE;

   szMax = hbnum_native_to_string( pMax );
   nDigits = ( HB_SIZE ) strlen( szMax );

   do
   {
      hbnum_native_release( pResult );
      hbnum_native_init( pResult );

      for( nPos = 0; nPos < nDigits; ++nPos )
      {
         int nValue = hbnum_native_random_digit( 9 );

         hbnum_native_mul_small( pResult, 10, &nTmp );
         hbnum_native_replace( pResult, &nTmp );

         if( nValue > 0 )
         {
            hbnum_native_set_small( ( HB_MAXINT ) nValue, &nDigit );
            hbnum_native_add( pResult, &nDigit, &nTmp );
            hbnum_native_replace( pResult, &nTmp );
            hbnum_native_release( &nDigit );
            hbnum_native_init( &nDigit );
         }
      }
   }
   while( hbnum_native_compare( pResult, pMax ) > 0 );

   hb_xfree( szMax );
   hbnum_native_release( &nTmp );
   hbnum_native_release( &nDigit );
   return HB_TRUE;
}

static HB_BOOL hbnum_native_random_range( const HBNumNative * pMin, const HBNumNative * pMax, HBNumNative * pResult )
{
   HBNumNative nMin;
   HBNumNative nMax;
   HBNumNative nTmp;
   HBNumNative nRange;
   HBNumNative nOffset;

   hbnum_native_init( pResult );
   hbnum_native_init( &nMin );
   hbnum_native_init( &nMax );
   hbnum_native_init( &nTmp );
   hbnum_native_init( &nRange );
   hbnum_native_init( &nOffset );

   if( ! hbnum_native_integer_clone( pMin, &nMin ) || ! hbnum_native_integer_clone( pMax, &nMax ) )
      goto failure;

   if( hbnum_native_compare( &nMin, &nMax ) > 0 )
   {
      hbnum_native_clone( &nMin, &nTmp );
      hbnum_native_release( &nMin );
      hbnum_native_clone( &nMax, &nMin );
      hbnum_native_release( &nMax );
      hbnum_native_clone( &nTmp, &nMax );
      hbnum_native_release( &nTmp );
   }

   hbnum_native_sub( &nMax, &nMin, &nRange );

   if( hbnum_native_is_zero_value( &nRange ) )
   {
      hbnum_native_clone( &nMin, pResult );
      goto done;
   }

   hbnum_native_random_below( &nRange, &nOffset );
   hbnum_native_add( &nMin, &nOffset, pResult );

done:
   hbnum_native_release( &nMin );
   hbnum_native_release( &nMax );
   hbnum_native_release( &nTmp );
   hbnum_native_release( &nRange );
   hbnum_native_release( &nOffset );
   return HB_TRUE;

failure:
   hbnum_native_release( pResult );
   hbnum_native_init( pResult );
   hbnum_native_release( &nMin );
   hbnum_native_release( &nMax );
   hbnum_native_release( &nTmp );
   hbnum_native_release( &nRange );
   hbnum_native_release( &nOffset );
   return HB_FALSE;
}

static HB_BOOL hbnum_native_factorial_int( const HBNumNative * pA, HBNumNative * pResult )
{
   HBNumNative nValue;
   HBNumNative nCounter;
   HBNumNative nAcc;
   HBNumNative nTmp;

   hbnum_native_init( pResult );
   hbnum_native_init( &nValue );
   hbnum_native_init( &nCounter );
   hbnum_native_init( &nAcc );
   hbnum_native_init( &nTmp );

   if( ! hbnum_native_integer_clone( pA, &nValue ) || nValue.sign < 0 )
      goto failure;

   if( hbnum_native_is_zero_value( &nValue ) || hbnum_native_is_one_value( &nValue ) )
   {
      hbnum_native_set_one( pResult );
      goto done;
   }

   hbnum_native_set_one( &nAcc );
   hbnum_native_set_small( 2, &nCounter );

   while( hbnum_native_compare( &nCounter, &nValue ) <= 0 )
   {
      hbnum_native_mul( &nAcc, &nCounter, &nTmp );
      hbnum_native_replace( &nAcc, &nTmp );
      hbnum_native_increment_one( &nCounter );
   }

   hbnum_native_clone( &nAcc, pResult );
   goto done;

failure:
   hbnum_native_release( pResult );
   hbnum_native_init( pResult );

done:
   hbnum_native_release( &nValue );
   hbnum_native_release( &nCounter );
   hbnum_native_release( &nAcc );
   hbnum_native_release( &nTmp );
   return pResult->used > 0 || hbnum_native_is_zero_value( pResult );
}

static HB_BOOL hbnum_native_fi_int( const HBNumNative * pA, HBNumNative * pResult )
{
   HBNumNative nN;
   HBNumNative nPhi;
   HBNumNative nI;
   HBNumNative nSquare;
   HBNumNative nMod;
   HBNumNative nDiv;
   HBNumNative nTmp;

   hbnum_native_init( pResult );
   hbnum_native_init( &nN );
   hbnum_native_init( &nPhi );
   hbnum_native_init( &nI );
   hbnum_native_init( &nSquare );
   hbnum_native_init( &nMod );
   hbnum_native_init( &nDiv );
   hbnum_native_init( &nTmp );

   if( ! hbnum_native_integer_clone( pA, &nN ) || nN.sign < 0 )
      goto failure;

   if( hbnum_native_is_zero_value( &nN ) )
      goto done;

   hbnum_native_clone( &nN, &nPhi );
   hbnum_native_set_small( 2, &nI );

   while( HB_TRUE )
   {
      hbnum_native_mul( &nI, &nI, &nSquare );
      if( hbnum_native_compare( &nSquare, &nN ) > 0 )
         break;
      hbnum_native_release( &nSquare );
      hbnum_native_init( &nSquare );

      hbnum_native_mod_int( &nN, &nI, &nMod );
      if( hbnum_native_is_zero_value( &nMod ) )
      {
         hbnum_native_div( &nPhi, &nI, 0, &nDiv );
         hbnum_native_sub( &nPhi, &nDiv, &nTmp );
         hbnum_native_replace( &nPhi, &nTmp );
         hbnum_native_release( &nDiv );
         hbnum_native_init( &nDiv );

         do
         {
            hbnum_native_div( &nN, &nI, 0, &nTmp );
            hbnum_native_replace( &nN, &nTmp );
            hbnum_native_mod_int( &nN, &nI, &nMod );
         }
         while( hbnum_native_is_zero_value( &nMod ) );
      }

      hbnum_native_release( &nMod );
      hbnum_native_init( &nMod );
      hbnum_native_increment_one( &nI );
   }

   if( hbnum_native_compare( &nN, &nI ) >= 0 && ! hbnum_native_is_one_value( &nN ) )
   {
      hbnum_native_div( &nPhi, &nN, 0, &nDiv );
      hbnum_native_sub( &nPhi, &nDiv, &nTmp );
      hbnum_native_replace( &nPhi, &nTmp );
   }

   hbnum_native_clone( &nPhi, pResult );
   goto done;

failure:
   hbnum_native_release( pResult );
   hbnum_native_init( pResult );

done:
   hbnum_native_release( &nN );
   hbnum_native_release( &nPhi );
   hbnum_native_release( &nI );
   hbnum_native_release( &nSquare );
   hbnum_native_release( &nMod );
   hbnum_native_release( &nDiv );
   hbnum_native_release( &nTmp );
   return HB_TRUE;
}

static HB_BOOL hbnum_native_pow_mod( const HBNumNative * pBase, const HBNumNative * pExponent, const HBNumNative * pMod, HBNumNative * pResult )
{
   HBNumNative nBaseWork;
   HBNumNative nExp;
   HBNumNative nAcc;
   HBNumNative nTmp;
   HBNumNative nMul;

   hbnum_native_init( pResult );
   hbnum_native_init( &nBaseWork );
   hbnum_native_init( &nExp );
   hbnum_native_init( &nAcc );
   hbnum_native_init( &nTmp );
   hbnum_native_init( &nMul );

   if( ! hbnum_native_integer_clone( pExponent, &nExp ) )
      goto failure;

   hbnum_native_mod_int( pBase, pMod, &nBaseWork );
   hbnum_native_set_one( &nAcc );

   while( ! hbnum_native_is_zero_value( &nExp ) )
   {
      if( ! hbnum_native_is_even_value( &nExp ) )
      {
         hbnum_native_mul( &nAcc, &nBaseWork, &nMul );
         hbnum_native_mod_int( &nMul, pMod, &nTmp );
         hbnum_native_replace( &nAcc, &nTmp );
         hbnum_native_release( &nMul );
         hbnum_native_init( &nMul );
      }

      hbnum_native_div_small( &nExp, 2, 0, &nTmp );
      hbnum_native_replace( &nExp, &nTmp );

      if( ! hbnum_native_is_zero_value( &nExp ) )
      {
         hbnum_native_mul( &nBaseWork, &nBaseWork, &nMul );
         hbnum_native_mod_int( &nMul, pMod, &nTmp );
         hbnum_native_replace( &nBaseWork, &nTmp );
         hbnum_native_release( &nMul );
         hbnum_native_init( &nMul );
      }
   }

   hbnum_native_clone( &nAcc, pResult );
   goto done;

failure:
   hbnum_native_release( pResult );
   hbnum_native_init( pResult );

done:
   hbnum_native_release( &nBaseWork );
   hbnum_native_release( &nExp );
   hbnum_native_release( &nAcc );
   hbnum_native_release( &nTmp );
   hbnum_native_release( &nMul );
   return HB_TRUE;
}

static HB_BOOL hbnum_native_miller_rabin_int( const HBNumNative * pA, HB_SIZE nRounds )
{
   static const HB_MAXINT s_aWitnesses[] = { 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37 };
   HBNumNative nValue;
   HBNumNative nOne;
   HBNumNative nTwo;
   HBNumNative nThree;
   HBNumNative nFour;
   HBNumNative nNMinusOne;
   HBNumNative nNMinusTwo;
   HBNumNative nD;
   HBNumNative nWitness;
   HBNumNative nX;
   HBNumNative nTmp;
   HB_SIZE nS;
   HB_SIZE nRound;
   HB_BOOL fPrime;

   hbnum_native_init( &nValue );
   hbnum_native_init( &nOne );
   hbnum_native_init( &nTwo );
   hbnum_native_init( &nThree );
   hbnum_native_init( &nFour );
   hbnum_native_init( &nNMinusOne );
   hbnum_native_init( &nNMinusTwo );
   hbnum_native_init( &nD );
   hbnum_native_init( &nWitness );
   hbnum_native_init( &nX );
   hbnum_native_init( &nTmp );

   hbnum_native_set_one( &nOne );
   hbnum_native_set_small( 2, &nTwo );
   hbnum_native_set_small( 3, &nThree );
   hbnum_native_set_small( 4, &nFour );

   if( ! hbnum_native_integer_clone( pA, &nValue ) || nValue.sign <= 0 )
   {
      fPrime = HB_FALSE;
      goto done;
   }

   if( hbnum_native_compare( &nValue, &nTwo ) == 0 || hbnum_native_compare( &nValue, &nThree ) == 0 )
   {
      fPrime = HB_TRUE;
      goto done;
   }

   if( hbnum_native_compare( &nValue, &nTwo ) < 0 || hbnum_native_is_even_value( &nValue ) )
   {
      fPrime = HB_FALSE;
      goto done;
   }

   hbnum_native_sub( &nValue, &nOne, &nNMinusOne );
   hbnum_native_sub( &nValue, &nTwo, &nNMinusTwo );
   hbnum_native_clone( &nNMinusOne, &nD );

   nS = 0;
   while( hbnum_native_is_even_value( &nD ) )
   {
      hbnum_native_div_small( &nD, 2, 0, &nTmp );
      hbnum_native_replace( &nD, &nTmp );
      ++nS;
   }

   if( nRounds == 0 )
      nRounds = HBNUM_MR_DEFAULT_ROUNDS;

   fPrime = HB_TRUE;

   for( nRound = 0; nRound < nRounds; ++nRound )
   {
      HB_SIZE nStep;
      HB_BOOL fRoundPass;

      hbnum_native_release( &nWitness );
      hbnum_native_init( &nWitness );

      if( nRound < ( sizeof( s_aWitnesses ) / sizeof( s_aWitnesses[ 0 ] ) ) )
      {
         hbnum_native_set_small( s_aWitnesses[ nRound ], &nWitness );
         if( hbnum_native_compare( &nWitness, &nNMinusTwo ) > 0 )
         {
            hbnum_native_release( &nWitness );
            hbnum_native_clone( &nTwo, &nWitness );
         }
      }
      else
      {
         hbnum_native_random_range( &nTwo, &nNMinusTwo, &nWitness );
      }

      hbnum_native_pow_mod( &nWitness, &nD, &nValue, &nX );

      if( hbnum_native_compare( &nX, &nOne ) == 0 || hbnum_native_compare( &nX, &nNMinusOne ) == 0 )
         continue;

      fRoundPass = HB_FALSE;

      for( nStep = 1; nStep < nS; ++nStep )
      {
         hbnum_native_mul( &nX, &nX, &nTmp );
         hbnum_native_mod_int( &nTmp, &nValue, &nX );

         if( hbnum_native_compare( &nX, &nNMinusOne ) == 0 )
         {
            fRoundPass = HB_TRUE;
            break;
         }
      }

      if( ! fRoundPass )
      {
         fPrime = HB_FALSE;
         break;
      }
   }

done:
   hbnum_native_release( &nValue );
   hbnum_native_release( &nOne );
   hbnum_native_release( &nTwo );
   hbnum_native_release( &nThree );
   hbnum_native_release( &nFour );
   hbnum_native_release( &nNMinusOne );
   hbnum_native_release( &nNMinusTwo );
   hbnum_native_release( &nD );
   hbnum_native_release( &nWitness );
   hbnum_native_release( &nX );
   hbnum_native_release( &nTmp );
   return fPrime;
}

static HB_SIZE hbnum_native_rounds_param( void )
{
   PHB_ITEM pHashRounds = hb_param( 2, HB_IT_HASH );
   HB_SIZE nRounds = HBNUM_MR_DEFAULT_ROUNDS;

   if( hb_param( 2, HB_IT_NUMERIC ) != NULL )
   {
      nRounds = ( HB_SIZE ) hb_parns( 2 );
   }
   else if( pHashRounds != NULL )
   {
      HBNumNative nRoundsValue;
      HB_MAXINT nRawRounds;

      hbnum_native_init( &nRoundsValue );
      hbnum_native_from_hash( pHashRounds, &nRoundsValue );

      if( hbnum_native_to_small_int( &nRoundsValue, &nRawRounds ) && nRawRounds > 0 )
         nRounds = ( HB_SIZE ) nRawRounds;

      hbnum_native_release( &nRoundsValue );
   }

   if( nRounds == 0 )
      nRounds = HBNUM_MR_DEFAULT_ROUNDS;

   return nRounds;
}

HB_FUNC( HBNUM_CORE_FACTORIAL )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   HBNumNative nA;
   HBNumNative nResult;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nA );
   hbnum_native_init( &nResult );

   hbnum_native_from_hash( pA, &nA );

   if( ! hbnum_native_is_integer( &nA ) )
   {
      hbnum_native_release( &nA );
      hbnum_native_release( &nResult );
      hb_errRT_BASE( EG_ARG, 0, "Factorial requires integer operand (scale = 0)", HB_ERR_FUNCNAME, 0 );
      return;
   }

   if( nA.sign < 0 )
   {
      hbnum_native_release( &nA );
      hbnum_native_release( &nResult );
      hb_errRT_BASE( EG_ARG, 0, "Factorial requires non-negative operand", HB_ERR_FUNCNAME, 0 );
      return;
   }

   hbnum_native_factorial_int( &nA, &nResult );
   pHashResult = hbnum_native_to_hash( &nResult );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nA );
   hbnum_native_release( &nResult );
}

HB_FUNC( HBNUM_CORE_FI )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   HBNumNative nA;
   HBNumNative nResult;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nA );
   hbnum_native_init( &nResult );

   hbnum_native_from_hash( pA, &nA );

   if( ! hbnum_native_is_integer( &nA ) )
   {
      hbnum_native_release( &nA );
      hbnum_native_release( &nResult );
      hb_errRT_BASE( EG_ARG, 0, "Fi requires integer operand (scale = 0)", HB_ERR_FUNCNAME, 0 );
      return;
   }

   if( nA.sign < 0 )
   {
      hbnum_native_release( &nA );
      hbnum_native_release( &nResult );
      hb_errRT_BASE( EG_ARG, 0, "Fi requires non-negative operand", HB_ERR_FUNCNAME, 0 );
      return;
   }

   hbnum_native_fi_int( &nA, &nResult );
   pHashResult = hbnum_native_to_hash( &nResult );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nA );
   hbnum_native_release( &nResult );
}

HB_FUNC( HBNUM_CORE_MILLERRABIN )
{
   PHB_ITEM pA = hb_param( 1, HB_IT_HASH );
   HBNumNative nA;
   HB_SIZE nRounds;

   hbnum_native_init( &nA );
   hbnum_native_from_hash( pA, &nA );

   if( ! hbnum_native_is_integer( &nA ) )
   {
      hbnum_native_release( &nA );
      hb_errRT_BASE( EG_ARG, 0, "MillerRabin requires integer operand (scale = 0)", HB_ERR_FUNCNAME, 0 );
      return;
   }

   nRounds = hbnum_native_rounds_param();
   hb_retl( hbnum_native_miller_rabin_int( &nA, nRounds ) );
   hbnum_native_release( &nA );
}

HB_FUNC( HBNUM_CORE_RANDOMIZE )
{
   PHB_ITEM pMinHash = hb_param( 1, HB_IT_HASH );
   PHB_ITEM pMaxHash = hb_param( 2, HB_IT_HASH );
   HBNumNative nMin;
   HBNumNative nMax;
   HBNumNative nResult;
   HBNumNative nTmp;
   PHB_ITEM pHashResult;

   hbnum_native_init( &nMin );
   hbnum_native_init( &nMax );
   hbnum_native_init( &nResult );
   hbnum_native_init( &nTmp );

   if( pMinHash != NULL )
   {
      hbnum_native_from_hash( pMinHash, &nTmp );
      hbnum_native_truncate( &nTmp, 0, &nMin );
      hbnum_native_release( &nTmp );
      hbnum_native_init( &nTmp );
   }
   else
   {
      hbnum_native_set_one( &nMin );
   }

   if( pMaxHash != NULL )
   {
      hbnum_native_from_hash( pMaxHash, &nTmp );
      hbnum_native_truncate( &nTmp, 0, &nMax );
      hbnum_native_release( &nTmp );
      hbnum_native_init( &nTmp );
   }
   else
   {
      hbnum_native_set_integer_text( HBNUM_RANDOM_DEFAULT_MAX, &nMax );
   }

   hbnum_native_random_range( &nMin, &nMax, &nResult );
   pHashResult = hbnum_native_to_hash( &nResult );
   hb_itemReturnRelease( pHashResult );

   hbnum_native_release( &nMin );
   hbnum_native_release( &nMax );
   hbnum_native_release( &nResult );
   hbnum_native_release( &nTmp );
}
