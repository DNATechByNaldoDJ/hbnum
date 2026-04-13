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

CLASS HBNumIntegerOps

   DATA oBase

   METHOD New( oBase )
   METHOD Gcd( xValue )
   METHOD Lcm( xValue )

   METHOD _Coerce( xValue )

ENDCLASS


METHOD New( oBase ) CLASS HBNumIntegerOps

   IF HB_ISOBJECT( oBase ) .AND. oBase:ClassName() == "HBNUM"
      ::oBase := oBase
   ELSE
      ::oBase := HBNum():New( "0" )
   ENDIF

RETURN Self


METHOD _Coerce( xValue ) CLASS HBNumIntegerOps
RETURN ::oBase:_CoerceOperand( xValue )


METHOD Gcd( xValue ) CLASS HBNumIntegerOps

   LOCAL oOther := ::_Coerce( xValue )
   LOCAL oNew := HBNum():New()

   oNew:hbNum := HBNUM_CORE_GCD( ::oBase:hbNum, oOther:hbNum )

RETURN oNew


METHOD Lcm( xValue ) CLASS HBNumIntegerOps

   LOCAL oOther := ::_Coerce( xValue )
   LOCAL oNew := HBNum():New()

   oNew:hbNum := HBNUM_CORE_LCM( ::oBase:hbNum, oOther:hbNum )

RETURN oNew
