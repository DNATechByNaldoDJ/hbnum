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

CLASS HBNumCompareOps

   DATA oBase

   METHOD New( oBase )
   METHOD Eq( xValue )
   METHOD Ne( xValue )
   METHOD Gt( xValue )
   METHOD Gte( xValue )
   METHOD Lt( xValue )
   METHOD Lte( xValue )
   METHOD Min( xValue )
   METHOD Max( xValue )

   METHOD _Coerce( xValue )

ENDCLASS


METHOD New( oBase ) CLASS HBNumCompareOps

   IF HB_ISOBJECT( oBase ) .AND. oBase:ClassName() == "HBNUM"
      ::oBase := oBase
   ELSE
      ::oBase := HBNum():New( "0" )
   ENDIF

RETURN Self


METHOD _Coerce( xValue ) CLASS HBNumCompareOps
RETURN ::oBase:_CoerceOperand( xValue )


METHOD Eq( xValue ) CLASS HBNumCompareOps
RETURN ::oBase:Compare( ::_Coerce( xValue ) ) == 0


METHOD Ne( xValue ) CLASS HBNumCompareOps
RETURN ::oBase:Compare( ::_Coerce( xValue ) ) != 0


METHOD Gt( xValue ) CLASS HBNumCompareOps
RETURN ::oBase:Compare( ::_Coerce( xValue ) ) > 0


METHOD Gte( xValue ) CLASS HBNumCompareOps
RETURN ::oBase:Compare( ::_Coerce( xValue ) ) >= 0


METHOD Lt( xValue ) CLASS HBNumCompareOps
RETURN ::oBase:Compare( ::_Coerce( xValue ) ) < 0


METHOD Lte( xValue ) CLASS HBNumCompareOps
RETURN ::oBase:Compare( ::_Coerce( xValue ) ) <= 0


METHOD Min( xValue ) CLASS HBNumCompareOps

   LOCAL oOther := ::_Coerce( xValue )

   IF ::oBase:Compare( oOther ) <= 0
      RETURN ::oBase:Clone()
   ENDIF

RETURN oOther:Clone()


METHOD Max( xValue ) CLASS HBNumCompareOps

   LOCAL oOther := ::_Coerce( xValue )

   IF ::oBase:Compare( oOther ) >= 0
      RETURN ::oBase:Clone()
   ENDIF

RETURN oOther:Clone()
