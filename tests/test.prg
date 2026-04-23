/*
hbnum: Released to Public Domain.
*/
#include "hbnum.ch"
#include "hblog.ch"
#include "hbthread.ch"

#define MOD_D_TEXT    1
#define MOD_D_SCALED  2
#define MOD_D_SCALE   3

STATIC __cLastOperation := ""
STATIC __cLastExpected := ""
STATIC __cLastActual := ""
STATIC __cLogFileName := ""
STATIC __pSpinner := NIL
STATIC __lSpinnerStop := .F.
STATIC __cSpinnerLabel := ""
STATIC __nModRandState := 1

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

STATIC PROCEDURE __SpinnerClear()
   OutStd( Chr( 13 ) + Space( 140 ) + Chr( 13 ) )
RETURN

STATIC PROCEDURE __SpinnerThread( lStop, cLabel )
   LOCAL cFrames := "|/-" + Chr( 92 )
   LOCAL nFrame := 1

   DO WHILE ! lStop
      OutStd( Chr( 13 ) + "[RUN] " + SubStr( cFrames, nFrame, 1 ) + " " + cLabel )
      nFrame := IIf( nFrame >= Len( cFrames ), 1, nFrame + 1 )
      hb_idleSleep( 0.12 )
   ENDDO
RETURN

STATIC PROCEDURE __SpinnerStart( cLabel )
   __SpinnerStop()
   __cSpinnerLabel := cLabel
   __lSpinnerStop := .F.
   __pSpinner := hb_threadStart( HB_THREAD_INHERIT_MEMVARS, @__SpinnerThread(), ;
      @__lSpinnerStop, @__cSpinnerLabel )
RETURN

STATIC PROCEDURE __SpinnerStop()
   LOCAL pSpinner := __pSpinner

   IF pSpinner != NIL
      __lSpinnerStop := .T.
      hb_threadJoin( pSpinner )
      __pSpinner := NIL
   ENDIF

   __SpinnerClear()
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

STATIC FUNCTION __JoinTextArray( aValues )
   LOCAL cOut := ""
   LOCAL nAt

   FOR nAt := 1 TO Len( aValues )
      IF nAt > 1
         cOut += ","
      ENDIF
      cOut += aValues[ nAt ]
   NEXT

RETURN cOut

STATIC PROCEDURE __ModSeedRand( nSeed )
   nSeed := Int( nSeed )

   IF nSeed <= 0
      nSeed := 1
   ENDIF

   __nModRandState := Mod( nSeed, 2147483647 )
   IF __nModRandState <= 0
      __nModRandState += 2147483646
   ENDIF
RETURN

STATIC FUNCTION __ModNextRand()
   __nModRandState := Mod( __nModRandState * 48271, 2147483647 )

   IF __nModRandState <= 0
      __nModRandState += 2147483646
   ENDIF

RETURN __nModRandState

STATIC FUNCTION __ModRandInt( nMin, nMax )
   LOCAL nRange

   IF nMax <= nMin
      RETURN nMin
   ENDIF

   nRange := ( nMax - nMin ) + 1
RETURN nMin + Mod( __ModNextRand(), nRange )

STATIC FUNCTION __ModCanonical( cValue )
   LOCAL cText := AllTrim( cValue )
   LOCAL lNeg := .F.
   LOCAL nDot
   LOCAL cInt
   LOCAL cDec

   IF Empty( cText )
      RETURN "0"
   ENDIF

   IF Left( cText, 1 ) == "+"
      cText := SubStr( cText, 2 )
   ENDIF

   IF Left( cText, 1 ) == "-"
      lNeg := .T.
      cText := SubStr( cText, 2 )
   ENDIF

   nDot := At( ".", cText )
   IF nDot > 0
      cInt := Left( cText, nDot - 1 )
      cDec := SubStr( cText, nDot + 1 )
   ELSE
      cInt := cText
      cDec := ""
   ENDIF

   IF Empty( cInt )
      cInt := "0"
   ENDIF

   DO WHILE Len( cInt ) > 1 .AND. Left( cInt, 1 ) == "0"
      cInt := SubStr( cInt, 2 )
   ENDDO

   DO WHILE ! Empty( cDec ) .AND. Right( cDec, 1 ) == "0"
      cDec := Left( cDec, Len( cDec ) - 1 )
   ENDDO

   IF cInt == "0" .AND. Empty( cDec )
      RETURN "0"
   ENDIF

   cText := cInt
   IF ! Empty( cDec )
      cText += "." + cDec
   ENDIF

   IF lNeg
      cText := "-" + cText
   ENDIF

RETURN cText

STATIC FUNCTION __ModPow10( nExp )
   LOCAL nValue := 1
   LOCAL nPos

   FOR nPos := 1 TO nExp
      nValue *= 10
   NEXT

RETURN nValue

STATIC FUNCTION __ModScaledToText( nScaled, nScale )
   LOCAL lNeg := nScaled < 0
   LOCAL cDigits := __ModCanonical( hb_ntos( Abs( nScaled ) ) )
   LOCAL cText

   IF nScaled == 0
      RETURN "0"
   ENDIF

   IF nScale == 0
      cText := cDigits
   ELSEIF nScale >= Len( cDigits )
      cText := "0." + Replicate( "0", nScale - Len( cDigits ) ) + cDigits
   ELSE
      cText := Left( cDigits, Len( cDigits ) - nScale ) + "." + Right( cDigits, nScale )
   ENDIF

   IF lNeg
      cText := "-" + cText
   ENDIF

RETURN __ModCanonical( cText )

STATIC FUNCTION __ModIntExpectedText( nValue )
RETURN __ModCanonical( hb_ntos( nValue ) )

STATIC FUNCTION __ModMakeDecimalSpec( nScaled, nScale )
RETURN { __ModScaledToText( nScaled, nScale ), nScaled, nScale }

STATIC FUNCTION __ModRandomDecimalSpec( nMaxAbsScaled, nMaxScale )
   LOCAL nScale := __ModRandInt( 0, nMaxScale )
   LOCAL nScaled := __ModRandInt( -nMaxAbsScaled, nMaxAbsScaled )

RETURN __ModMakeDecimalSpec( nScaled, nScale )

STATIC FUNCTION __ModAlignScaled( aSpec, nTargetScale )
RETURN aSpec[ MOD_D_SCALED ] * __ModPow10( nTargetScale - aSpec[ MOD_D_SCALE ] )

STATIC FUNCTION __ModTruncDiv( nNum, nDen )
   LOCAL nQ

   nQ := Int( Abs( nNum ) / Abs( nDen ) )
   IF ( nNum < 0 .AND. nDen > 0 ) .OR. ( nNum > 0 .AND. nDen < 0 )
      nQ := -nQ
   ENDIF

RETURN nQ

STATIC FUNCTION __ModDecimalExpected( aA, aB )
   LOCAL nScale := Max( aA[ MOD_D_SCALE ], aB[ MOD_D_SCALE ] )
   LOCAL nA := __ModAlignScaled( aA, nScale )
   LOCAL nB := __ModAlignScaled( aB, nScale )
   LOCAL nQ := __ModTruncDiv( nA, nB )
   LOCAL nR := nA - ( nQ * nB )

RETURN __ModMakeDecimalSpec( nR, nScale )

STATIC FUNCTION __ModValidateNumber( oNum, cContext )
   LOCAL hNum
   LOCAL nSign
   LOCAL nScale
   LOCAL nUsed
   LOCAL aLimbs
   LOCAL nPos
   LOCAL nLimb

   IF ValType( oNum ) != "O"
      __SetTrace( cContext, "object result", "non-object result" )
      RETURN .F.
   ENDIF

   hNum := oNum:hbNum
   IF ValType( hNum ) != "H"
      __SetTrace( cContext, "hash result", "non-hash hbNum" )
      RETURN .F.
   ENDIF

   nSign := hNum[ HBNUM_SIGN ]
   nScale := hNum[ HBNUM_SCALE ]
   nUsed := hNum[ HBNUM_USED ]
   aLimbs := hNum[ HBNUM_LIMBS ]

   IF ! HB_ISNUMERIC( nSign ) .OR. !( nSign == -1 .OR. nSign == 0 .OR. nSign == 1 )
      __SetTrace( cContext, "valid sign", "invalid sign=" + hb_ValToExp( nSign ) )
      RETURN .F.
   ENDIF

   IF ! HB_ISNUMERIC( nScale ) .OR. nScale < 0
      __SetTrace( cContext, "non-negative scale", "invalid scale=" + hb_ValToExp( nScale ) )
      RETURN .F.
   ENDIF

   IF ! HB_ISNUMERIC( nUsed ) .OR. nUsed < 0
      __SetTrace( cContext, "non-negative used", "invalid used=" + hb_ValToExp( nUsed ) )
      RETURN .F.
   ENDIF

   IF ValType( aLimbs ) != "A"
      __SetTrace( cContext, "limbs array", "non-array limbs" )
      RETURN .F.
   ENDIF

   IF Len( aLimbs ) != nUsed
      __SetTrace( cContext, "used matches limbs len", "used=" + hb_ntos( nUsed ) + ", len=" + hb_ntos( Len( aLimbs ) ) )
      RETURN .F.
   ENDIF

   FOR nPos := 1 TO Len( aLimbs )
      nLimb := aLimbs[ nPos ]
      IF ! HB_ISNUMERIC( nLimb ) .OR. Int( nLimb ) != nLimb .OR. nLimb < 0 .OR. nLimb >= HBNUM_BASE
         __SetTrace( cContext, "limb in range", "limb[" + hb_ntos( nPos ) + "]=" + hb_ValToExp( nLimb ) )
         RETURN .F.
      ENDIF
   NEXT

   IF nUsed == 0
      IF nSign != 0 .OR. nScale != 0
         __SetTrace( cContext, "normalized zero", ;
            "sign=" + hb_ntos( nSign ) + ", scale=" + hb_ntos( nScale ) )
         RETURN .F.
      ENDIF
   ELSE
      IF nSign == 0
         __SetTrace( cContext, "non-zero sign", "sign=0" )
         RETURN .F.
      ENDIF
      IF aLimbs[ Len( aLimbs ) ] == 0
         __SetTrace( cContext, "no leading zero limb", "top limb is zero" )
         RETURN .F.
      ENDIF
   ENDIF

RETURN .T.

FUNCTION Main()
   LOCAL lOk := .T.

   __InitTestLog()

   ? "== ADD TESTS =="
   __LogLine( "GROUP", "== ADD TESTS ==", HB_LOG_INFO )
   __SpinnerStart( "ADD TESTS" )
   lOk := __RunTest( "Test_Add_Simple", Test_Add_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_Add_Carry", Test_Add_Carry() ) .AND. lOk
   lOk := __RunTest( "Test_Add_DifferentSize", Test_Add_DifferentSize() ) .AND. lOk
   lOk := __RunTest( "Test_Add_Negative", Test_Add_Negative() ) .AND. lOk
   lOk := __RunTest( "Test_Add_Zero", Test_Add_Zero() ) .AND. lOk
   lOk := __RunTest( "Test_Add_Internal", Test_Add_Internal() ) .AND. lOk
   lOk := __RunTest( "Test_Add_Commutative", Test_Add_Commutative() ) .AND. lOk
   lOk := __RunTest( "Test_Add_NoMutation", Test_Add_NoMutation() ) .AND. lOk
   __SpinnerStop()

   ? "== SUB TESTS =="
   __LogLine( "GROUP", "== SUB TESTS ==", HB_LOG_INFO )
   __SpinnerStart( "SUB TESTS" )
   lOk := __RunTest( "Test_Sub_Simple", Test_Sub_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_Sub_Borrow", Test_Sub_Borrow() ) .AND. lOk
   lOk := __RunTest( "Test_Sub_DifferentSize", Test_Sub_DifferentSize() ) .AND. lOk
   lOk := __RunTest( "Test_Sub_Negative", Test_Sub_Negative() ) .AND. lOk
   lOk := __RunTest( "Test_Sub_Zero", Test_Sub_Zero() ) .AND. lOk
   lOk := __RunTest( "Test_Sub_NoMutation", Test_Sub_NoMutation() ) .AND. lOk
   __SpinnerStop()

   ? "== MUL TESTS =="
   __LogLine( "GROUP", "== MUL TESTS ==", HB_LOG_INFO )
   __SpinnerStart( "MUL TESTS" )
   lOk := __RunTest( "Test_Mul_Simple", Test_Mul_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_Mul_Carry", Test_Mul_Carry() ) .AND. lOk
   lOk := __RunTest( "Test_Mul_DifferentSize", Test_Mul_DifferentSize() ) .AND. lOk
   lOk := __RunTest( "Test_Mul_Negative", Test_Mul_Negative() ) .AND. lOk
   lOk := __RunTest( "Test_Mul_Zero", Test_Mul_Zero() ) .AND. lOk
   lOk := __RunTest( "Test_Mul_NoMutation", Test_Mul_NoMutation() ) .AND. lOk
   __SpinnerStop()

   ? "== DIV TESTS =="
   __LogLine( "GROUP", "== DIV TESTS ==", HB_LOG_INFO )
   __SpinnerStart( "DIV TESTS" )
   lOk := __RunTest( "Test_Div_Simple", Test_Div_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_Div_Truncate", Test_Div_Truncate() ) .AND. lOk
   lOk := __RunTest( "Test_Div_Precision", Test_Div_Precision() ) .AND. lOk
   lOk := __RunTest( "Test_Div_Negative", Test_Div_Negative() ) .AND. lOk
   lOk := __RunTest( "Test_Div_ZeroNumerator", Test_Div_ZeroNumerator() ) .AND. lOk
   lOk := __RunTest( "Test_Div_NoMutation", Test_Div_NoMutation() ) .AND. lOk
   lOk := __RunTest( "Test_Div_Exact_NoPrecision", Test_Div_Exact_NoPrecision() ) .AND. lOk
   lOk := __RunTest( "Test_Div_NonTerminating_RequiresPrecision", Test_Div_NonTerminating_RequiresPrecision() ) .AND. lOk
   __SpinnerStop()

   ? "== PRECISION/ROUNDING TESTS =="
   __LogLine( "GROUP", "== PRECISION/ROUNDING TESTS ==", HB_LOG_INFO )
   __SpinnerStart( "PRECISION/ROUNDING TESTS" )
   lOk := __RunTest( "Test_Context_DefaultPrecision", Test_Context_DefaultPrecision() ) .AND. lOk
   lOk := __RunTest( "Test_Context_InstancePrecision", Test_Context_InstancePrecision() ) .AND. lOk
   lOk := __RunTest( "Test_Context_Propagation", Test_Context_Propagation() ) .AND. lOk
   lOk := __RunTest( "Test_Truncate_Simple", Test_Truncate_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_Round_HalfUp", Test_Round_HalfUp() ) .AND. lOk
   lOk := __RunTest( "Test_Round_HalfUp_Negative", Test_Round_HalfUp_Negative() ) .AND. lOk
   lOk := __RunTest( "Test_Floor_Negative", Test_Floor_Negative() ) .AND. lOk
   lOk := __RunTest( "Test_Ceiling_Positive", Test_Ceiling_Positive() ) .AND. lOk
   lOk := __RunTest( "Test_Rounding_NoMutation", Test_Rounding_NoMutation() ) .AND. lOk
   __SpinnerStop()

   ? "== ROOT/LOG TESTS =="
   __LogLine( "GROUP", "== ROOT/LOG TESTS ==", HB_LOG_INFO )
   __SpinnerStart( "ROOT/LOG TESTS" )
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
   __SpinnerStop()

   ? "== DOMAIN/POLICY TESTS =="
   __LogLine( "GROUP", "== DOMAIN/POLICY TESTS ==", HB_LOG_INFO )
   __SpinnerStart( "DOMAIN/POLICY TESTS" )
   lOk := __RunTest( "Test_Div_ByZero_Error", Test_Div_ByZero_Error() ) .AND. lOk
   lOk := __RunTest( "Test_Sqrt_Negative_Error", Test_Sqrt_Negative_Error() ) .AND. lOk
   lOk := __RunTest( "Test_NthRoot_DegreeZero_Error", Test_NthRoot_DegreeZero_Error() ) .AND. lOk
   lOk := __RunTest( "Test_NthRoot_EvenNegative_Error", Test_NthRoot_EvenNegative_Error() ) .AND. lOk
   lOk := __RunTest( "Test_Log_InvalidBaseOne_Error", Test_Log_InvalidBaseOne_Error() ) .AND. lOk
   lOk := __RunTest( "Test_Log_NonPositiveValue_Error", Test_Log_NonPositiveValue_Error() ) .AND. lOk
   lOk := __RunTest( "Test_Log10_NonPositive_Error", Test_Log10_NonPositive_Error() ) .AND. lOk
   lOk := __RunTest( "Test_Ln_NonPositive_Error", Test_Ln_NonPositive_Error() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_NegativeExponent_Error", Test_PowInt_NegativeExponent_Error() ) .AND. lOk
   __SpinnerStop()

   ? "== EXT TESTS =="
   __LogLine( "GROUP", "== EXT TESTS ==", HB_LOG_INFO )
   __SpinnerStart( "EXT TESTS" )
   lOk := __RunTest( "Test_Compare_Eq", Test_Compare_Eq() ) .AND. lOk
   lOk := __RunTest( "Test_Compare_Order", Test_Compare_Order() ) .AND. lOk
   lOk := __RunTest( "Test_Compare_RawMatrix", Test_Compare_RawMatrix() ) .AND. lOk
   lOk := __RunTest( "Test_Compare_ScaledOrdering", Test_Compare_ScaledOrdering() ) .AND. lOk
   lOk := __RunTest( "Test_Compare_ZeroScaled", Test_Compare_ZeroScaled() ) .AND. lOk
   lOk := __RunTest( "Test_Min_Max", Test_Min_Max() ) .AND. lOk
   lOk := __RunTest( "Test_Format_Scientific_Exact", Test_Format_Scientific_Exact() ) .AND. lOk
   lOk := __RunTest( "Test_Format_Scientific_SignificantDigits", Test_Format_Scientific_SignificantDigits() ) .AND. lOk
   lOk := __RunTest( "Test_Format_Engineering_Exact", Test_Format_Engineering_Exact() ) .AND. lOk
   lOk := __RunTest( "Test_Format_Engineering_SignificantDigits", Test_Format_Engineering_SignificantDigits() ) .AND. lOk
   lOk := __RunTest( "Test_Format_NoMutation", Test_Format_NoMutation() ) .AND. lOk
   lOk := __RunTest( "Test_Mod_Simple", Test_Mod_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_Mod_NegativeDividend", Test_Mod_NegativeDividend() ) .AND. lOk
   lOk := __RunTest( "Test_Mod_NegativeDivisor", Test_Mod_NegativeDivisor() ) .AND. lOk
   lOk := __RunTest( "Test_Mod_BothNegative", Test_Mod_BothNegative() ) .AND. lOk
   lOk := __RunTest( "Test_Mod_DecimalScale", Test_Mod_DecimalScale() ) .AND. lOk
   lOk := __RunTest( "Test_Mod_ScaledDividendLessThanDivisor", Test_Mod_ScaledDividendLessThanDivisor() ) .AND. lOk
   lOk := __RunTest( "Test_Mod_NoMutation", Test_Mod_NoMutation() ) .AND. lOk
   lOk := __RunTest( "Test_Mod_Fuzz_SmallIntOracle", Test_Mod_Fuzz_SmallIntOracle() ) .AND. lOk
   lOk := __RunTest( "Test_Mod_Fuzz_SmallDecimalOracle", Test_Mod_Fuzz_SmallDecimalOracle() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_Simple", Test_PowInt_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_ZeroExponent", Test_PowInt_ZeroExponent() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_NegativeBase", Test_PowInt_NegativeBase() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_EvenNegativeBase", Test_PowInt_EvenNegativeBase() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_DecimalBase", Test_PowInt_DecimalBase() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_ZeroBasePositiveExponent", Test_PowInt_ZeroBasePositiveExponent() ) .AND. lOk
   lOk := __RunTest( "Test_PowInt_NoMutation", Test_PowInt_NoMutation() ) .AND. lOk
   __SpinnerStop()

   ? "== NUMBER THEORY TESTS =="
   __LogLine( "GROUP", "== NUMBER THEORY TESTS ==", HB_LOG_INFO )
   __SpinnerStart( "NUMBER THEORY TESTS" )
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
   lOk := __RunTest( "Test_Factorial_Zero", Test_Factorial_Zero() ) .AND. lOk
   lOk := __RunTest( "Test_Factorial_100", Test_Factorial_100() ) .AND. lOk
   lOk := __RunTest( "Test_Factorial_NoMutation", Test_Factorial_NoMutation() ) .AND. lOk
   lOk := __RunTest( "Test_Factorial_Negative_Error", Test_Factorial_Negative_Error() ) .AND. lOk
   lOk := __RunTest( "Test_Fi_Simple", Test_Fi_Simple() ) .AND. lOk
   lOk := __RunTest( "Test_Fi_Prime", Test_Fi_Prime() ) .AND. lOk
   lOk := __RunTest( "Test_Fi_NoMutation", Test_Fi_NoMutation() ) .AND. lOk
   lOk := __RunTest( "Test_Fi_Negative_Error", Test_Fi_Negative_Error() ) .AND. lOk
   lOk := __RunTest( "Test_MillerRabin_Prime_Mersenne127", Test_MillerRabin_Prime_Mersenne127() ) .AND. lOk
   lOk := __RunTest( "Test_MillerRabin_Composite_2047", Test_MillerRabin_Composite_2047() ) .AND. lOk
   lOk := __RunTest( "Test_Randomize_DefaultRange", Test_Randomize_DefaultRange() ) .AND. lOk
   lOk := __RunTest( "Test_Randomize_CustomLargeRange", Test_Randomize_CustomLargeRange() ) .AND. lOk
   lOk := __RunTest( "Test_Fibonacci_Threshold10", Test_Fibonacci_Threshold10() ) .AND. lOk
   lOk := __RunTest( "Test_Fibonacci_Threshold1000000", Test_Fibonacci_Threshold1000000() ) .AND. lOk
   __SpinnerStop()

   ? "== tBigNtst COMPAT TESTS =="
   __LogLine( "GROUP", "== tBigNtst COMPAT TESTS ==", HB_LOG_INFO )
   __SpinnerStart( "tBigNtst COMPAT TESTS" )
   lOk := __RunTest( "Test_TBigNtst19_Factorial_100", Test_TBigNtst19_Factorial_100() ) .AND. lOk
   lOk := __RunTest( "Test_TBigNtst24_Fi_97", Test_TBigNtst24_Fi_97() ) .AND. lOk
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
   lOk := __RunTest( "Test_TBigNtst34_MillerRabin_Mersenne127", Test_TBigNtst34_MillerRabin_Mersenne127() ) .AND. lOk
   lOk := __RunTest( "Test_TBigNtst35_Randomize_LargeBounds", Test_TBigNtst35_Randomize_LargeBounds() ) .AND. lOk
   lOk := __RunTest( "Test_TBigNtst36_Fibonacci_1000", Test_TBigNtst36_Fibonacci_1000() ) .AND. lOk
   lOk := __RunTest( "Test_TBigNtst37_Fibonacci_Mersenne31", Test_TBigNtst37_Fibonacci_Mersenne31() ) .AND. lOk
   lOk := __RunTest( "Test_TBigNtst38_BigMersenne127", Test_TBigNtst38_BigMersenne127() ) .AND. lOk
   lOk := __RunTest( "Test_TBigNtst39_BigGoogol", Test_TBigNtst39_BigGoogol() ) .AND. lOk
   __SpinnerStop()

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


FUNCTION Test_Format_Scientific_Exact()
   LOCAL aActual := {}
   LOCAL cExpected := "1.2345E+4,1.23E-3,-9.8765E+2,1E+3,8.4E+0,0E+0"
   LOCAL cActual

   AAdd( aActual, HBNum():New( "12345" ):ToScientific() )
   AAdd( aActual, HBNum():New( "0.00123" ):ToScientific() )
   AAdd( aActual, HBNum():New( "-987.65" ):ToScientific() )
   AAdd( aActual, HBNum():New( "1000" ):ToScientific() )
   AAdd( aActual, HBNum():New( "8.40" ):ToScientific() )
   AAdd( aActual, HBNum():New( "0" ):ToScientific() )

   cActual := __JoinTextArray( aActual )
   __SetTrace( "ToScientific() exact formatting", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Format_Scientific_SignificantDigits()
   LOCAL aActual := {}
   LOCAL cExpected := "1.23E+4,1.0E+3,1.00E-2,0.00E+0"
   LOCAL cActual

   AAdd( aActual, HBNum():New( "12345" ):ToScientific( 3 ) )
   AAdd( aActual, HBNum():New( "999" ):ToScientific( 2 ) )
   AAdd( aActual, HBNum():New( "0.009995" ):ToScientific( 3 ) )
   AAdd( aActual, HBNum():New( "0" ):ToScientific( 3 ) )

   cActual := __JoinTextArray( aActual )
   __SetTrace( "ToScientific(n) significant digits", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Format_Engineering_Exact()
   LOCAL aActual := {}
   LOCAL cExpected := "12.345E+3,1.23E-3,120E-3,1.234567E+6,999E+0"
   LOCAL cActual

   AAdd( aActual, HBNum():New( "12345" ):ToEngineering() )
   AAdd( aActual, HBNum():New( "0.00123" ):ToEngineering() )
   AAdd( aActual, HBNum():New( "0.12" ):ToEngineering() )
   AAdd( aActual, HBNum():New( "1234567" ):ToEngineering() )
   AAdd( aActual, HBNum():New( "999" ):ToEngineering() )

   cActual := __JoinTextArray( aActual )
   __SetTrace( "ToEngineering() exact formatting", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Format_Engineering_SignificantDigits()
   LOCAL aActual := {}
   LOCAL cExpected := "12.35E+3,1.0E+3,10.0E-3,0.0E+0"
   LOCAL cActual

   AAdd( aActual, HBNum():New( "12345" ):ToEngineering( 4 ) )
   AAdd( aActual, HBNum():New( "999" ):ToEngineering( 2 ) )
   AAdd( aActual, HBNum():New( "0.009995" ):ToEngineering( 3 ) )
   AAdd( aActual, HBNum():New( "0" ):ToEngineering( 2 ) )

   cActual := __JoinTextArray( aActual )
   __SetTrace( "ToEngineering(n) significant digits", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Format_NoMutation()
   LOCAL oValue := HBNum():New( "12345.600" )
   LOCAL cBefore := oValue:ToString()
   LOCAL cScientific := oValue:ToScientific( 4 )
   LOCAL cEngineering := oValue:ToEngineering( 4 )
   LOCAL cAfter := oValue:ToString()
   LOCAL lResult := cBefore == cAfter .AND. cScientific == "1.235E+4" .AND. cEngineering == "12.35E+3"
   LOCAL cActual := "before=" + cBefore + ", after=" + cAfter + ", scientific=" + cScientific + ", engineering=" + cEngineering

   __SetTrace( "formatting does not mutate source number", "before=after, scientific=1.235E+4, engineering=12.35E+3", cActual )
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


FUNCTION Test_Mod_Fuzz_SmallIntOracle()
   LOCAL nSeed := 20260421
   LOCAL nLoops := 400
   LOCAL nI
   LOCAL nA
   LOCAL nB
   LOCAL nQ
   LOCAL nR
   LOCAL oA
   LOCAL oB
   LOCAL oR
   LOCAL cAStable
   LOCAL cBStable

   __ModSeedRand( nSeed )

   FOR nI := 1 TO nLoops
      nA := __ModRandInt( -1000000, 1000000 )
      nB := __ModRandInt( -1000000, 1000000 )
      IF nB == 0
         nB := 1
      ENDIF

      oA := HBNum():New( __ModIntExpectedText( nA ) )
      oB := HBNum():New( __ModIntExpectedText( nB ) )
      cAStable := oA:ToString()
      cBStable := oB:ToString()
      oR := oA:Mod( oB )

      IF ! __ModValidateNumber( oR, "fuzz int mod #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF

      nQ := __ModTruncDiv( nA, nB )
      nR := nA - ( nQ * nB )

      IF oR:ToString() != __ModIntExpectedText( nR )
         __SetTrace( ;
            "fuzz int mod #" + hb_ntos( nI ) + " seed=" + hb_ntos( nSeed ) + ;
               " for " + cAStable + " % " + cBStable, ;
            __ModIntExpectedText( nR ), ;
            oR:ToString() )
         RETURN .F.
      ENDIF

      IF oA:ToString() != cAStable .OR. oB:ToString() != cBStable
         __SetTrace( ;
            "fuzz int mod #" + hb_ntos( nI ) + " mutation", ;
            "A=" + cAStable + ", B=" + cBStable, ;
            "A=" + oA:ToString() + ", B=" + oB:ToString() )
         RETURN .F.
      ENDIF
   NEXT

   __SetTrace( ;
      "fuzz int mod seed=" + hb_ntos( nSeed ), ;
      "all " + hb_ntos( nLoops ) + " oracle cases matched", ;
      "all " + hb_ntos( nLoops ) + " oracle cases matched" )
RETURN .T.


FUNCTION Test_Mod_Fuzz_SmallDecimalOracle()
   LOCAL nSeed := 20260422
   LOCAL nLoops := 400
   LOCAL nI
   LOCAL aA
   LOCAL aB
   LOCAL aExpected
   LOCAL oA
   LOCAL oB
   LOCAL oR
   LOCAL cAStable
   LOCAL cBStable

   __ModSeedRand( nSeed )

   FOR nI := 1 TO nLoops
      aA := __ModRandomDecimalSpec( 100000, 4 )
      aB := __ModRandomDecimalSpec( 100000, 4 )
      IF aB[ MOD_D_SCALED ] == 0
         aB := __ModMakeDecimalSpec( 1, 0 )
      ENDIF

      oA := HBNum():New( aA[ MOD_D_TEXT ] )
      oB := HBNum():New( aB[ MOD_D_TEXT ] )
      cAStable := oA:ToString()
      cBStable := oB:ToString()
      oR := oA:Mod( oB )

      IF ! __ModValidateNumber( oR, "fuzz decimal mod #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF

      aExpected := __ModDecimalExpected( aA, aB )
      IF oR:ToString() != aExpected[ MOD_D_TEXT ]
         __SetTrace( ;
            "fuzz decimal mod #" + hb_ntos( nI ) + " seed=" + hb_ntos( nSeed ) + ;
               " for " + cAStable + " % " + cBStable, ;
            aExpected[ MOD_D_TEXT ], ;
            oR:ToString() )
         RETURN .F.
      ENDIF

      IF oA:ToString() != cAStable .OR. oB:ToString() != cBStable
         __SetTrace( ;
            "fuzz decimal mod #" + hb_ntos( nI ) + " mutation", ;
            "A=" + cAStable + ", B=" + cBStable, ;
            "A=" + oA:ToString() + ", B=" + oB:ToString() )
         RETURN .F.
      ENDIF
   NEXT

   __SetTrace( ;
      "fuzz decimal mod seed=" + hb_ntos( nSeed ), ;
      "all " + hb_ntos( nLoops ) + " oracle cases matched", ;
      "all " + hb_ntos( nLoops ) + " oracle cases matched" )
RETURN .T.


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


FUNCTION Test_Factorial_Zero()
   LOCAL oValue := HBNum():New( "0" )
   LOCAL cActual := oValue:Factorial():ToString()

   __SetTrace( "0!", "1", cActual )
RETURN cActual == "1"


FUNCTION Test_Factorial_100()
   LOCAL oValue := HBNum():New( "100" )
   LOCAL cExpected := "93326215443944152681699238856266700490715968264381621468592963895217599993229915608941463976156518286253697920827223758251185210916864000000000000000000000000"
   LOCAL cActual := oValue:Factorial():ToString()

   __SetTrace( "100!", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Factorial_NoMutation()
   LOCAL oValue := HBNum():New( "25" )
   LOCAL cBefore := oValue:ToString()
   LOCAL cExpected := "15511210043330985984000000"
   LOCAL oResult := oValue:Factorial()
   LOCAL lOk := oValue:ToString() == cBefore .AND. oResult:ToString() == cExpected
   LOCAL cActual := "input=" + oValue:ToString() + ", result=" + oResult:ToString()

   __SetTrace( "imutabilidade de entrada em 25!", "input=25, result=" + cExpected, cActual )
RETURN lOk


FUNCTION Test_Factorial_Negative_Error()
RETURN __ExpectErrorContains( ;
   {|| HBNum():New( "-5" ):Factorial() }, ;
   "Factorial requires non-negative operand", ;
   "(-5)!" )


FUNCTION Test_Fi_Simple()
   LOCAL oValue := HBNum():New( "36" )
   LOCAL cActual := oValue:Fi():ToString()

   __SetTrace( "phi(36)", "12", cActual )
RETURN cActual == "12"


FUNCTION Test_Fi_Prime()
   LOCAL oValue := HBNum():New( "97" )
   LOCAL cActual := oValue:Fi():ToString()

   __SetTrace( "phi(97)", "96", cActual )
RETURN cActual == "96"


FUNCTION Test_Fi_NoMutation()
   LOCAL oValue := HBNum():New( "84" )
   LOCAL cBefore := oValue:ToString()
   LOCAL oResult := oValue:Fi()
   LOCAL lOk := oValue:ToString() == cBefore .AND. oResult:ToString() == "24"
   LOCAL cActual := "input=" + oValue:ToString() + ", result=" + oResult:ToString()

   __SetTrace( "imutabilidade de entrada em phi(84)", "input=84, result=24", cActual )
RETURN lOk


FUNCTION Test_Fi_Negative_Error()
RETURN __ExpectErrorContains( ;
   {|| HBNum():New( "-84" ):Fi() }, ;
   "Fi requires non-negative operand", ;
   "phi(-84)" )


FUNCTION Test_MillerRabin_Prime_Mersenne127()
   LOCAL oValue := HBNum():New( "2" ):PowInt( 127 ):Sub( "1" )
   LOCAL lActual := oValue:MillerRabin( 5 )
   LOCAL cActual := IIf( lActual, ".T.", ".F." )

   __SetTrace( "MillerRabin(2^127 - 1, 5)", ".T.", cActual )
RETURN lActual


FUNCTION Test_MillerRabin_Composite_2047()
   LOCAL oValue := HBNum():New( "2047" )
   LOCAL lActual := oValue:MillerRabin( 2 )
   LOCAL cActual := IIf( lActual, ".T.", ".F." )

   __SetTrace( "MillerRabin(2047, 2)", ".F.", cActual )
RETURN ! lActual


FUNCTION Test_Randomize_DefaultRange()
   LOCAL oMin := HBNum():New( "1" )
   LOCAL oMax := HBNum():New( "99999999999999999999999999999999" )
   LOCAL oValue := HBNum():New():Randomize()
   LOCAL cActual := oValue:ToString()
   LOCAL lOk := At( ".", cActual ) == 0 .AND. oValue:Gte( oMin ) .AND. oValue:Lte( oMax )

   __SetTrace( "Randomize() default range", "integer in [1, 99999999999999999999999999999999]", cActual )
RETURN lOk


FUNCTION Test_Randomize_CustomLargeRange()
   LOCAL cMin := "100000000000000000000000000000000000000000000000000"
   LOCAL cMax := "999999999999999999999999999999999999999999999999999999999999"
   LOCAL oMin := HBNum():New( cMin )
   LOCAL oMax := HBNum():New( cMax )
   LOCAL nTry
   LOCAL oValue
   LOCAL cActual := ""
   LOCAL lOk := .T.

   FOR nTry := 1 TO 3
      oValue := HBNum():New():Randomize( oMin, oMax )
      cActual += IIf( Empty( cActual ), "", "," ) + oValue:ToString()
      lOk := lOk .AND. At( ".", oValue:ToString() ) == 0 .AND. oValue:Gte( oMin ) .AND. oValue:Lte( oMax )
   NEXT

   __SetTrace( "Randomize([10^50, 10^60-1]) x3", "all integer values inside range", cActual )
RETURN lOk


FUNCTION Test_Fibonacci_Threshold10()
   LOCAL cExpected := "0,1,1,2,3,5,8"
   LOCAL cActual := __JoinTextArray( HBNum():New( "10" ):Fibonacci() )

   __SetTrace( "Fibonacci(<10)", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_Fibonacci_Threshold1000000()
   LOCAL aFib := HBNum():New( "1000000" ):Fibonacci()
   LOCAL lOk := Len( aFib ) == 31 .AND. aFib[ Len( aFib ) ] == "832040"
   LOCAL cActual := "len=" + hb_ntos( Len( aFib ) ) + ", last=" + aFib[ Len( aFib ) ]

   __SetTrace( "Fibonacci(<1000000)", "len=31, last=832040", cActual )
RETURN lOk


FUNCTION Test_TBigNtst19_Factorial_100()
   LOCAL cExpected := "93326215443944152681699238856266700490715968264381621468592963895217599993229915608941463976156518286253697920827223758251185210916864000000000000000000000000"
   LOCAL cActual := HBNum():New( "100" ):Factorial():ToString()

   __SetTrace( "tBigNtst19 port: 100!", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_TBigNtst24_Fi_97()
   LOCAL cActual := HBNum():New( "97" ):Fi():ToString()

   __SetTrace( "tBigNtst24 port: phi(97)", "96", cActual )
RETURN cActual == "96"


FUNCTION Test_TBigNtst34_MillerRabin_Mersenne127()
   LOCAL lActual := HBNum():New( "2" ):PowInt( 127 ):Sub( "1" ):MillerRabin( 5 )
   LOCAL cActual := IIf( lActual, ".T.", ".F." )

   __SetTrace( "tBigNtst34 port: MillerRabin(2^127 - 1, 5)", ".T.", cActual )
RETURN lActual


FUNCTION Test_TBigNtst35_Randomize_LargeBounds()
   LOCAL oMin := HBNum():New( "1" )
   LOCAL oMax := HBNum():New( "9999999999999999999999999999999999999999" )
   LOCAL oValue := HBNum():New():Randomize( oMin, oMax )
   LOCAL cActual := oValue:ToString()
   LOCAL lOk := At( ".", cActual ) == 0 .AND. oValue:Gte( oMin ) .AND. oValue:Lte( oMax )

   __SetTrace( "tBigNtst35 port: Randomize(1, 10^40-1)", "integer in [1, 9999999999999999999999999999999999999999]", cActual )
RETURN lOk


FUNCTION Test_TBigNtst36_Fibonacci_1000()
   LOCAL cExpected := "0,1,1,2,3,5,8,13,21,34,55,89,144,233,377,610,987"
   LOCAL cActual := __JoinTextArray( HBNum():New( "1000" ):Fibonacci() )

   __SetTrace( "tBigNtst36 port: Fibonacci(<1000)", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_TBigNtst37_Fibonacci_Mersenne31()
   LOCAL cExpected := "0,1,1,2,3,5,8,13,21"
   LOCAL cActual := __JoinTextArray( HBNum():New( "31" ):Fibonacci() )

   __SetTrace( "tBigNtst37 port: Fibonacci(<31)", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_TBigNtst38_BigMersenne127()
   LOCAL cExpected := "170141183460469231731687303715884105727"
   LOCAL cActual := HBNum():New( "2" ):PowInt( 127 ):Sub( "1" ):ToString()

   __SetTrace( "tBigNtst38 port: 2^127 - 1", cExpected, cActual )
RETURN cActual == cExpected


FUNCTION Test_TBigNtst39_BigGoogol()
   LOCAL cExpected := "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
   LOCAL cActual := HBNum():New( "10" ):PowInt( 100 ):ToString()

   __SetTrace( "tBigNtst39 representative port: 10^100", cExpected, cActual )
RETURN cActual == cExpected
