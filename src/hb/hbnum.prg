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

CLASS HBNum

   DATA hbNum
   DATA oContext

   METHOD New( xValue )
   METHOD FromString( cValue )
   METHOD FromInt( nValue )
   METHOD Clone()

   METHOD Add( xValue )
   METHOD Sub( xValue )
   METHOD Mul( xValue )
   METHOD Div( xValue, nPrecision )
   METHOD Compare( xValue )
   METHOD Eq( xValue )
   METHOD Ne( xValue )
   METHOD Gt( xValue )
   METHOD Gte( xValue )
   METHOD Lt( xValue )
   METHOD Lte( xValue )
   METHOD Min( xValue )
   METHOD Max( xValue )
   METHOD Mod( xValue )
   METHOD PowInt( nExp )
   METHOD Sqrt( nPrecision )
   METHOD NthRoot( nDegree, nPrecision )
   METHOD Log( xBase, nPrecision )
   METHOD Log10( nPrecision )
   METHOD Ln( nPrecision )
   METHOD Gcd( xValue )
   METHOD Lcm( xValue )
   METHOD Round( nPrecision )
   METHOD Truncate( nPrecision )
   METHOD Floor( nPrecision )
   METHOD Ceiling( nPrecision )

   METHOD Abs()
   METHOD Neg()
   METHOD IsZero()

   METHOD Normalize()
   METHOD ToString()
   METHOD SetContext( oContext )
   METHOD GetContext()
   METHOD SetPrecision( nPrecision )
   METHOD GetPrecision()
   METHOD SetRootPrecision( nPrecision )
   METHOD GetRootPrecision()
   METHOD SetLogPrecision( nPrecision )
   METHOD GetLogPrecision()

   METHOD _InitHash()
   METHOD _Spawn()
   METHOD _CoerceOperand( xValue )
   METHOD CompareOps()
   METHOD MathOps()
   METHOD IntegerOps()
ENDCLASS


METHOD New( xValue ) CLASS HBNum

   ::_InitHash()

   IF PCount() == 0 .OR. xValue == NIL
      RETURN Self
   ENDIF

   DO CASE
   CASE HB_ISOBJECT( xValue ) .AND. xValue:ClassName() == "HBNUM"
      ::hbNum := HBNUM_CORE_CLONE( xValue:hbNum )

   CASE HB_ISCHAR( xValue )
      ::FromString( xValue )

   CASE HB_ISNUMERIC( xValue )
      ::FromString( hb_ntos( xValue ) )

   OTHERWISE
      ::FromString( "0" )
   ENDCASE

RETURN Self


METHOD _InitHash() CLASS HBNum

   ::hbNum := { ;
      HBNUM_SIGN  => 0, ;
      HBNUM_SCALE => 0, ;
      HBNUM_USED  => 0, ;
      HBNUM_LIMBS => {} ;
   }
   ::oContext := HBNumGetDefaultContext()

RETURN Self


METHOD Clone() CLASS HBNum

   LOCAL oNew := ::_Spawn()

   oNew:hbNum := HBNUM_CORE_CLONE( ::hbNum )

RETURN oNew


METHOD Normalize() CLASS HBNum

   ::hbNum := HBNUM_CORE_NORMALIZE( ::hbNum )

RETURN Self


METHOD FromString( cValue ) CLASS HBNum

   IF ! HB_ISCHAR( cValue )
      IF HB_ISNUMERIC( cValue )
         cValue := hb_ntos( cValue )
      ELSE
         cValue := "0"
      ENDIF
   ENDIF

   ::hbNum := HBNUM_CORE_FROMSTRING( ::hbNum, cValue )

RETURN Self


METHOD FromInt( nValue ) CLASS HBNum

   IF ! HB_ISNUMERIC( nValue )
      nValue := 0
   ENDIF

RETURN ::FromString( hb_ntos( nValue ) )


METHOD ToString() CLASS HBNum
RETURN HBNUM_CORE_TOSTRING( ::hbNum )


METHOD SetContext( oContext ) CLASS HBNum

   IF HB_ISOBJECT( oContext ) .AND. oContext:ClassName() == "HBNUMCONTEXT"
      ::oContext := oContext:Clone()
   ELSE
      ::oContext := HBNumGetDefaultContext()
   ENDIF

RETURN Self


METHOD GetContext() CLASS HBNum
RETURN ::oContext:Clone()


METHOD SetPrecision( nPrecision ) CLASS HBNum

   ::oContext:SetPrecision( nPrecision )

RETURN Self


METHOD GetPrecision() CLASS HBNum
RETURN ::oContext:GetPrecision()


METHOD SetRootPrecision( nPrecision ) CLASS HBNum

   ::oContext:SetRootPrecision( nPrecision )

RETURN Self


METHOD GetRootPrecision() CLASS HBNum
RETURN ::oContext:GetRootPrecision()


METHOD SetLogPrecision( nPrecision ) CLASS HBNum

   ::oContext:SetLogPrecision( nPrecision )

RETURN Self


METHOD GetLogPrecision() CLASS HBNum
RETURN ::oContext:GetLogPrecision()


METHOD Add( xValue ) CLASS HBNum

   LOCAL oOther := ::_CoerceOperand( xValue )
   LOCAL oNew := ::_Spawn()

   oNew:hbNum := HBNUM_CORE_ADD( ::hbNum, oOther:hbNum )

RETURN oNew


METHOD Sub( xValue ) CLASS HBNum

   LOCAL oOther := ::_CoerceOperand( xValue )
   LOCAL oNew := ::_Spawn()

   oNew:hbNum := HBNUM_CORE_SUB( ::hbNum, oOther:hbNum )

RETURN oNew


METHOD Mul( xValue ) CLASS HBNum

   LOCAL oOther := ::_CoerceOperand( xValue )
   LOCAL oNew := ::_Spawn()

   oNew:hbNum := HBNUM_CORE_MUL( ::hbNum, oOther:hbNum )

RETURN oNew


METHOD Div( xValue, nPrecision ) CLASS HBNum

   LOCAL oOther := ::_CoerceOperand( xValue )
   LOCAL oNew := ::_Spawn()

   IF nPrecision == NIL
      nPrecision := ::GetPrecision()
   ENDIF

   IF nPrecision == NIL
      oNew:hbNum := HBNUM_CORE_DIV_AUTO( ::hbNum, oOther:hbNum )
      RETURN oNew
   ENDIF

   IF ! HB_ISNUMERIC( nPrecision )
      nPrecision := 0
   ENDIF

   IF nPrecision < 0
      nPrecision := 0
   ENDIF

   oNew:hbNum := HBNUM_CORE_DIV( ::hbNum, oOther:hbNum, nPrecision )

RETURN oNew


METHOD Compare( xValue ) CLASS HBNum

   LOCAL oOther := ::_CoerceOperand( xValue )

RETURN HBNUM_CORE_COMPARE( ::hbNum, oOther:hbNum )


METHOD Abs() CLASS HBNum

   LOCAL oNew := ::_Spawn()

   oNew:hbNum := HBNUM_CORE_ABS( ::hbNum )

RETURN oNew


METHOD Neg() CLASS HBNum

   LOCAL oNew := ::_Spawn()

   oNew:hbNum := HBNUM_CORE_NEG( ::hbNum )

RETURN oNew


METHOD IsZero() CLASS HBNum
RETURN HBNUM_CORE_ISZERO( ::hbNum )


METHOD _Spawn() CLASS HBNum

   LOCAL oNew := HBNum():New()

   oNew:oContext := ::GetContext()

RETURN oNew


METHOD _CoerceOperand( xValue ) CLASS HBNum

   LOCAL oValue

   IF HB_ISOBJECT( xValue ) .AND. xValue:ClassName() == "HBNUM"
      RETURN xValue
   ENDIF

   oValue := HBNum():New( xValue )
   oValue:oContext := ::GetContext()

RETURN oValue


METHOD CompareOps() CLASS HBNum
RETURN HBNumCompareOps():New( Self )


METHOD MathOps() CLASS HBNum
RETURN HBNumMathOps():New( Self )


METHOD IntegerOps() CLASS HBNum
RETURN HBNumIntegerOps():New( Self )


METHOD Eq( xValue ) CLASS HBNum
RETURN ::CompareOps():Eq( xValue )


METHOD Ne( xValue ) CLASS HBNum
RETURN ::CompareOps():Ne( xValue )


METHOD Gt( xValue ) CLASS HBNum
RETURN ::CompareOps():Gt( xValue )


METHOD Gte( xValue ) CLASS HBNum
RETURN ::CompareOps():Gte( xValue )


METHOD Lt( xValue ) CLASS HBNum
RETURN ::CompareOps():Lt( xValue )


METHOD Lte( xValue ) CLASS HBNum
RETURN ::CompareOps():Lte( xValue )


METHOD Min( xValue ) CLASS HBNum
RETURN ::CompareOps():Min( xValue )


METHOD Max( xValue ) CLASS HBNum
RETURN ::CompareOps():Max( xValue )


METHOD Mod( xValue ) CLASS HBNum
RETURN ::MathOps():Mod( xValue )


METHOD PowInt( nExp ) CLASS HBNum
RETURN ::MathOps():PowInt( nExp )


METHOD Sqrt( nPrecision ) CLASS HBNum
RETURN ::MathOps():Sqrt( nPrecision )


METHOD NthRoot( nDegree, nPrecision ) CLASS HBNum
RETURN ::MathOps():NthRoot( nDegree, nPrecision )


METHOD Log( xBase, nPrecision ) CLASS HBNum
RETURN ::MathOps():Log( xBase, nPrecision )


METHOD Log10( nPrecision ) CLASS HBNum
RETURN ::MathOps():Log10( nPrecision )


METHOD Ln( nPrecision ) CLASS HBNum
RETURN ::MathOps():Ln( nPrecision )


METHOD Round( nPrecision ) CLASS HBNum
RETURN ::MathOps():Round( nPrecision )


METHOD Truncate( nPrecision ) CLASS HBNum
RETURN ::MathOps():Truncate( nPrecision )


METHOD Floor( nPrecision ) CLASS HBNum
RETURN ::MathOps():Floor( nPrecision )


METHOD Ceiling( nPrecision ) CLASS HBNum
RETURN ::MathOps():Ceiling( nPrecision )


METHOD Gcd( xValue ) CLASS HBNum
RETURN ::IntegerOps():Gcd( xValue )


METHOD Lcm( xValue ) CLASS HBNum
RETURN ::IntegerOps():Lcm( xValue )
