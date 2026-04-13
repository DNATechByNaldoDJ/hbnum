#include "hbnum.ch"
#include "hblog.ch"

STATIC __cLastOperation := ""
STATIC __cLastExpected := ""
STATIC __cLastActual := ""
STATIC __cLogFileName := "hbnum_tests.log"

STATIC PROCEDURE __InitTestLog()
   LOCAL nStyle := HB_LOG_ST_DATE + HB_LOG_ST_ISODATE + HB_LOG_ST_TIME + HB_LOG_ST_LEVEL
   LOCAL nSeverity := HB_LOG_DEBUG
   LOCAL nFileSize := 2 * 1024 * 1024
   LOCAL nFileCount := 5

   INIT LOG ON FILE ( nSeverity, __cLogFileName, nFileSize, nFileCount )
   SET LOG STYLE ( nStyle )
   __LogLine( "TEST", "Test log started. File: " + __cLogFileName, HB_LOG_INFO )
RETURN

STATIC PROCEDURE __CloseTestLog()
   __LogLine( "TEST", "Test log finished.", HB_LOG_INFO )
   CLOSE LOG
RETURN

STATIC PROCEDURE __LogLine( cKey, cMessage, nSeverity )
   hb_default( @nSeverity, HB_LOG_DEBUG )
   LOG cKey + ": " + cMessage PRIORITY nSeverity
RETURN

STATIC PROCEDURE __SetTrace( cOperation, cExpected, cActual )
   __cLastOperation := cOperation
   __cLastExpected := cExpected
   __cLastActual := cActual
RETURN

STATIC FUNCTION __RunTest( cName, lResult )
   ? IIf( lResult, "[PASS]", "[FAIL]" ), cName
   ? "  operation:", __cLastOperation
   ? "  expected :", __cLastExpected
   ? "  actual   :", __cLastActual
   __LogLine( cName, ;
      "result=" + IIf( lResult, "PASS", "FAIL" ) + ;
      ", operation=[" + __cLastOperation + "]" + ;
      ", expected=[" + __cLastExpected + "]" + ;
      ", actual=[" + __cLastActual + "]", ;
      IIf( lResult, HB_LOG_INFO, HB_LOG_ERROR ) )
RETURN lResult

FUNCTION Main()
   LOCAL lOk := .T.

   __InitTestLog()

   ? "== ADD TESTS =="
   __LogLine( "GROUP", "== ADD TESTS ==", HB_LOG_INFO )
   lOk := __RunTest( "Test_Add_Simple", Test_Add_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_Add_Carry", Test_Add_Carry() ) .AND. lOk
   lOk := __RunTest( "Test_Add_DifferentSize", Test_Add_DifferentSize() ) .AND. lOk
   lOk := __RunTest( "Test_Add_Negative", Test_Add_Negative() ) .AND. lOk
   lOk := __RunTest( "Test_Add_Zero", Test_Add_Zero() ) .AND. lOk
   lOk := __RunTest( "Test_Add_Internal", Test_Add_Internal() ) .AND. lOk
   lOk := __RunTest( "Test_Add_Commutative", Test_Add_Commutative() ) .AND. lOk
   lOk := __RunTest( "Test_Add_NoMutation", Test_Add_NoMutation() ) .AND. lOk

   ? "== SUB TESTS =="
   __LogLine( "GROUP", "== SUB TESTS ==", HB_LOG_INFO )
   lOk := __RunTest( "Test_Sub_Simple", Test_Sub_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_Sub_Borrow", Test_Sub_Borrow() ) .AND. lOk
   lOk := __RunTest( "Test_Sub_DifferentSize", Test_Sub_DifferentSize() ) .AND. lOk
   lOk := __RunTest( "Test_Sub_Negative", Test_Sub_Negative() ) .AND. lOk
   lOk := __RunTest( "Test_Sub_Zero", Test_Sub_Zero() ) .AND. lOk
   lOk := __RunTest( "Test_Sub_NoMutation", Test_Sub_NoMutation() ) .AND. lOk

   ? "== MUL TESTS =="
   __LogLine( "GROUP", "== MUL TESTS ==", HB_LOG_INFO )
   lOk := __RunTest( "Test_Mul_Simple", Test_Mul_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_Mul_Carry", Test_Mul_Carry() ) .AND. lOk
   lOk := __RunTest( "Test_Mul_DifferentSize", Test_Mul_DifferentSize() ) .AND. lOk
   lOk := __RunTest( "Test_Mul_Negative", Test_Mul_Negative() ) .AND. lOk
   lOk := __RunTest( "Test_Mul_Zero", Test_Mul_Zero() ) .AND. lOk
   lOk := __RunTest( "Test_Mul_NoMutation", Test_Mul_NoMutation() ) .AND. lOk

   ? "== DIV TESTS =="
   __LogLine( "GROUP", "== DIV TESTS ==", HB_LOG_INFO )
   lOk := __RunTest( "Test_Div_Simple", Test_Div_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_Div_Truncate", Test_Div_Truncate() ) .AND. lOk
   lOk := __RunTest( "Test_Div_Precision", Test_Div_Precision() ) .AND. lOk
   lOk := __RunTest( "Test_Div_Negative", Test_Div_Negative() ) .AND. lOk
   lOk := __RunTest( "Test_Div_ZeroNumerator", Test_Div_ZeroNumerator() ) .AND. lOk
   lOk := __RunTest( "Test_Div_NoMutation", Test_Div_NoMutation() ) .AND. lOk

   ? "== EXT TESTS =="
   __LogLine( "GROUP", "== EXT TESTS ==", HB_LOG_INFO )
   lOk := __RunTest( "Test_Compare_Eq", Test_Compare_Eq() ) .AND. lOk
   lOk := __RunTest( "Test_Compare_Order", Test_Compare_Order() ) .AND. lOk
   lOk := __RunTest( "Test_Min_Max", Test_Min_Max() ) .AND. lOk
   lOk := __RunTest( "Test_Mod_Simple", Test_Mod_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_Mod_NegativeDividend", Test_Mod_NegativeDividend() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_Simple", Test_PowInt_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_ZeroExponent", Test_PowInt_ZeroExponent() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_NegativeBase", Test_PowInt_NegativeBase() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_NoMutation", Test_PowInt_NoMutation() ) .AND. lOk

   ? "== NUMBER THEORY TESTS =="
   __LogLine( "GROUP", "== NUMBER THEORY TESTS ==", HB_LOG_INFO )
   lOk := __RunTest( "Test_Gcd_Simple", Test_Gcd_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_Gcd_Zero", Test_Gcd_Zero() ) .AND. lOk
   lOk := __RunTest( "Test_Gcd_Negative", Test_Gcd_Negative() ) .AND. lOk
   lOk := __RunTest( "Test_Gcd_NoMutation", Test_Gcd_NoMutation() ) .AND. lOk
   lOk := __RunTest( "Test_Lcm_Simple", Test_Lcm_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_Lcm_Zero", Test_Lcm_Zero() ) .AND. lOk
   lOk := __RunTest( "Test_Lcm_Negative", Test_Lcm_Negative() ) .AND. lOk

   IF lOk
      ? "ALL TESTS PASSED"
      __LogLine( "RESULT", "ALL TESTS PASSED", HB_LOG_INFO )
      __CloseTestLog()
      RETURN 0
   ENDIF

   ? "TESTS FAILED"
   __LogLine( "RESULT", "TESTS FAILED", HB_LOG_ERROR )
   __CloseTestLog()
RETURN 1

FUNCTION Test_Add_Simple()
   LOCAL oA := HBNum():New( "2" )
   LOCAL oB := HBNum():New( "3" )
   LOCAL oR := oA:Add( oB )
   LOCAL cExpected := "5"
   LOCAL cActual := oR:ToString()

   __SetTrace( "2 + 3", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Add_Carry()
   LOCAL oA := HBNum():New( "999999999" )
   LOCAL oB := HBNum():New( "1" )
   LOCAL oR := oA:Add( oB )
   LOCAL cExpected := "1000000000"
   LOCAL cActual := oR:ToString()

   __SetTrace( "999999999 + 1", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Add_DifferentSize()
   LOCAL oA := HBNum():New( "123" )
   LOCAL oB := HBNum():New( "999999999" )
   LOCAL oR := oA:Add( oB )
   LOCAL cExpected := "1000000122"
   LOCAL cActual := oR:ToString()

   __SetTrace( "123 + 999999999", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Add_Negative()
   LOCAL oA := HBNum():New( "-10" )
   LOCAL oB := HBNum():New( "5" )
   LOCAL oR := oA:Add( oB )
   LOCAL cExpected := "-5"
   LOCAL cActual := oR:ToString()

   __SetTrace( "-10 + 5", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Add_Zero()
   LOCAL oA := HBNum():New( "0" )
   LOCAL oB := HBNum():New( "123" )
   LOCAL oR := oA:Add( oB )
   LOCAL cExpected := "123"
   LOCAL cActual := oR:ToString()

   __SetTrace( "0 + 123", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Add_Internal()
   LOCAL oA := HBNum():New( hb_ntos( HBNUM_BASE - 1 ) )
   LOCAL oB := HBNum():New( "1" )
   LOCAL oR := oA:Add( oB )
   LOCAL lResult := ;
      oR:hbNum[ HBNUM_USED ] > 1 .AND. ;
      oR:hbNum[ HBNUM_SIGN ] == 1 .AND. ;
      Len( oR:hbNum[ HBNUM_LIMBS ] ) == oR:hbNum[ HBNUM_USED ]
   LOCAL cActual := ;
      "nUsed=" + hb_ntos( oR:hbNum[ HBNUM_USED ] ) + ;
      ", nSign=" + hb_ntos( oR:hbNum[ HBNUM_SIGN ] )

   __SetTrace( hb_ntos( HBNUM_BASE - 1 ) + " + 1 (carry de limb)", "nUsed>1, nSign=1", cActual )
RETURN lResult

FUNCTION Test_Add_Commutative()
   LOCAL oA := HBNum():New( "123456" )
   LOCAL oB := HBNum():New( "789" )
   LOCAL cAB := oA:Add( oB ):ToString()
   LOCAL cBA := oB:Add( oA ):ToString()

   __SetTrace( "123456 + 789 (commutative)", cAB, cBA )
RETURN cAB == cBA

FUNCTION Test_Add_NoMutation()
   LOCAL oA := HBNum():New( "42" )
   LOCAL oB := HBNum():New( "-2" )
   LOCAL cA := oA:ToString()
   LOCAL cB := oB:ToString()
   LOCAL oR := oA:Add( oB )
   LOCAL lResult := ;
      cA == oA:ToString() .AND. ;
      cB == oB:ToString() .AND. ;
      oR:ToString() == "40"
   LOCAL cActual := ;
      "A=" + oA:ToString() + ", B=" + oB:ToString() + ", R=" + oR:ToString()

   __SetTrace( "imutabilidade de entrada em 42 + (-2)", "A=42, B=-2, R=40", cActual )
RETURN lResult

FUNCTION Test_Sub_Simple()
   LOCAL oA := HBNum():New( "5" )
   LOCAL oB := HBNum():New( "3" )
   LOCAL oR := oA:Sub( oB )
   LOCAL cExpected := "2"
   LOCAL cActual := oR:ToString()

   __SetTrace( "5 - 3", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Sub_Borrow()
   LOCAL oA := HBNum():New( hb_ntos( HBNUM_BASE ) )
   LOCAL oB := HBNum():New( "1" )
   LOCAL oR := oA:Sub( oB )
   LOCAL cExpected := hb_ntos( HBNUM_BASE - 1 )
   LOCAL cActual := oR:ToString()

   __SetTrace( hb_ntos( HBNUM_BASE ) + " - 1 (borrow de limb)", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Sub_DifferentSize()
   LOCAL oA := HBNum():New( "1000000000" )
   LOCAL oB := HBNum():New( "123" )
   LOCAL oR := oA:Sub( oB )
   LOCAL cExpected := "999999877"
   LOCAL cActual := oR:ToString()

   __SetTrace( "1000000000 - 123", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Sub_Negative()
   LOCAL oA := HBNum():New( "5" )
   LOCAL oB := HBNum():New( "10" )
   LOCAL oR := oA:Sub( oB )
   LOCAL cExpected := "-5"
   LOCAL cActual := oR:ToString()

   __SetTrace( "5 - 10", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Sub_Zero()
   LOCAL oA := HBNum():New( "0" )
   LOCAL oB := HBNum():New( "123" )
   LOCAL oR := oA:Sub( oB )
   LOCAL cExpected := "-123"
   LOCAL cActual := oR:ToString()

   __SetTrace( "0 - 123", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Sub_NoMutation()
   LOCAL oA := HBNum():New( "42" )
   LOCAL oB := HBNum():New( "2" )
   LOCAL cA := oA:ToString()
   LOCAL cB := oB:ToString()
   LOCAL oR := oA:Sub( oB )
   LOCAL lResult := ;
      cA == oA:ToString() .AND. ;
      cB == oB:ToString() .AND. ;
      oR:ToString() == "40"
   LOCAL cActual := ;
      "A=" + oA:ToString() + ", B=" + oB:ToString() + ", R=" + oR:ToString()

   __SetTrace( "imutabilidade de entrada em 42 - 2", "A=42, B=2, R=40", cActual )
RETURN lResult

FUNCTION Test_Mul_Simple()
   LOCAL oA := HBNum():New( "2" )
   LOCAL oB := HBNum():New( "3" )
   LOCAL oR := oA:Mul( oB )
   LOCAL cExpected := "6"
   LOCAL cActual := oR:ToString()

   __SetTrace( "2 * 3", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Mul_Carry()
   LOCAL oA := HBNum():New( hb_ntos( HBNUM_BASE - 1 ) )
   LOCAL oB := HBNum():New( "2" )
   LOCAL oR := oA:Mul( oB )
   LOCAL cExpected := hb_ntos( ( HBNUM_BASE - 1 ) * 2 )
   LOCAL cActual := oR:ToString()

   __SetTrace( hb_ntos( HBNUM_BASE - 1 ) + " * 2", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Mul_DifferentSize()
   LOCAL oA := HBNum():New( "123" )
   LOCAL oB := HBNum():New( "999999999" )
   LOCAL oR := oA:Mul( oB )
   LOCAL cExpected := "122999999877"
   LOCAL cActual := oR:ToString()

   __SetTrace( "123 * 999999999", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Mul_Negative()
   LOCAL oA := HBNum():New( "-10" )
   LOCAL oB := HBNum():New( "5" )
   LOCAL oR := oA:Mul( oB )
   LOCAL cExpected := "-50"
   LOCAL cActual := oR:ToString()

   __SetTrace( "-10 * 5", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Mul_Zero()
   LOCAL oA := HBNum():New( "0" )
   LOCAL oB := HBNum():New( "123" )
   LOCAL oR := oA:Mul( oB )
   LOCAL cExpected := "0"
   LOCAL cActual := oR:ToString()

   __SetTrace( "0 * 123", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Mul_NoMutation()
   LOCAL oA := HBNum():New( "42" )
   LOCAL oB := HBNum():New( "-2" )
   LOCAL cA := oA:ToString()
   LOCAL cB := oB:ToString()
   LOCAL oR := oA:Mul( oB )
   LOCAL lResult := ;
      cA == oA:ToString() .AND. ;
      cB == oB:ToString() .AND. ;
      oR:ToString() == "-84"
   LOCAL cActual := ;
      "A=" + oA:ToString() + ", B=" + oB:ToString() + ", R=" + oR:ToString()

   __SetTrace( "imutabilidade de entrada em 42 * (-2)", "A=42, B=-2, R=-84", cActual )
RETURN lResult

FUNCTION Test_Div_Simple()
   LOCAL oA := HBNum():New( "10" )
   LOCAL oB := HBNum():New( "2" )
   LOCAL oR := oA:Div( oB, 0 )
   LOCAL cExpected := "5"
   LOCAL cActual := oR:ToString()

   __SetTrace( "10 / 2 (precision 0)", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Div_Truncate()
   LOCAL oA := HBNum():New( "7" )
   LOCAL oB := HBNum():New( "2" )
   LOCAL oR := oA:Div( oB, 0 )
   LOCAL cExpected := "3"
   LOCAL cActual := oR:ToString()

   __SetTrace( "7 / 2 (precision 0, truncado)", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Div_Precision()
   LOCAL oA := HBNum():New( "1" )
   LOCAL oB := HBNum():New( "8" )
   LOCAL oR := oA:Div( oB, 3 )
   LOCAL cExpected := "0.125"
   LOCAL cActual := oR:ToString()

   __SetTrace( "1 / 8 (precision 3)", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Div_Negative()
   LOCAL oA := HBNum():New( "-10" )
   LOCAL oB := HBNum():New( "4" )
   LOCAL oR := oA:Div( oB, 0 )
   LOCAL cExpected := "-2"
   LOCAL cActual := oR:ToString()

   __SetTrace( "-10 / 4 (precision 0)", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Div_ZeroNumerator()
   LOCAL oA := HBNum():New( "0" )
   LOCAL oB := HBNum():New( "123" )
   LOCAL oR := oA:Div( oB, 2 )
   LOCAL cExpected := "0"
   LOCAL cActual := oR:ToString()

   __SetTrace( "0 / 123 (precision 2)", cExpected, cActual )
RETURN cActual == cExpected

FUNCTION Test_Div_NoMutation()
   LOCAL oA := HBNum():New( "42" )
   LOCAL oB := HBNum():New( "5" )
   LOCAL cA := oA:ToString()
   LOCAL cB := oB:ToString()
   LOCAL oR := oA:Div( oB, 2 )
   LOCAL lResult := ;
      cA == oA:ToString() .AND. ;
      cB == oB:ToString() .AND. ;
      oR:ToString() == "8.40"
   LOCAL cActual := ;
      "A=" + oA:ToString() + ", B=" + oB:ToString() + ", R=" + oR:ToString()

   __SetTrace( "imutabilidade de entrada em 42 / 5 (precision 2)", "A=42, B=5, R=8.40", cActual )
RETURN lResult


FUNCTION Test_Compare_Eq()
   LOCAL oA := HBNum():New( "123.45" )
   LOCAL oB := HBNum():New( "123.450" )
   LOCAL lResult := oA:Eq( oB ) .AND. oA:Gte( oB ) .AND. oA:Lte( oB )
   LOCAL cActual := IIf( lResult, ".T.", ".F." )

   __SetTrace( "123.45 == 123.450 (Eq/Gte/Lte)", ".T.", cActual )
RETURN lResult


FUNCTION Test_Compare_Order()
   LOCAL oA := HBNum():New( "-7" )
   LOCAL oB := HBNum():New( "3" )
   LOCAL lResult := oA:Lt( oB ) .AND. oB:Gt( oA ) .AND. oA:Ne( oB )
   LOCAL cActual := IIf( lResult, ".T.", ".F." )

   __SetTrace( "-7 < 3 e 3 > -7", ".T.", cActual )
RETURN lResult


FUNCTION Test_Min_Max()
   LOCAL oA := HBNum():New( "12.5" )
   LOCAL oB := HBNum():New( "12.49" )
   LOCAL oMin := oA:Min( oB )
   LOCAL oMax := oA:Max( oB )
   LOCAL lResult := oMin:ToString() == "12.49" .AND. oMax:ToString() == "12.5"
   LOCAL cActual := "min=" + oMin:ToString() + ", max=" + oMax:ToString()

   __SetTrace( "Min/Max entre 12.5 e 12.49", "min=12.49, max=12.5", cActual )
RETURN lResult


FUNCTION Test_Mod_Simple()
   LOCAL oA := HBNum():New( "10" )
   LOCAL oB := HBNum():New( "3" )
   LOCAL oR := oA:Mod( oB )
   LOCAL cExpected := "1"
   LOCAL cActual := oR:ToString()

   __SetTrace( "10 % 3", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Mod_NegativeDividend()
   LOCAL oA := HBNum():New( "-10" )
   LOCAL oB := HBNum():New( "3" )
   LOCAL oR := oA:Mod( oB )
   LOCAL cExpected := "-1"
   LOCAL cActual := oR:ToString()

   __SetTrace( "-10 % 3 (trunc toward zero)", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_PowInt_Simple()
   LOCAL oA := HBNum():New( "2" )
   LOCAL oR := oA:PowInt( 10 )
   LOCAL cExpected := "1024"
   LOCAL cActual := oR:ToString()

   __SetTrace( "2^10", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_PowInt_ZeroExponent()
   LOCAL oA := HBNum():New( "999" )
   LOCAL oR := oA:PowInt( 0 )
   LOCAL cExpected := "1"
   LOCAL cActual := oR:ToString()

   __SetTrace( "999^0", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_PowInt_NegativeBase()
   LOCAL oA := HBNum():New( "-2" )
   LOCAL oR := oA:PowInt( 3 )
   LOCAL cExpected := "-8"
   LOCAL cActual := oR:ToString()

   __SetTrace( "(-2)^3", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_PowInt_NoMutation()
   LOCAL oA := HBNum():New( "3" )
   LOCAL cA := oA:ToString()
   LOCAL oR := oA:PowInt( 4 )
   LOCAL lResult := cA == oA:ToString() .AND. oR:ToString() == "81"
   LOCAL cActual := "A=" + oA:ToString() + ", R=" + oR:ToString()

   __SetTrace( "imutabilidade de entrada em 3^4", "A=3, R=81", cActual )
RETURN lResult


FUNCTION Test_Gcd_Simple()
   LOCAL oA := HBNum():New( "48" )
   LOCAL oB := HBNum():New( "18" )
   LOCAL oR := oA:Gcd( oB )
   LOCAL cExpected := "6"
   LOCAL cActual := oR:ToString()

   __SetTrace( "GCD(48, 18)", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Gcd_Zero()
   LOCAL oA := HBNum():New( "0" )
   LOCAL oB := HBNum():New( "18" )
   LOCAL oR := oA:Gcd( oB )
   LOCAL cExpected := "18"
   LOCAL cActual := oR:ToString()

   __SetTrace( "GCD(0, 18)", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Gcd_Negative()
   LOCAL oA := HBNum():New( "-48" )
   LOCAL oB := HBNum():New( "18" )
   LOCAL oR := oA:Gcd( oB )
   LOCAL cExpected := "6"
   LOCAL cActual := oR:ToString()

   __SetTrace( "GCD(-48, 18)", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Gcd_NoMutation()
   LOCAL oA := HBNum():New( "84" )
   LOCAL oB := HBNum():New( "30" )
   LOCAL cA := oA:ToString()
   LOCAL cB := oB:ToString()
   LOCAL oR := oA:Gcd( oB )
   LOCAL lResult := ;
      cA == oA:ToString() .AND. ;
      cB == oB:ToString() .AND. ;
      oR:ToString() == "6"
   LOCAL cActual := ;
      "A=" + oA:ToString() + ", B=" + oB:ToString() + ", R=" + oR:ToString()

   __SetTrace( "imutabilidade de entrada em GCD(84,30)", "A=84, B=30, R=6", cActual )
RETURN lResult


FUNCTION Test_Lcm_Simple()
   LOCAL oA := HBNum():New( "21" )
   LOCAL oB := HBNum():New( "6" )
   LOCAL oR := oA:Lcm( oB )
   LOCAL cExpected := "42"
   LOCAL cActual := oR:ToString()

   __SetTrace( "LCM(21, 6)", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Lcm_Zero()
   LOCAL oA := HBNum():New( "0" )
   LOCAL oB := HBNum():New( "9" )
   LOCAL oR := oA:Lcm( oB )
   LOCAL cExpected := "0"
   LOCAL cActual := oR:ToString()

   __SetTrace( "LCM(0, 9)", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Lcm_Negative()
   LOCAL oA := HBNum():New( "-21" )
   LOCAL oB := HBNum():New( "6" )
   LOCAL oR := oA:Lcm( oB )
   LOCAL cExpected := "42"
   LOCAL cActual := oR:ToString()

   __SetTrace( "LCM(-21, 6)", cExpected, cActual )
RETURN cActual == cExpected
