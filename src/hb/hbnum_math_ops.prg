/*
 _      _
| |__  | |__   _ __   _   _  _ __ ___
| '_ \ | '_ \ | '_ \ | | | || '_ ` _ \
| | | || |_) || | | || |_| || | | | | |
|_| |_||_.__/ |_| |_| \__,_||_| |_| |_|

hbnum: Released to Public Domain.
--------------------------------------------------------------------------------------

*/

#include "hbnum.ch"
#include "hbclass.ch"

CLASS HBNumMathOps

   DATA oBase

   METHOD New( oBase )
   METHOD Mod( xValue )
   METHOD PowInt( nExp )
   METHOD Sqrt( nPrecision )
   METHOD NthRoot( nDegree, nPrecision )
   METHOD Log( xBase, nPrecision )
   METHOD Log10( nPrecision )
   METHOD Ln( nPrecision )
   METHOD Round( nPrecision )
   METHOD Truncate( nPrecision )
   METHOD Floor( nPrecision )
   METHOD Ceiling( nPrecision )

   METHOD _Coerce( xValue )

ENDCLASS


METHOD New( oBase ) CLASS HBNumMathOps

   IF HB_ISOBJECT( oBase ) .AND. oBase:ClassName() == "HBNUM"
      ::oBase := oBase
   ELSE
      ::oBase := HBNum():New( "0" )
   ENDIF

RETURN Self


METHOD _Coerce( xValue ) CLASS HBNumMathOps
RETURN ::oBase:_CoerceOperand( xValue )


METHOD Mod( xValue ) CLASS HBNumMathOps

   LOCAL oOther := ::_Coerce( xValue )
   LOCAL oNew := ::oBase:_Spawn()

   oNew:hbNum := HBNUM_CORE_MOD( ::oBase:hbNum, oOther:hbNum )

RETURN oNew


METHOD PowInt( nExp ) CLASS HBNumMathOps

   LOCAL oNew := ::oBase:_Spawn()

   IF nExp == NIL .OR. ! HB_ISNUMERIC( nExp )
      nExp := 0
   ENDIF

   oNew:hbNum := HBNUM_CORE_POWINT( ::oBase:hbNum, Int( nExp ) )

RETURN oNew


METHOD Sqrt( nPrecision ) CLASS HBNumMathOps

   LOCAL oNew := ::oBase:_Spawn()

   IF nPrecision == NIL .OR. ! HB_ISNUMERIC( nPrecision )
      nPrecision := ::oBase:GetRootPrecision()
   ENDIF

   IF nPrecision == NIL
      oNew:hbNum := HBNUM_CORE_SQRT_AUTO( ::oBase:hbNum )
      RETURN oNew
   ENDIF

   oNew:hbNum := HBNUM_CORE_SQRT( ::oBase:hbNum, Max( Int( nPrecision ), 0 ) )

RETURN oNew


METHOD NthRoot( nDegree, nPrecision ) CLASS HBNumMathOps

   LOCAL oNew := ::oBase:_Spawn()

   IF nPrecision == NIL .OR. ! HB_ISNUMERIC( nPrecision )
      nPrecision := ::oBase:GetRootPrecision()
   ENDIF

   IF nPrecision == NIL
      oNew:hbNum := HBNUM_CORE_NTHROOT_AUTO( ::oBase:hbNum, nDegree )
      RETURN oNew
   ENDIF

   oNew:hbNum := HBNUM_CORE_NTHROOT( ::oBase:hbNum, nDegree, Max( Int( nPrecision ), 0 ) )

RETURN oNew


METHOD Log( xBase, nPrecision ) CLASS HBNumMathOps

   LOCAL oNew := ::oBase:_Spawn()
   LOCAL oOther

   IF nPrecision == NIL .OR. ! HB_ISNUMERIC( nPrecision )
      nPrecision := ::oBase:GetLogPrecision()
   ENDIF

   IF xBase == NIL
      IF nPrecision == NIL
         oNew:hbNum := HBNUM_CORE_LN_AUTO( ::oBase:hbNum )
      ELSE
         oNew:hbNum := HBNUM_CORE_LN( ::oBase:hbNum, Max( Int( nPrecision ), 0 ) )
      ENDIF
      RETURN oNew
   ENDIF

   oOther := ::_Coerce( xBase )

   IF nPrecision == NIL
      oNew:hbNum := HBNUM_CORE_LOG_AUTO( ::oBase:hbNum, oOther:hbNum )
      RETURN oNew
   ENDIF

   oNew:hbNum := HBNUM_CORE_LOG( ::oBase:hbNum, oOther:hbNum, Max( Int( nPrecision ), 0 ) )

RETURN oNew


METHOD Log10( nPrecision ) CLASS HBNumMathOps

   LOCAL oNew := ::oBase:_Spawn()

   IF nPrecision == NIL .OR. ! HB_ISNUMERIC( nPrecision )
      nPrecision := ::oBase:GetLogPrecision()
   ENDIF

   IF nPrecision == NIL
      oNew:hbNum := HBNUM_CORE_LOG10_AUTO( ::oBase:hbNum )
      RETURN oNew
   ENDIF

   oNew:hbNum := HBNUM_CORE_LOG10( ::oBase:hbNum, Max( Int( nPrecision ), 0 ) )

RETURN oNew


METHOD Ln( nPrecision ) CLASS HBNumMathOps
RETURN ::Log( NIL, nPrecision )


METHOD Round( nPrecision ) CLASS HBNumMathOps

   LOCAL oNew := ::oBase:_Spawn()

   IF nPrecision == NIL .OR. ! HB_ISNUMERIC( nPrecision )
      nPrecision := ::oBase:GetPrecision()
   ENDIF

   oNew:hbNum := HBNUM_CORE_ROUND( ::oBase:hbNum, Max( Int( nPrecision ), 0 ) )

RETURN oNew


METHOD Truncate( nPrecision ) CLASS HBNumMathOps

   LOCAL oNew := ::oBase:_Spawn()

   IF nPrecision == NIL .OR. ! HB_ISNUMERIC( nPrecision )
      nPrecision := ::oBase:GetPrecision()
   ENDIF

   oNew:hbNum := HBNUM_CORE_TRUNC( ::oBase:hbNum, Max( Int( nPrecision ), 0 ) )

RETURN oNew


METHOD Floor( nPrecision ) CLASS HBNumMathOps

   LOCAL oNew := ::oBase:_Spawn()

   IF nPrecision == NIL .OR. ! HB_ISNUMERIC( nPrecision )
      nPrecision := ::oBase:GetPrecision()
   ENDIF

   oNew:hbNum := HBNUM_CORE_FLOOR( ::oBase:hbNum, Max( Int( nPrecision ), 0 ) )

RETURN oNew


METHOD Ceiling( nPrecision ) CLASS HBNumMathOps

   LOCAL oNew := ::oBase:_Spawn()

   IF nPrecision == NIL .OR. ! HB_ISNUMERIC( nPrecision )
      nPrecision := ::oBase:GetPrecision()
   ENDIF

   oNew:hbNum := HBNUM_CORE_CEILING( ::oBase:hbNum, Max( Int( nPrecision ), 0 ) )

RETURN oNew
