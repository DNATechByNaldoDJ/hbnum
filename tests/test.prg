/*
hbnum: Released to Public Domain.
*/
#include "hbnum.ch"
#include "hblog.ch"

STATIC __cLastOperation := ""
STATIC __cLastExpected := ""
STATIC __cLastActual := ""
STATIC __cLogFileName := ""

STATIC PROCEDURE __InitTestLog()
   LOCAL nStyle := HB_LOG_ST_DATE + HB_LOG_ST_ISODATE + HB_LOG_ST_TIME + HB_LOG_ST_LEVEL
   LOCAL nSeverity := HB_LOG_DEBUG
   LOCAL nFileSize := 2 * 1024 * 1024
   LOCAL nFileCount := 5

   __cLogFileName := HBNumTestArtifactPath( "hbnum_tests.log" )
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

STATIC FUNCTION __ExpectErrorContains( bAction, cExpected, cOperation )
   LOCAL bOldError := ErrorBlock( {|oError| Break( oError ) } )
   LOCAL lRaised := .F.
   LOCAL cActual := "no error"
   LOCAL oErr

   BEGIN SEQUENCE
      Eval( bAction )
   RECOVER USING oErr
      lRaised := .T.
      cActual := IIf( HB_ISOBJECT( oErr ), oErr:Description, "error" )
   END SEQUENCE

   ErrorBlock( bOldError )
   __SetTrace( cOperation, cExpected, cActual )
RETURN lRaised .AND. cExpected $ cActual

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
   lOk := __RunTest( "Test_Div_Exact_NoPrecision", Test_Div_Exact_NoPrecision() ) .AND. lOk
   lOk := __RunTest( "Test_Div_NonTerminating_RequiresPrecision", Test_Div_NonTerminating_RequiresPrecision() ) .AND. lOk

   ? "== PRECISION/ROUNDING TESTS =="
   __LogLine( "GROUP", "== PRECISION/ROUNDING TESTS ==", HB_LOG_INFO )
   lOk := __RunTest( "Test_Context_DefaultPrecision", Test_Context_DefaultPrecision() ) .AND. lOk
   lOk := __RunTest( "Test_Context_InstancePrecision", Test_Context_InstancePrecision() ) .AND. lOk
   lOk := __RunTest( "Test_Context_Propagation", Test_Context_Propagation() ) .AND. lOk
   lOk := __RunTest( "Test_Truncate_Simple", Test_Truncate_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_Round_HalfUp", Test_Round_HalfUp() ) .AND. lOk
   lOk := __RunTest( "Test_Round_HalfUp_Negative", Test_Round_HalfUp_Negative() ) .AND. lOk
   lOk := __RunTest( "Test_Floor_Negative", Test_Floor_Negative() ) .AND. lOk
   lOk := __RunTest( "Test_Ceiling_Positive", Test_Ceiling_Positive() ) .AND. lOk
   lOk := __RunTest( "Test_Rounding_NoMutation", Test_Rounding_NoMutation() ) .AND. lOk

   ? "== ROOT/LOG TESTS =="
   __LogLine( "GROUP", "== ROOT/LOG TESTS ==", HB_LOG_INFO )
   lOk := __RunTest( "Test_RootContext_DefaultPrecision", Test_RootContext_DefaultPrecision() ) .AND. lOk
   lOk := __RunTest( "Test_RootContext_InstancePropagation", Test_RootContext_InstancePropagation() ) .AND. lOk
   lOk := __RunTest( "Test_Sqrt_Exact_NoPrecision", Test_Sqrt_Exact_NoPrecision() ) .AND. lOk
   lOk := __RunTest( "Test_Sqrt_NonTerminating_RequiresPrecision", Test_Sqrt_NonTerminating_RequiresPrecision() ) .AND. lOk
   lOk := __RunTest( "Test_NthRoot_ExactNegativeOdd", Test_NthRoot_ExactNegativeOdd() ) .AND. lOk
   lOk := __RunTest( "Test_LogContext_DefaultPrecision", Test_LogContext_DefaultPrecision() ) .AND. lOk
   lOk := __RunTest( "Test_LogContext_InstancePropagation", Test_LogContext_InstancePropagation() ) .AND. lOk
   lOk := __RunTest( "Test_Log_Exact_NoPrecision_Integer", Test_Log_Exact_NoPrecision_Integer() ) .AND. lOk
   lOk := __RunTest( "Test_Log_Exact_NoPrecision_TerminatingRatio", Test_Log_Exact_NoPrecision_TerminatingRatio() ) .AND. lOk
   lOk := __RunTest( "Test_Log_Exact_NoPrecision_NegativeExponent", Test_Log_Exact_NoPrecision_NegativeExponent() ) .AND. lOk
   lOk := __RunTest( "Test_Log_NonTerminating_RequiresPrecision", Test_Log_NonTerminating_RequiresPrecision() ) .AND. lOk
   lOk := __RunTest( "Test_Ln_ExactOne_NoPrecision", Test_Ln_ExactOne_NoPrecision() ) .AND. lOk
   lOk := __RunTest( "Test_NthRoot_Approx_WithPrecision", Test_NthRoot_Approx_WithPrecision() ) .AND. lOk

   ? "== DOMAIN/POLICY TESTS =="
   __LogLine( "GROUP", "== DOMAIN/POLICY TESTS ==", HB_LOG_INFO )
   lOk := __RunTest( "Test_Div_ByZero_Error", Test_Div_ByZero_Error() ) .AND. lOk
   lOk := __RunTest( "Test_Sqrt_Negative_Error", Test_Sqrt_Negative_Error() ) .AND. lOk
   lOk := __RunTest( "Test_NthRoot_DegreeZero_Error", Test_NthRoot_DegreeZero_Error() ) .AND. lOk
   lOk := __RunTest( "Test_NthRoot_EvenNegative_Error", Test_NthRoot_EvenNegative_Error() ) .AND. lOk
   lOk := __RunTest( "Test_Log_InvalidBaseOne_Error", Test_Log_InvalidBaseOne_Error() ) .AND. lOk
   lOk := __RunTest( "Test_Log_NonPositiveValue_Error", Test_Log_NonPositiveValue_Error() ) .AND. lOk
   lOk := __RunTest( "Test_Log10_NonPositive_Error", Test_Log10_NonPositive_Error() ) .AND. lOk
   lOk := __RunTest( "Test_Ln_NonPositive_Error", Test_Ln_NonPositive_Error() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_NegativeExponent_Error", Test_PowInt_NegativeExponent_Error() ) .AND. lOk

   ? "== EXT TESTS =="
   __LogLine( "GROUP", "== EXT TESTS ==", HB_LOG_INFO )
   lOk := __RunTest( "Test_Compare_Eq", Test_Compare_Eq() ) .AND. lOk
   lOk := __RunTest( "Test_Compare_Order", Test_Compare_Order() ) .AND. lOk
   lOk := __RunTest( "Test_Compare_RawMatrix", Test_Compare_RawMatrix() ) .AND. lOk
   lOk := __RunTest( "Test_Compare_ScaledOrdering", Test_Compare_ScaledOrdering() ) .AND. lOk
   lOk := __RunTest( "Test_Compare_ZeroScaled", Test_Compare_ZeroScaled() ) .AND. lOk
   lOk := __RunTest( "Test_Min_Max", Test_Min_Max() ) .AND. lOk
   lOk := __RunTest( "Test_Mod_Simple", Test_Mod_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_Mod_NegativeDividend", Test_Mod_NegativeDividend() ) .AND. lOk
   lOk := __RunTest( "Test_Mod_NegativeDivisor", Test_Mod_NegativeDivisor() ) .AND. lOk
   lOk := __RunTest( "Test_Mod_BothNegative", Test_Mod_BothNegative() ) .AND. lOk
   lOk := __RunTest( "Test_Mod_DecimalScale", Test_Mod_DecimalScale() ) .AND. lOk
   lOk := __RunTest( "Test_Mod_ScaledDividendLessThanDivisor", Test_Mod_ScaledDividendLessThanDivisor() ) .AND. lOk
   lOk := __RunTest( "Test_Mod_NoMutation", Test_Mod_NoMutation() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_Simple", Test_PowInt_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_ZeroExponent", Test_PowInt_ZeroExponent() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_NegativeBase", Test_PowInt_NegativeBase() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_EvenNegativeBase", Test_PowInt_EvenNegativeBase() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_DecimalBase", Test_PowInt_DecimalBase() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_ZeroBasePositiveExponent", Test_PowInt_ZeroBasePositiveExponent() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_NoMutation", Test_PowInt_NoMutation() ) .AND. lOk

   ? "== NUMBER THEORY TESTS =="
   __LogLine( "GROUP", "== NUMBER THEORY TESTS ==", HB_LOG_INFO )
   lOk := __RunTest( "Test_Gcd_Simple", Test_Gcd_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_Gcd_Zero", Test_Gcd_Zero() ) .AND. lOk
   lOk := __RunTest( "Test_Gcd_Negative", Test_Gcd_Negative() ) .AND. lOk
   lOk := __RunTest( "Test_Gcd_Coprime", Test_Gcd_Coprime() ) .AND. lOk
   lOk := __RunTest( "Test_Gcd_LargeCommonFactor", Test_Gcd_LargeCommonFactor() ) .AND. lOk
   lOk := __RunTest( "Test_Gcd_NoMutation", Test_Gcd_NoMutation() ) .AND. lOk
   lOk := __RunTest( "Test_Lcm_Simple", Test_Lcm_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_Lcm_Zero", Test_Lcm_Zero() ) .AND. lOk
   lOk := __RunTest( "Test_Lcm_Negative", Test_Lcm_Negative() ) .AND. lOk
   lOk := __RunTest( "Test_Lcm_Coprime", Test_Lcm_Coprime() ) .AND. lOk
   lOk := __RunTest( "Test_Lcm_LargeCommonFactor", Test_Lcm_LargeCommonFactor() ) .AND. lOk
   lOk := __RunTest( "Test_Lcm_NoMutation", Test_Lcm_NoMutation() ) .AND. lOk

   ? "== tBigNtst COMPAT TESTS =="
   __LogLine( "GROUP", "== tBigNtst COMPAT TESTS ==", HB_LOG_INFO )
   lOk := __RunTest( "Test_TBigNtst_Add_RepeatedDelta", Test_TBigNtst_Add_RepeatedDelta() ) .AND. lOk
   lOk := __RunTest( "Test_TBigNtst_Add_PaddedZeroSeed", Test_TBigNtst_Add_PaddedZeroSeed() ) .AND. lOk
   lOk := __RunTest( "Test_TBigNtst_Add_NegativeRepeatedDelta", Test_TBigNtst_Add_NegativeRepeatedDelta() ) .AND. lOk
   lOk := __RunTest( "Test_TBigNtst_Sub_NegativeRepeatedOperand", Test_TBigNtst_Sub_NegativeRepeatedOperand() ) .AND. lOk
   lOk := __RunTest( "Test_TBigNtst_Mul_RepeatedOnePointFive", Test_TBigNtst_Mul_RepeatedOnePointFive() ) .AND. lOk
   lOk := __RunTest( "Test_TBigNtst_Mul_RepeatedThreePointFiveFiveFive", Test_TBigNtst_Mul_RepeatedThreePointFiveFiveFive() ) .AND. lOk
   lOk := __RunTest( "Test_TBigNtst_Div_RecurringWithPrecision", Test_TBigNtst_Div_RecurringWithPrecision() ) .AND. lOk
   lOk := __RunTest( "Test_TBigNtst_Sqrt_PerfectSquare", Test_TBigNtst_Sqrt_PerfectSquare() ) .AND. lOk
   lOk := __RunTest( "Test_TBigNtst_Log_PowerOfTenInventory", Test_TBigNtst_Log_PowerOfTenInventory() ) .AND. lOk
   lOk := __RunTest( "Test_TBigNtst_Ln_WithPrecision", Test_TBigNtst_Ln_WithPrecision() ) .AND. lOk

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


FUNCTION Test_Div_Exact_NoPrecision()
   LOCAL nOld := HBNumGetDefaultPrecision()
   LOCAL oA := HBNum():New( "1" )
   LOCAL oR
   LOCAL cActual

   HBNumSetDefaultPrecision( NIL )
   oR := oA:Div( "8" )
   HBNumSetDefaultPrecision( nOld )

   cActual := oR:ToString()
   __SetTrace( "1 / 8 sem precision/context limit", "0.125", cActual )
RETURN cActual == "0.125"


FUNCTION Test_Div_NonTerminating_RequiresPrecision()
   LOCAL nOld := HBNumGetDefaultPrecision()
   LOCAL bOldError
   LOCAL lRaised := .F.
   LOCAL cActual := "no error"
   LOCAL oErr

   bOldError := ErrorBlock( {|oErr| Break( oErr ) } )
   HBNumSetDefaultPrecision( NIL )
   BEGIN SEQUENCE
      HBNum():New( "1" ):Div( "3" )
   RECOVER USING oErr
      lRaised := .T.
      cActual := IIf( HB_ISOBJECT( oErr ), oErr:Description, "error" )
   END SEQUENCE
   ErrorBlock( bOldError )
   HBNumSetDefaultPrecision( nOld )

   __SetTrace( "1 / 3 sem precision/context limit", "Non-terminating decimal division", cActual )
RETURN lRaised .AND. "Non-terminating decimal division" $ cActual


FUNCTION Test_Context_DefaultPrecision()
   LOCAL nOld := HBNumGetDefaultPrecision()
   LOCAL oA
   LOCAL oR
   LOCAL cActual

   HBNumSetDefaultPrecision( 4 )
   oA := HBNum():New( "1" )
   oR := oA:Div( "8" )
   HBNumSetDefaultPrecision( nOld )

   cActual := oR:ToString()
   __SetTrace( "default context precision 4 on 1 / 8", "0.1250", cActual )
RETURN cActual == "0.1250"


FUNCTION Test_Context_InstancePrecision()
   LOCAL oA := HBNum():New( "1" )
   LOCAL oR
   LOCAL cActual

   oA:SetPrecision( 3 )
   oR := oA:Div( "8" )
   cActual := oR:ToString()

   __SetTrace( "instance precision 3 on 1 / 8", "0.125", cActual )
RETURN cActual == "0.125"


FUNCTION Test_Context_Propagation()
   LOCAL oA := HBNum():New( "10" )
   LOCAL oMid
   LOCAL oR
   LOCAL cActual

   oA:SetPrecision( 2 )
   oMid := oA:Abs()
   oR := oMid:Div( "4" )
   cActual := oR:ToString()

   __SetTrace( "context propagation across Abs() then Div()", "2.50", cActual )
RETURN cActual == "2.50"


FUNCTION Test_RootContext_DefaultPrecision()
   LOCAL nOld := HBNumGetDefaultRootPrecision()
   LOCAL oA
   LOCAL oR
   LOCAL cActual

   HBNumSetDefaultRootPrecision( 4 )
   oA := HBNum():New( "2" )
   oR := oA:Sqrt()
   HBNumSetDefaultRootPrecision( nOld )

   cActual := oR:ToString()
   __SetTrace( "default root precision 4 on sqrt(2)", "1.4142", cActual )
RETURN cActual == "1.4142"


FUNCTION Test_RootContext_InstancePropagation()
   LOCAL oA := HBNum():New( "2" )
   LOCAL oMid
   LOCAL oR
   LOCAL cActual

   oA:SetRootPrecision( 3 )
   oMid := oA:Abs()
   oR := oMid:Sqrt()
   cActual := oR:ToString()

   __SetTrace( "instance root precision 3 propagated via Abs() then sqrt(2)", "1.414", cActual )
RETURN cActual == "1.414"


FUNCTION Test_Sqrt_Exact_NoPrecision()
   LOCAL nOld := HBNumGetDefaultRootPrecision()
   LOCAL oA := HBNum():New( "0.25" )
   LOCAL oR
   LOCAL cActual

   HBNumSetDefaultRootPrecision( NIL )
   oR := oA:Sqrt()
   HBNumSetDefaultRootPrecision( nOld )

   cActual := oR:ToString()
   __SetTrace( "sqrt(0.25) sem precision/context limit", "0.5", cActual )
RETURN cActual == "0.5"


FUNCTION Test_Sqrt_NonTerminating_RequiresPrecision()
   LOCAL nOld := HBNumGetDefaultRootPrecision()
   LOCAL bOldError
   LOCAL lRaised := .F.
   LOCAL cActual := "no error"
   LOCAL oErr

   bOldError := ErrorBlock( {|oError| Break( oError ) } )
   HBNumSetDefaultRootPrecision( NIL )
   BEGIN SEQUENCE
      HBNum():New( "2" ):Sqrt()
   RECOVER USING oErr
      lRaised := .T.
      cActual := IIf( HB_ISOBJECT( oErr ), oErr:Description, "error" )
   END SEQUENCE
   ErrorBlock( bOldError )
   HBNumSetDefaultRootPrecision( nOld )

   __SetTrace( "sqrt(2) sem precision/context limit", "Non-terminating square root", cActual )
RETURN lRaised .AND. "Non-terminating square root" $ cActual


FUNCTION Test_NthRoot_ExactNegativeOdd()
   LOCAL nOld := HBNumGetDefaultRootPrecision()
   LOCAL oA := HBNum():New( "-8" )
   LOCAL oR
   LOCAL cActual

   HBNumSetDefaultRootPrecision( NIL )
   oR := oA:NthRoot( 3 )
   HBNumSetDefaultRootPrecision( nOld )

   cActual := oR:ToString()
   __SetTrace( "NthRoot(-8, 3) sem precision/context limit", "-2", cActual )
RETURN cActual == "-2"


FUNCTION Test_LogContext_DefaultPrecision()
   LOCAL nOld := HBNumGetDefaultLogPrecision()
   LOCAL oA
   LOCAL oR
   LOCAL cActual

   HBNumSetDefaultLogPrecision( 2 )
   oA := HBNum():New( "2" )
   oR := oA:Log10()
   HBNumSetDefaultLogPrecision( nOld )

   cActual := oR:ToString()
   __SetTrace( "default log precision 2 on log10(2)", "0.30", cActual )
RETURN cActual == "0.30"


FUNCTION Test_LogContext_InstancePropagation()
   LOCAL oA := HBNum():New( "2" )
   LOCAL oMid
   LOCAL oR
   LOCAL cActual

   oA:SetLogPrecision( 2 )
   oMid := oA:Abs()
   oR := oMid:Log10()
   cActual := oR:ToString()

   __SetTrace( "instance log precision 2 propagated via Abs() then log10(2)", "0.30", cActual )
RETURN cActual == "0.30"


FUNCTION Test_Log_Exact_NoPrecision_Integer()
   LOCAL nOld := HBNumGetDefaultLogPrecision()
   LOCAL oA := HBNum():New( "1000" )
   LOCAL oR
   LOCAL cActual

   HBNumSetDefaultLogPrecision( NIL )
   oR := oA:Log( "10" )
   HBNumSetDefaultLogPrecision( nOld )

   cActual := oR:ToString()
   __SetTrace( "log base 10 de 1000 sem precision/context limit", "3", cActual )
RETURN cActual == "3"


FUNCTION Test_Log_Exact_NoPrecision_TerminatingRatio()
   LOCAL nOld := HBNumGetDefaultLogPrecision()
   LOCAL oA := HBNum():New( "10" )
   LOCAL oR
   LOCAL cActual

   HBNumSetDefaultLogPrecision( NIL )
   oR := oA:Log( "100" )
   HBNumSetDefaultLogPrecision( nOld )

   cActual := oR:ToString()
   __SetTrace( "log base 100 de 10 sem precision/context limit", "0.5", cActual )
RETURN cActual == "0.5"


FUNCTION Test_Log_Exact_NoPrecision_NegativeExponent()
   LOCAL nOld := HBNumGetDefaultLogPrecision()
   LOCAL oA := HBNum():New( "0.125" )
   LOCAL oR
   LOCAL cActual

   HBNumSetDefaultLogPrecision( NIL )
   oR := oA:Log( "2" )
   HBNumSetDefaultLogPrecision( nOld )

   cActual := oR:ToString()
   __SetTrace( "log base 2 de 0.125 sem precision/context limit", "-3", cActual )
RETURN cActual == "-3"


FUNCTION Test_Log_NonTerminating_RequiresPrecision()
   LOCAL nOld := HBNumGetDefaultLogPrecision()
   LOCAL bOldError
   LOCAL lRaised := .F.
   LOCAL cActual := "no error"
   LOCAL oErr

   bOldError := ErrorBlock( {|oError| Break( oError ) } )
   HBNumSetDefaultLogPrecision( NIL )
   BEGIN SEQUENCE
      HBNum():New( "2" ):Log( "10" )
   RECOVER USING oErr
      lRaised := .T.
      cActual := IIf( HB_ISOBJECT( oErr ), oErr:Description, "error" )
   END SEQUENCE
   ErrorBlock( bOldError )
   HBNumSetDefaultLogPrecision( nOld )

   __SetTrace( "log base 10 de 2 sem precision/context limit", "Non-terminating logarithm", cActual )
RETURN lRaised .AND. "Non-terminating logarithm" $ cActual


FUNCTION Test_Ln_ExactOne_NoPrecision()
   LOCAL nOld := HBNumGetDefaultLogPrecision()
   LOCAL oA := HBNum():New( "1" )
   LOCAL oR
   LOCAL cActual

   HBNumSetDefaultLogPrecision( NIL )
   oR := oA:Ln()
   HBNumSetDefaultLogPrecision( nOld )

   cActual := oR:ToString()
   __SetTrace( "ln(1) sem precision/context limit", "0", cActual )
RETURN cActual == "0"


FUNCTION Test_NthRoot_Approx_WithPrecision()
   LOCAL oA := HBNum():New( "2" )
   LOCAL oR := oA:NthRoot( 2, 12 )
   LOCAL cActual := oR:ToString()

   __SetTrace( "NthRoot(2, 2, 12)", "1.414213562373", cActual )
RETURN cActual == "1.414213562373"


FUNCTION Test_Div_ByZero_Error()
RETURN __ExpectErrorContains( ;
   {|| HBNum():New( "10" ):Div( "0", 2 ) }, ;
   "Division by zero", ;
   "10 / 0 (precision 2)" )


FUNCTION Test_Sqrt_Negative_Error()
RETURN __ExpectErrorContains( ;
   {|| HBNum():New( "-4" ):Sqrt( 2 ) }, ;
   "Square root is undefined for negative numbers", ;
   "sqrt(-4, 2)" )


FUNCTION Test_NthRoot_DegreeZero_Error()
RETURN __ExpectErrorContains( ;
   {|| HBNum():New( "9" ):NthRoot( 0, 2 ) }, ;
   "NthRoot degree must be > 0", ;
   "NthRoot(9, 0, 2)" )


FUNCTION Test_NthRoot_EvenNegative_Error()
RETURN __ExpectErrorContains( ;
   {|| HBNum():New( "-16" ):NthRoot( 2, 4 ) }, ;
   "Even-degree root of a negative number is undefined", ;
   "NthRoot(-16, 2, 4)" )


FUNCTION Test_Log_InvalidBaseOne_Error()
RETURN __ExpectErrorContains( ;
   {|| HBNum():New( "1000" ):Log( "1", 6 ) }, ;
   "base != 1", ;
   "log base 1 of 1000 (precision 6)" )


FUNCTION Test_Log_NonPositiveValue_Error()
RETURN __ExpectErrorContains( ;
   {|| HBNum():New( "0" ):Log( "10", 6 ) }, ;
   "x > 0 and base > 0", ;
   "log base 10 of 0 (precision 6)" )


FUNCTION Test_Log10_NonPositive_Error()
RETURN __ExpectErrorContains( ;
   {|| HBNum():New( "0" ):Log10( 6 ) }, ;
   "Base-10 logarithm requires x > 0", ;
   "log10(0, 6)" )


FUNCTION Test_Ln_NonPositive_Error()
RETURN __ExpectErrorContains( ;
   {|| HBNum():New( "-1" ):Ln( 6 ) }, ;
   "Natural logarithm requires x > 0", ;
   "ln(-1, 6)" )


FUNCTION Test_PowInt_NegativeExponent_Error()
RETURN __ExpectErrorContains( ;
   {|| HBNum():New( "2" ):PowInt( -1 ) }, ;
   "PowInt exponent must be >= 0", ;
   "2^(-1) via PowInt" )


FUNCTION Test_Truncate_Simple()
   LOCAL oA := HBNum():New( "12.349" )
   LOCAL oR := oA:Truncate( 2 )
   LOCAL cExpected := "12.34"
   LOCAL cActual := oR:ToString()

   __SetTrace( "Truncate(12.349, 2)", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Round_HalfUp()
   LOCAL oA := HBNum():New( "12.345" )
   LOCAL oR := oA:Round( 2 )
   LOCAL cExpected := "12.35"
   LOCAL cActual := oR:ToString()

   __SetTrace( "Round(12.345, 2)", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Round_HalfUp_Negative()
   LOCAL oA := HBNum():New( "-12.345" )
   LOCAL oR := oA:Round( 2 )
   LOCAL cExpected := "-12.35"
   LOCAL cActual := oR:ToString()

   __SetTrace( "Round(-12.345, 2)", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Floor_Negative()
   LOCAL oA := HBNum():New( "-12.341" )
   LOCAL oR := oA:Floor( 1 )
   LOCAL cExpected := "-12.4"
   LOCAL cActual := oR:ToString()

   __SetTrace( "Floor(-12.341, 1)", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Ceiling_Positive()
   LOCAL oA := HBNum():New( "12.341" )
   LOCAL oR := oA:Ceiling( 1 )
   LOCAL cExpected := "12.4"
   LOCAL cActual := oR:ToString()

   __SetTrace( "Ceiling(12.341, 1)", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Rounding_NoMutation()
   LOCAL oA := HBNum():New( "-12.345" )
   LOCAL cA := oA:ToString()
   LOCAL oR := oA:Round( 2 )
   LOCAL lResult := cA == oA:ToString() .AND. oR:ToString() == "-12.35"
   LOCAL cActual := "A=" + oA:ToString() + ", R=" + oR:ToString()

   __SetTrace( "imutabilidade de entrada em Round(-12.345, 2)", "A=-12.345, R=-12.35", cActual )
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


FUNCTION Test_Compare_RawMatrix()
   LOCAL oNeg := HBNum():New( "-0.125" )
   LOCAL oZero := HBNum():New( "0.000" )
   LOCAL oPos := HBNum():New( "0.1250" )
   LOCAL lResult := ;
      oNeg:Compare( oZero ) < 0 .AND. ;
      oZero:Compare( oPos ) < 0 .AND. ;
      oPos:Compare( oNeg ) > 0
   LOCAL cActual := ;
      "neg/zero=" + hb_ntos( oNeg:Compare( oZero ) ) + ;
      ", zero/pos=" + hb_ntos( oZero:Compare( oPos ) ) + ;
      ", pos/neg=" + hb_ntos( oPos:Compare( oNeg ) )

   __SetTrace( "matriz Compare(-0.125, 0.000, 0.1250)", "neg/zero<0, zero/pos<0, pos/neg>0", cActual )
RETURN lResult


FUNCTION Test_Compare_ScaledOrdering()
   LOCAL oA := HBNum():New( "1.2001" )
   LOCAL oB := HBNum():New( "1.2" )
   LOCAL lResult := oA:Gt( oB ) .AND. oB:Lt( oA ) .AND. oA:Compare( oB ) == 1
   LOCAL cActual := ;
      "A>B=" + IIf( oA:Gt( oB ), ".T.", ".F." ) + ;
      ", B<A=" + IIf( oB:Lt( oA ), ".T.", ".F." ) + ;
      ", compare=" + hb_ntos( oA:Compare( oB ) )

   __SetTrace( "1.2001 > 1.2", "A>B=.T., B<A=.T., compare=1", cActual )
RETURN lResult


FUNCTION Test_Compare_ZeroScaled()
   LOCAL oA := HBNum():New( "0.0000" )
   LOCAL oB := HBNum():New( "0" )
   LOCAL lResult := oA:Eq( oB ) .AND. oA:Compare( oB ) == 0 .AND. oA:IsZero() .AND. oB:IsZero()
   LOCAL cActual := ;
      "Eq=" + IIf( oA:Eq( oB ), ".T.", ".F." ) + ;
      ", compare=" + hb_ntos( oA:Compare( oB ) ) + ;
      ", zeroA=" + IIf( oA:IsZero(), ".T.", ".F." ) + ;
      ", zeroB=" + IIf( oB:IsZero(), ".T.", ".F." )

   __SetTrace( "0.0000 == 0", "Eq=.T., compare=0, zeroA=.T., zeroB=.T.", cActual )
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


FUNCTION Test_Mod_NegativeDivisor()
   LOCAL oA := HBNum():New( "10" )
   LOCAL oB := HBNum():New( "-3" )
   LOCAL oR := oA:Mod( oB )
   LOCAL cExpected := "1"
   LOCAL cActual := oR:ToString()

   __SetTrace( "10 % -3 (trunc toward zero)", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Mod_BothNegative()
   LOCAL oA := HBNum():New( "-10" )
   LOCAL oB := HBNum():New( "-3" )
   LOCAL oR := oA:Mod( oB )
   LOCAL cExpected := "-1"
   LOCAL cActual := oR:ToString()

   __SetTrace( "-10 % -3 (trunc toward zero)", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Mod_DecimalScale()
   LOCAL oA := HBNum():New( "10.5" )
   LOCAL oB := HBNum():New( "0.2" )
   LOCAL oR := oA:Mod( oB )
   LOCAL cExpected := "0.1"
   LOCAL cActual := oR:ToString()

   __SetTrace( "10.5 % 0.2", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Mod_ScaledDividendLessThanDivisor()
   LOCAL oA := HBNum():New( "1.25" )
   LOCAL oB := HBNum():New( "2" )
   LOCAL oR := oA:Mod( oB )
   LOCAL cExpected := "1.25"
   LOCAL cActual := oR:ToString()

   __SetTrace( "1.25 % 2", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Mod_NoMutation()
   LOCAL oA := HBNum():New( "10.5" )
   LOCAL oB := HBNum():New( "-0.2" )
   LOCAL cA := oA:ToString()
   LOCAL cB := oB:ToString()
   LOCAL oR := oA:Mod( oB )
   LOCAL lResult := ;
      cA == oA:ToString() .AND. ;
      cB == oB:ToString() .AND. ;
      oR:ToString() == "0.1"
   LOCAL cActual := ;
      "A=" + oA:ToString() + ", B=" + oB:ToString() + ", R=" + oR:ToString()

   __SetTrace( "imutabilidade de entrada em 10.5 % (-0.2)", "A=10.5, B=-0.2, R=0.1", cActual )
RETURN lResult


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


FUNCTION Test_PowInt_EvenNegativeBase()
   LOCAL oA := HBNum():New( "-2" )
   LOCAL oR := oA:PowInt( 4 )
   LOCAL cExpected := "16"
   LOCAL cActual := oR:ToString()

   __SetTrace( "(-2)^4", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_PowInt_DecimalBase()
   LOCAL oA := HBNum():New( "1.5" )
   LOCAL oR := oA:PowInt( 3 )
   LOCAL cExpected := "3.375"
   LOCAL cActual := oR:ToString()

   __SetTrace( "(1.5)^3", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_PowInt_ZeroBasePositiveExponent()
   LOCAL oA := HBNum():New( "0" )
   LOCAL oR := oA:PowInt( 5 )
   LOCAL cExpected := "0"
   LOCAL cActual := oR:ToString()

   __SetTrace( "0^5", cExpected, cActual )
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


FUNCTION Test_Gcd_Coprime()
   LOCAL oA := HBNum():New( "123456789012345678901" )
   LOCAL oB := HBNum():New( "123456789012345678902" )
   LOCAL oR := oA:Gcd( oB )
   LOCAL cExpected := "1"
   LOCAL cActual := oR:ToString()

   __SetTrace( "GCD(consecutivos grandes)", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Gcd_LargeCommonFactor()
   LOCAL oA := HBNum():New( "456790119345679011930" )
   LOCAL oB := HBNum():New( "1123456780012345677990" )
   LOCAL oR := oA:Gcd( oB )
   LOCAL cExpected := "12345678901234567890"
   LOCAL cActual := oR:ToString()

   __SetTrace( "GCD(456790119345679011930, 1123456780012345677990)", cExpected, cActual )
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


FUNCTION Test_Lcm_Coprime()
   LOCAL oA := HBNum():New( "123456789012345678901" )
   LOCAL oB := HBNum():New( "123456789012345678902" )
   LOCAL oR := oA:Lcm( oB )
   LOCAL cExpected := "15241578753238836750560890354538942246702"
   LOCAL cActual := oR:ToString()

   __SetTrace( "LCM(consecutivos grandes)", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Lcm_LargeCommonFactor()
   LOCAL oA := HBNum():New( "456790119345679011930" )
   LOCAL oB := HBNum():New( "1123456780012345677990" )
   LOCAL oR := oA:Lcm( oB )
   LOCAL cExpected := "41567900860456790085630"
   LOCAL cActual := oR:ToString()

   __SetTrace( "LCM(456790119345679011930, 1123456780012345677990)", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Lcm_NoMutation()
   LOCAL oA := HBNum():New( "21" )
   LOCAL oB := HBNum():New( "-6" )
   LOCAL cA := oA:ToString()
   LOCAL cB := oB:ToString()
   LOCAL oR := oA:Lcm( oB )
   LOCAL lResult := ;
      cA == oA:ToString() .AND. ;
      cB == oB:ToString() .AND. ;
      oR:ToString() == "42"
   LOCAL cActual := ;
      "A=" + oA:ToString() + ", B=" + oB:ToString() + ", R=" + oR:ToString()

   __SetTrace( "imutabilidade de entrada em LCM(21,-6)", "A=21, B=-6, R=42", cActual )
RETURN lResult


FUNCTION Test_TBigNtst_Add_RepeatedDelta()
   LOCAL oValue := HBNum():New( "1" )
   LOCAL nStep
   LOCAL cActual

   FOR nStep := 1 TO 3
      oValue := oValue:Add( "9999.9999999999" )
   NEXT

   cActual := oValue:ToString()
   __SetTrace( "tBigNtst07 port: 1 + 3*(9999.9999999999)", "30000.9999999997", cActual )
RETURN cActual == "30000.9999999997"


FUNCTION Test_TBigNtst_Add_PaddedZeroSeed()
   LOCAL oValue := HBNum():New( "0.0000000000" )
   LOCAL nStep
   LOCAL cActual

   FOR nStep := 1 TO 3
      oValue := oValue:Add( "9999.9999999999" )
   NEXT

   cActual := oValue:ToString()
   __SetTrace( "tBigNtst08 port: 0.0000000000 + 3*(9999.9999999999)", "29999.9999999997", cActual )
RETURN cActual == "29999.9999999997"


FUNCTION Test_TBigNtst_Add_NegativeRepeatedDelta()
   LOCAL oValue := HBNum():New( "0" )
   LOCAL nStep
   LOCAL cActual

   FOR nStep := 1 TO 3
      oValue := oValue:Add( "-9999.9999999999" )
   NEXT

   cActual := oValue:ToString()
   __SetTrace( "tBigNtst09 port: 0 + 3*(-9999.9999999999)", "-29999.9999999997", cActual )
RETURN cActual == "-29999.9999999997"


FUNCTION Test_TBigNtst_Sub_NegativeRepeatedOperand()
   LOCAL oValue := HBNum():New( "0" )
   LOCAL nStep
   LOCAL cActual

   FOR nStep := 1 TO 3
      oValue := oValue:Sub( "-9999.9999999999" )
   NEXT

   cActual := oValue:ToString()
   __SetTrace( "tBigNtst12 port: 0 - 3*(-9999.9999999999)", "29999.9999999997", cActual )
RETURN cActual == "29999.9999999997"


FUNCTION Test_TBigNtst_Mul_RepeatedOnePointFive()
   LOCAL oValue := HBNum():New( "1" )
   LOCAL nStep
   LOCAL cActual

   FOR nStep := 1 TO 6
      oValue := oValue:Mul( "1.5" )
   NEXT

   cActual := oValue:ToString()
   __SetTrace( "tBigNtst13/14 port: 1 * (1.5^6)", "11.390625", cActual )
RETURN cActual == "11.390625"


FUNCTION Test_TBigNtst_Mul_RepeatedThreePointFiveFiveFive()
   LOCAL oValue := HBNum():New( "1" )
   LOCAL nStep
   LOCAL cActual

   FOR nStep := 1 TO 3
      oValue := oValue:Mul( "3.555" )
   NEXT

   cActual := oValue:ToString()
   __SetTrace( "tBigNtst16/17 port: 1 * (3.555^3)", "44.928178875", cActual )
RETURN cActual == "44.928178875"


FUNCTION Test_TBigNtst_Div_RecurringWithPrecision()
   LOCAL oValue := HBNum():New( "19701215" )
   LOCAL oR := oValue:Div( "1.5", 10 )
   LOCAL cActual := oR:ToString()

   __SetTrace( "tBigNtst22 port: 19701215 / 1.5 (precision 10)", "13134143.3333333333", cActual )
RETURN cActual == "13134143.3333333333"


FUNCTION Test_TBigNtst_Sqrt_PerfectSquare()
   LOCAL oValue := HBNum():New( "9801" )
   LOCAL cActual := oValue:Sqrt():ToString()

   __SetTrace( "tBigNtst25/26 port: sqrt(9801)", "99", cActual )
RETURN cActual == "99"


FUNCTION Test_TBigNtst_Log_PowerOfTenInventory()
   LOCAL oValue := HBNum():New( "1000000000000000000000000000000" )
   LOCAL cLog10 := oValue:Log10():ToString()
   LOCAL cLogBase10 := oValue:Log( "10" ):ToString()
   LOCAL cLogBase1e10 := oValue:Log( "10000000000" ):ToString()
   LOCAL lOk := ;
      cLog10 == "30" .AND. ;
      cLogBase10 == "30" .AND. ;
      cLogBase1e10 == "3"
   LOCAL cActual := ;
      "log10=" + cLog10 + ;
      ", log10base=" + cLogBase10 + ;
      ", log1e10=" + cLogBase1e10

   __SetTrace( ;
      "tBigNtst31 port: power-of-ten logarithm inventory", ;
      "log10=30, log10base=30, log1e10=3", ;
      cActual )
RETURN lOk


FUNCTION Test_TBigNtst_Ln_WithPrecision()
   LOCAL oValue := HBNum():New( "1000000000000000000000000000000" )
   LOCAL cActual := oValue:Ln( 12 ):ToString()

   __SetTrace( "tBigNtst33 port: ln(10^30, 12)", "69.077552789821", cActual )
RETURN cActual == "69.077552789821"
