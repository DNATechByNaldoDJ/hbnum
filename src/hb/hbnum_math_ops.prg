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
   LOCAL oNew := HBNum():New()

   oNew:hbNum := HBNUM_CORE_MOD( ::oBase:hbNum, oOther:hbNum )

RETURN oNew


METHOD PowInt( nExp ) CLASS HBNumMathOps

   LOCAL oNew := HBNum():New()

   IF nExp == NIL .OR. ! HB_ISNUMERIC( nExp )
      nExp := 0
   ENDIF

   oNew:hbNum := HBNUM_CORE_POWINT( ::oBase:hbNum, Int( nExp ) )

RETURN oNew
