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
   METHOD Factorial()
   METHOD Fi()
   METHOD MillerRabin( xIterations )
   METHOD Randomize( xMin, xMax )
   METHOD Fibonacci()

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


METHOD Factorial() CLASS HBNumIntegerOps

   LOCAL oNew := HBNum():New()

   oNew:hbNum := HBNUM_CORE_FACTORIAL( ::oBase:hbNum )

RETURN oNew


METHOD Fi() CLASS HBNumIntegerOps

   LOCAL oNew := HBNum():New()

   oNew:hbNum := HBNUM_CORE_FI( ::oBase:hbNum )

RETURN oNew


METHOD MillerRabin( xIterations ) CLASS HBNumIntegerOps

   LOCAL oRounds

   IF xIterations == NIL
      RETURN HBNUM_CORE_MILLERRABIN( ::oBase:hbNum, 2 )
   ENDIF

   IF HB_ISNUMERIC( xIterations )
      RETURN HBNUM_CORE_MILLERRABIN( ::oBase:hbNum, Max( Int( xIterations ), 1 ) )
   ENDIF

   oRounds := ::_Coerce( xIterations )

RETURN HBNUM_CORE_MILLERRABIN( ::oBase:hbNum, oRounds:hbNum )


METHOD Randomize( xMin, xMax ) CLASS HBNumIntegerOps

   LOCAL oNew := HBNum():New()
   LOCAL oMin
   LOCAL oMax

   IF xMin == NIL .AND. xMax == NIL
      oNew:hbNum := HBNUM_CORE_RANDOMIZE()
      RETURN oNew
   ENDIF

   IF xMin == NIL
      oMin := HBNum():New( "1" )
   ELSE
      oMin := ::_Coerce( xMin )
   ENDIF

   IF xMax == NIL
      oMax := oMin
      oMin := HBNum():New( "0" )
   ELSE
      oMax := ::_Coerce( xMax )
   ENDIF

   oNew:hbNum := HBNUM_CORE_RANDOMIZE( oMin:hbNum, oMax:hbNum )

RETURN oNew


METHOD Fibonacci() CLASS HBNumIntegerOps

   LOCAL aFibonacci := {}
   LOCAL oLimit := ::oBase:Clone()
   LOCAL oA := HBNum():New( "0" )
   LOCAL oB := HBNum():New( "1" )
   LOCAL oT

   DO WHILE oA:Lt( oLimit )
      AAdd( aFibonacci, oA:ToString() )
      oT := oB:Clone()
      oB := oA:Add( oB )
      oA := oT
   ENDDO

RETURN aFibonacci
