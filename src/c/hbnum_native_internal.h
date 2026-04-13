/*
 _      _
| |__  | |__   _ __   _   _  _ __ ___
| '_ \ | '_ \ | '_ \ | | | || '_ ` _ \
| | | || |_) || | | || |_| || | | | | |
|_| |_||_.__/ |_| |_| \__,_||_| |_| |_|

hbnum: Released to Public Domain.
--------------------------------------------------------------------------------------

*/

#ifndef HBNUM_NATIVE_INTERNAL_H
#define HBNUM_NATIVE_INTERNAL_H

#include "../../include/hbnum.h"

typedef struct
{
   int sign;
   HB_SIZE scale;
   HB_SIZE used;
   HB_U32 * limbs;
} HBNumNative;

void hbnum_native_init( HBNumNative * pNum );
void hbnum_native_release( HBNumNative * pNum );
void hbnum_native_normalize( HBNumNative * pNum );

HB_BOOL hbnum_native_clone( const HBNumNative * pSrc, HBNumNative * pDst );
HB_BOOL hbnum_native_add( const HBNumNative * pA, const HBNumNative * pB, HBNumNative * pResult );
HB_BOOL hbnum_native_sub( const HBNumNative * pA, const HBNumNative * pB, HBNumNative * pResult );
HB_BOOL hbnum_native_mul( const HBNumNative * pA, const HBNumNative * pB, HBNumNative * pResult );
HB_BOOL hbnum_native_div( const HBNumNative * pA, const HBNumNative * pB, HB_SIZE nPrecision, HBNumNative * pResult );
int hbnum_native_compare( const HBNumNative * pA, const HBNumNative * pB );

HB_BOOL hbnum_native_from_hash( PHB_ITEM pHash, HBNumNative * pOut );
PHB_ITEM hbnum_native_to_hash( const HBNumNative * pNum );

#endif
