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

#include "hbnum_native_internal.h"

#include <string.h>

static char * hbnum_format_exp_text( HB_MAXINT nExponent )
{
   char szDigits[ 64 ];
   HB_SIZE nDigits = 0;
   HB_BOOL fNegative = nExponent < 0;
   HB_MAXUINT nValue = fNegative ?
      ( ( HB_MAXUINT ) -( nExponent + 1 ) ) + 1 :
      ( HB_MAXUINT ) nExponent;
   char * szText;
   HB_SIZE nPos = 0;

   do
   {
      szDigits[ nDigits++ ] = ( char ) ( '0' + ( nValue % 10 ) );
      nValue /= 10;
   }
   while( nValue > 0 );

   szText = ( char * ) hb_xgrab( nDigits + 3 );
   szText[ nPos++ ] = 'E';
   szText[ nPos++ ] = fNegative ? '-' : '+';

   while( nDigits > 0 )
      szText[ nPos++ ] = szDigits[ --nDigits ];

   szText[ nPos ] = '\0';
   return szText;
}

static HB_MAXINT hbnum_format_floor3( HB_MAXINT nValue )
{
   if( nValue >= 0 )
      return ( nValue / 3 ) * 3;

   return -( ( ( -nValue ) + 2 ) / 3 ) * 3;
}

static char * hbnum_format_zero( HB_SIZE nSignificantDigits )
{
   char * szOut;
   HB_SIZE nPos = 0;

   if( nSignificantDigits <= 1 )
   {
      szOut = ( char * ) hb_xgrab( 5 );
      memcpy( szOut, "0E+0", 5 );
      return szOut;
   }

   szOut = ( char * ) hb_xgrab( nSignificantDigits + 5 );
   szOut[ nPos++ ] = '0';
   szOut[ nPos++ ] = '.';
   memset( szOut + nPos, '0', nSignificantDigits - 1 );
   nPos += nSignificantDigits - 1;
   memcpy( szOut + nPos, "E+0", 4 );

   return szOut;
}

static HB_BOOL hbnum_format_extract_digits( const char * szValue, char ** pszDigits, HB_SIZE * pnDigits, HB_MAXINT * pnExponent, HB_BOOL * pfNegative )
{
   const char * szBody = szValue != NULL ? szValue : "";
   const char * szDot;
   const char * szFrac;
   const char * szInt;
   HB_SIZE nIntLen;
   HB_SIZE nFracLen = 0;
   HB_SIZE nPos;
   char * szDigits;

   *pszDigits = NULL;
   *pnDigits = 0;
   *pnExponent = 0;
   *pfNegative = HB_FALSE;

   if( *szBody == '-' )
   {
      *pfNegative = HB_TRUE;
      ++szBody;
   }
   else if( *szBody == '+' )
   {
      ++szBody;
   }

   szDot = strchr( szBody, '.' );
   nIntLen = szDot != NULL ? ( HB_SIZE ) ( szDot - szBody ) : ( HB_SIZE ) strlen( szBody );
   szFrac = szDot != NULL ? szDot + 1 : szBody + nIntLen;
   nFracLen = szDot != NULL ? ( HB_SIZE ) strlen( szFrac ) : 0;

   szInt = szBody;
   while( nIntLen > 1 && *szInt == '0' )
   {
      ++szInt;
      --nIntLen;
   }

   if( nIntLen > 0 && *szInt != '0' )
   {
      *pnExponent = ( HB_MAXINT ) nIntLen - 1;
      *pnDigits = nIntLen + nFracLen;
      szDigits = ( char * ) hb_xgrab( *pnDigits + 1 );
      memcpy( szDigits, szInt, nIntLen );
      if( nFracLen > 0 )
         memcpy( szDigits + nIntLen, szFrac, nFracLen );
   }
   else
   {
      nPos = 0;
      while( nPos < nFracLen && szFrac[ nPos ] == '0' )
         ++nPos;

      if( nPos == nFracLen )
         return HB_TRUE;

      *pnExponent = -( ( HB_MAXINT ) nPos + 1 );
      *pnDigits = nFracLen - nPos;
      szDigits = ( char * ) hb_xgrab( *pnDigits + 1 );
      memcpy( szDigits, szFrac + nPos, *pnDigits );
   }

   while( *pnDigits > 1 && szDigits[ *pnDigits - 1 ] == '0' )
      --( *pnDigits );

   szDigits[ *pnDigits ] = '\0';
   *pszDigits = szDigits;

   return HB_TRUE;
}

static void hbnum_format_apply_significant_digits( char ** pszDigits, HB_SIZE * pnDigits, HB_MAXINT * pnExponent, HB_SIZE nSignificantDigits )
{
   char * szOld;
   char * szNew;
   HB_SIZE nOldDigits;
   HB_SIZE nCopy;
   HB_SIZE nPos;

   if( nSignificantDigits == 0 )
      return;

   szOld = *pszDigits;
   nOldDigits = *pnDigits;
   nCopy = nOldDigits < nSignificantDigits ? nOldDigits : nSignificantDigits;
   szNew = ( char * ) hb_xgrab( nSignificantDigits + 1 );
   memset( szNew, '0', nSignificantDigits );

   if( nCopy > 0 )
      memcpy( szNew, szOld, nCopy );

   szNew[ nSignificantDigits ] = '\0';

   if( nOldDigits > nSignificantDigits && szOld[ nSignificantDigits ] >= '5' )
   {
      nPos = nSignificantDigits;
      while( nPos > 0 )
      {
         --nPos;
         if( szNew[ nPos ] < '9' )
         {
            ++szNew[ nPos ];
            break;
         }
         szNew[ nPos ] = '0';
      }

      if( nPos == 0 && szNew[ 0 ] == '0' )
      {
         szNew[ 0 ] = '1';
         if( nSignificantDigits > 1 )
            memset( szNew + 1, '0', nSignificantDigits - 1 );
         ++( *pnExponent );
      }
   }

   hb_xfree( szOld );
   *pszDigits = szNew;
   *pnDigits = nSignificantDigits;
}

static char * hbnum_format_build( const char * szDigits, HB_SIZE nDigits, HB_MAXINT nExponent, HB_BOOL fNegative, HB_BOOL fEngineering )
{
   HB_MAXINT nOutExponent = nExponent;
   HB_SIZE nIntDigits = 1;
   HB_SIZE nDecimalDigits;
   HB_SIZE nBodyLen;
   HB_SIZE nOutLen;
   HB_SIZE nPos = 0;
   HB_SIZE nDigit;
   char * szExponent;
   HB_SIZE nExponentLen;
   char * szOut;

   if( fEngineering )
   {
      nOutExponent = hbnum_format_floor3( nExponent );
      nIntDigits = ( HB_SIZE ) ( nExponent - nOutExponent + 1 );
   }

   nDecimalDigits = nDigits > nIntDigits ? nDigits - nIntDigits : 0;
   nBodyLen = nIntDigits + ( nDecimalDigits > 0 ? nDecimalDigits + 1 : 0 );
   szExponent = hbnum_format_exp_text( nOutExponent );
   nExponentLen = ( HB_SIZE ) strlen( szExponent );
   nOutLen = ( fNegative ? 1 : 0 ) + nBodyLen + nExponentLen;
   szOut = ( char * ) hb_xgrab( nOutLen + 1 );

   if( fNegative )
      szOut[ nPos++ ] = '-';

   for( nDigit = 0; nDigit < nIntDigits; ++nDigit )
      szOut[ nPos++ ] = nDigit < nDigits ? szDigits[ nDigit ] : '0';

   if( nDecimalDigits > 0 )
   {
      szOut[ nPos++ ] = '.';
      memcpy( szOut + nPos, szDigits + nIntDigits, nDecimalDigits );
      nPos += nDecimalDigits;
   }

   memcpy( szOut + nPos, szExponent, nExponentLen + 1 );
   hb_xfree( szExponent );

   return szOut;
}

static void hbnum_core_format_return( HB_BOOL fEngineering )
{
   PHB_ITEM pHash = hb_param( 1, HB_IT_HASH );
   HB_SIZE nSignificantDigits = 0;
   HBNumNative nValue;
   char * szValue;
   char * szDigits = NULL;
   char * szOut;
   HB_SIZE nDigits = 0;
   HB_MAXINT nExponent = 0;
   HB_BOOL fNegative = HB_FALSE;

   if( hb_param( 2, HB_IT_NUMERIC ) != NULL )
   {
      HB_MAXINT nRequested = hb_parnint( 2 );
      if( nRequested > 0 )
         nSignificantDigits = ( HB_SIZE ) nRequested;
   }

   if( !hbnum_native_from_hash( pHash, &nValue ) )
   {
      szOut = hbnum_format_zero( nSignificantDigits );
      hb_retc( szOut );
      hb_xfree( szOut );
      return;
   }

   szValue = hbnum_native_to_string( &nValue );
   hbnum_format_extract_digits( szValue, &szDigits, &nDigits, &nExponent, &fNegative );

   if( nDigits == 0 )
   {
      szOut = hbnum_format_zero( nSignificantDigits );
   }
   else
   {
      hbnum_format_apply_significant_digits( &szDigits, &nDigits, &nExponent, nSignificantDigits );
      szOut = hbnum_format_build( szDigits, nDigits, nExponent, fNegative, fEngineering );
   }

   hb_retc( szOut );

   if( szDigits != NULL )
      hb_xfree( szDigits );
   hb_xfree( szOut );
   hb_xfree( szValue );
   hbnum_native_release( &nValue );
}

HB_FUNC( HBNUM_CORE_TOSCIENTIFIC )
{
   hbnum_core_format_return( HB_FALSE );
}

HB_FUNC( HBNUM_CORE_TOENGINEERING )
{
   hbnum_core_format_return( HB_TRUE );
}
