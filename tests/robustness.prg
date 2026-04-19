/*
hbnum: Released to Public Domain.
*/
#include "hbnum.ch"
#include "hblog.ch"

#define D_TEXT    1
#define D_SCALED  2
#define D_SCALE   3

STATIC __cLogFileName := ""
STATIC __cLastFailure := ""
STATIC __nRandState := 1

STATIC PROCEDURE __InitRobustLog()
   LOCAL nStyle := HB_LOG_ST_DATE + HB_LOG_ST_ISODATE + HB_LOG_ST_TIME + HB_LOG_ST_LEVEL
   LOCAL nSeverity := HB_LOG_DEBUG
   LOCAL nFileSize := 2 * 1024 * 1024
   LOCAL nFileCount := 5

   __cLogFileName := HBNumTestArtifactPath( "hbnum_robust.log" )
   INIT LOG ON FILE ( nSeverity, __cLogFileName, nFileSize, nFileCount )
   SET LOG STYLE ( nStyle )
   __LogLine( "ROBUST", "Robustness log started. File: " + __cLogFileName, HB_LOG_INFO )
RETURN

STATIC PROCEDURE __CloseRobustLog()
   __LogLine( "ROBUST", "Robustness log finished.", HB_LOG_INFO )
   CLOSE LOG
RETURN

STATIC PROCEDURE __LogLine( cKey, cMessage, nSeverity )
   hb_default( @nSeverity, HB_LOG_DEBUG )
   LOG cKey + ": " + cMessage PRIORITY nSeverity
RETURN

STATIC FUNCTION __NowMs()
RETURN Int( Seconds() * 1000 )

STATIC PROCEDURE __ClearFailure()
   __cLastFailure := ""
RETURN

STATIC PROCEDURE __SetFailure( cFailure )
   __cLastFailure := cFailure
RETURN

STATIC FUNCTION __ReadEnvInt( cName, nDefault )
   LOCAL cValue := AllTrim( GetEnv( cName ) )
   LOCAL nValue

   IF Empty( cValue )
      RETURN nDefault
   ENDIF

   nValue := Int( Val( cValue ) )
   IF nValue < 0
      RETURN nDefault
   ENDIF

RETURN nValue

STATIC PROCEDURE __SeedRand( nSeed )
   nSeed := Int( nSeed )

   IF nSeed <= 0
      nSeed := 1
   ENDIF

   __nRandState := Mod( nSeed, 2147483647 )
   IF __nRandState <= 0
      __nRandState += 2147483646
   ENDIF
RETURN

STATIC FUNCTION __NextRand()
   __nRandState := Mod( __nRandState * 48271, 2147483647 )

   IF __nRandState <= 0
      __nRandState += 2147483646
   ENDIF

RETURN __nRandState

STATIC FUNCTION __RandInt( nMin, nMax )
   LOCAL nRange

   IF nMax <= nMin
      RETURN nMin
   ENDIF

   nRange := ( nMax - nMin ) + 1
RETURN nMin + Mod( __NextRand(), nRange )

STATIC FUNCTION __Canonical( cValue )
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

STATIC FUNCTION __Pow10( nExp )
   LOCAL nValue := 1
   LOCAL nPos

   FOR nPos := 1 TO nExp
      nValue *= 10
   NEXT

RETURN nValue

STATIC FUNCTION __ScaledToText( nScaled, nScale )
   LOCAL lNeg := nScaled < 0
   LOCAL cDigits := __Canonical( hb_ntos( Abs( nScaled ) ) )
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

RETURN __Canonical( cText )

STATIC FUNCTION __IntExpectedText( nValue )
RETURN __Canonical( hb_ntos( nValue ) )

STATIC FUNCTION __MakeDecimalSpec( nScaled, nScale )
RETURN { __ScaledToText( nScaled, nScale ), nScaled, nScale }

STATIC FUNCTION __NoisyTextFromSpec( aSpec, lAllowDecimalPadding )
   LOCAL cText := aSpec[ D_TEXT ]
   LOCAL lNeg := Left( cText, 1 ) == "-"
   LOCAL cBody := IIf( lNeg, SubStr( cText, 2 ), cText )
   LOCAL nDot := At( ".", cBody )
   LOCAL cInt
   LOCAL cDec
   LOCAL cOut

   hb_default( @lAllowDecimalPadding, .T. )

   IF nDot > 0
      cInt := Left( cBody, nDot - 1 )
      cDec := SubStr( cBody, nDot + 1 )
   ELSE
      cInt := cBody
      cDec := ""
   ENDIF

   cInt := Replicate( "0", __RandInt( 0, 3 ) ) + cInt

   IF ! Empty( cDec )
      cDec += Replicate( "0", __RandInt( 0, 3 ) )
   ELSEIF lAllowDecimalPadding
      IF __RandInt( 0, 1 ) == 1
         cDec := Replicate( "0", __RandInt( 1, 3 ) )
      ENDIF
   ENDIF

   cOut := cInt
   IF ! Empty( cDec )
      cOut += "." + cDec
   ENDIF

   IF lNeg .AND. aSpec[ D_SCALED ] != 0
      cOut := "-" + cOut
   ELSEIF __RandInt( 0, 5 ) == 0
      cOut := "+" + cOut
   ENDIF

   cOut := Replicate( " ", __RandInt( 0, 2 ) ) + cOut + Replicate( " ", __RandInt( 0, 2 ) )
RETURN cOut

STATIC FUNCTION __RandomDecimalSpec( nMaxAbsScaled, nMaxScale )
   LOCAL nScale := __RandInt( 0, nMaxScale )
   LOCAL nScaled := __RandInt( -nMaxAbsScaled, nMaxAbsScaled )

RETURN __MakeDecimalSpec( nScaled, nScale )

STATIC FUNCTION __RandomLargeDigits( nDigits )
   LOCAL cDigits := ""
   LOCAL nPos
   LOCAL nDigit

   FOR nPos := 1 TO nDigits
      nDigit := __RandInt( 0, 9 )
      IF nPos == 1 .AND. nDigit == 0
         nDigit := __RandInt( 1, 9 )
      ENDIF
      cDigits += Chr( Asc( "0" ) + nDigit )
   NEXT

RETURN cDigits

STATIC FUNCTION __RandomLargeIntegerText( nMinDigits, nMaxDigits, lAllowZero, lAllowNegative )
   LOCAL cDigits := __RandomLargeDigits( __RandInt( nMinDigits, nMaxDigits ) )
   LOCAL cText := cDigits

   IF lAllowZero .AND. __RandInt( 1, 10 ) == 1
      cText := "0"
   ENDIF

   IF lAllowNegative .AND. cText != "0" .AND. __RandInt( 0, 1 ) == 1
      cText := "-" + cText
   ENDIF

RETURN cText

STATIC FUNCTION __RandomLargeDecimalText( nMinDigits, nMaxDigits, nMaxScale )
   LOCAL cDigits := __RandomLargeDigits( __RandInt( nMinDigits, nMaxDigits ) )
   LOCAL nScale := __RandInt( 0, nMaxScale )
   LOCAL cText

   IF nScale == 0
      cText := cDigits
   ELSEIF nScale >= Len( cDigits )
      cText := "0." + Replicate( "0", nScale - Len( cDigits ) ) + cDigits
   ELSE
      cText := Left( cDigits, Len( cDigits ) - nScale ) + "." + Right( cDigits, nScale )
   ENDIF

   IF cText != "0" .AND. __RandInt( 0, 1 ) == 1
      cText := "-" + cText
   ENDIF

RETURN cText

STATIC FUNCTION __AlignScaled( aSpec, nTargetScale )
RETURN aSpec[ D_SCALED ] * __Pow10( nTargetScale - aSpec[ D_SCALE ] )

STATIC FUNCTION __CompareScaled( nA, nB )
   IF nA > nB
      RETURN 1
   ENDIF
   IF nA < nB
      RETURN -1
   ENDIF
RETURN 0

STATIC FUNCTION __TruncDiv( nNum, nDen )
   LOCAL nQ

   nQ := Int( Abs( nNum ) / Abs( nDen ) )
   IF ( nNum < 0 .AND. nDen > 0 ) .OR. ( nNum > 0 .AND. nDen < 0 )
      nQ := -nQ
   ENDIF

RETURN nQ

STATIC FUNCTION __GcdInt( nA, nB )
   LOCAL nX := Abs( nA )
   LOCAL nY := Abs( nB )
   LOCAL nT

   IF nX == 0
      RETURN nY
   ENDIF

   IF nY == 0
      RETURN nX
   ENDIF

   DO WHILE nY != 0
      nT := Mod( nX, nY )
      nX := nY
      nY := nT
   ENDDO

RETURN nX

STATIC FUNCTION __LcmInt( nA, nB )
   LOCAL nX := Abs( nA )
   LOCAL nY := Abs( nB )
   LOCAL nG

   IF nX == 0 .OR. nY == 0
      RETURN 0
   ENDIF

   nG := __GcdInt( nX, nY )
RETURN Int( ( nX / nG ) * nY )

STATIC FUNCTION __DecimalAddExpected( aA, aB )
   LOCAL nScale := Max( aA[ D_SCALE ], aB[ D_SCALE ] )
   LOCAL nScaled := __AlignScaled( aA, nScale ) + __AlignScaled( aB, nScale )
RETURN __MakeDecimalSpec( nScaled, nScale )

STATIC FUNCTION __DecimalSubExpected( aA, aB )
   LOCAL nScale := Max( aA[ D_SCALE ], aB[ D_SCALE ] )
   LOCAL nScaled := __AlignScaled( aA, nScale ) - __AlignScaled( aB, nScale )
RETURN __MakeDecimalSpec( nScaled, nScale )

STATIC FUNCTION __DecimalMulExpected( aA, aB )
RETURN __MakeDecimalSpec( aA[ D_SCALED ] * aB[ D_SCALED ], aA[ D_SCALE ] + aB[ D_SCALE ] )

STATIC FUNCTION __DecimalDivExpected( aA, aB, nPrecision )
   LOCAL nNum := aA[ D_SCALED ]
   LOCAL nDen := aB[ D_SCALED ]
   LOCAL nExponent := nPrecision + aB[ D_SCALE ] - aA[ D_SCALE ]

   IF nExponent > 0
      nNum *= __Pow10( nExponent )
   ELSEIF nExponent < 0
      nDen *= __Pow10( -nExponent )
   ENDIF

RETURN __MakeDecimalSpec( __TruncDiv( nNum, nDen ), nPrecision )

STATIC FUNCTION __DecimalModExpected( aA, aB )
   LOCAL nScale := Max( aA[ D_SCALE ], aB[ D_SCALE ] )
   LOCAL nA := __AlignScaled( aA, nScale )
   LOCAL nB := __AlignScaled( aB, nScale )
   LOCAL nQ := __TruncDiv( nA, nB )
   LOCAL nR := nA - ( nQ * nB )
RETURN __MakeDecimalSpec( nR, nScale )

STATIC FUNCTION __ExpectedCompare( aA, aB )
   LOCAL nScale := Max( aA[ D_SCALE ], aB[ D_SCALE ] )
RETURN __CompareScaled( __AlignScaled( aA, nScale ), __AlignScaled( aB, nScale ) )

STATIC FUNCTION __ValidateNumber( oNum, cContext )
   LOCAL hNum
   LOCAL nSign
   LOCAL nScale
   LOCAL nUsed
   LOCAL aLimbs
   LOCAL nPos
   LOCAL nLimb

   IF ValType( oNum ) != "O"
      __SetFailure( cContext + " => result is not an object" )
      RETURN .F.
   ENDIF

   hNum := oNum:hbNum
   IF ValType( hNum ) != "H"
      __SetFailure( cContext + " => hbNum is not a hash" )
      RETURN .F.
   ENDIF

   nSign := hNum[ HBNUM_SIGN ]
   nScale := hNum[ HBNUM_SCALE ]
   nUsed := hNum[ HBNUM_USED ]
   aLimbs := hNum[ HBNUM_LIMBS ]

   IF ! HB_ISNUMERIC( nSign ) .OR. !( nSign == -1 .OR. nSign == 0 .OR. nSign == 1 )
      __SetFailure( cContext + " => invalid sign: " + hb_ValToExp( nSign ) )
      RETURN .F.
   ENDIF

   IF ! HB_ISNUMERIC( nScale ) .OR. nScale < 0
      __SetFailure( cContext + " => invalid scale: " + hb_ValToExp( nScale ) )
      RETURN .F.
   ENDIF

   IF ! HB_ISNUMERIC( nUsed ) .OR. nUsed < 0
      __SetFailure( cContext + " => invalid used: " + hb_ValToExp( nUsed ) )
      RETURN .F.
   ENDIF

   IF ValType( aLimbs ) != "A"
      __SetFailure( cContext + " => limbs is not an array" )
      RETURN .F.
   ENDIF

   IF Len( aLimbs ) != nUsed
      __SetFailure( cContext + " => nUsed/Len mismatch: " + hb_ntos( nUsed ) + "/" + hb_ntos( Len( aLimbs ) ) )
      RETURN .F.
   ENDIF

   FOR nPos := 1 TO Len( aLimbs )
      nLimb := aLimbs[ nPos ]
      IF ! HB_ISNUMERIC( nLimb ) .OR. Int( nLimb ) != nLimb .OR. nLimb < 0 .OR. nLimb >= HBNUM_BASE
         __SetFailure( cContext + " => limb out of range at " + hb_ntos( nPos ) + ": " + hb_ValToExp( nLimb ) )
         RETURN .F.
      ENDIF
   NEXT

   IF nUsed == 0
      IF nSign != 0
         __SetFailure( cContext + " => zero object with non-zero sign" )
         RETURN .F.
      ENDIF
      IF nScale != 0
         __SetFailure( cContext + " => zero object with non-zero scale" )
         RETURN .F.
      ENDIF
   ELSE
      IF nSign == 0
         __SetFailure( cContext + " => non-zero object with zero sign" )
         RETURN .F.
      ENDIF
      IF aLimbs[ Len( aLimbs ) ] == 0
         __SetFailure( cContext + " => leading zero limb found" )
         RETURN .F.
      ENDIF
   ENDIF

RETURN .T.

STATIC FUNCTION __RunSuite( cName, nLoops, bAction )
   LOCAL lOk
   LOCAL nStart := __NowMs()
   LOCAL nElapsed
   LOCAL cDetail

   __ClearFailure()
   ? "[RUN ]", cName
   __LogLine( cName, "starting, loops=" + hb_ntos( nLoops ), HB_LOG_INFO )

   BEGIN SEQUENCE
      lOk := Eval( bAction )
   RECOVER
      IF Empty( __cLastFailure )
         __SetFailure( "Unhandled exception while running suite." )
      ENDIF
      lOk := .F.
   END SEQUENCE

   nElapsed := __NowMs() - nStart
   cDetail := IIf( Empty( __cLastFailure ), "invariants preserved", __cLastFailure )

   ? IIf( lOk, "[PASS]", "[FAIL]" ), cName
   ? "  loops     :", hb_ntos( nLoops )
   ? "  elapsed_ms:", hb_ntos( nElapsed )
   ? "  detail    :", cDetail

   __LogLine( cName, ;
      "result=" + IIf( lOk, "PASS", "FAIL" ) + ;
      ", loops=" + hb_ntos( nLoops ) + ;
      ", elapsed_ms=" + hb_ntos( nElapsed ) + ;
      ", detail=[" + cDetail + "]", ;
      IIf( lOk, HB_LOG_INFO, HB_LOG_ERROR ) )

RETURN lOk

STATIC FUNCTION __RunSuiteIfEnabled( cName, nLoops, bAction )
   IF nLoops <= 0
      ? "[SKIP]", cName
      ? "  loops     :", hb_ntos( nLoops )
      ? "  detail    :", "disabled by environment"
      __LogLine( cName, "skipped, loops=0", HB_LOG_INFO )
      RETURN .T.
   ENDIF

RETURN __RunSuite( cName, nLoops, bAction )

STATIC FUNCTION __PropertySmallIntOracle( nLoops )
   LOCAL nI
   LOCAL nA
   LOCAL nB
   LOCAL cAText
   LOCAL cBText
   LOCAL oA
   LOCAL oB
   LOCAL cAStable
   LOCAL cBStable
   LOCAL oR
   LOCAL nCmpExpected
   LOCAL nQ
   LOCAL nR
   LOCAL nG
   LOCAL nL

   FOR nI := 1 TO nLoops
      nA := __RandInt( -1000000, 1000000 )
      nB := __RandInt( -1000000, 1000000 )
      IF nB == 0
         nB := 1
      ENDIF

      cAText := __NoisyTextFromSpec( __MakeDecimalSpec( nA, 0 ), .F. )
      cBText := __NoisyTextFromSpec( __MakeDecimalSpec( nB, 0 ), .F. )

      oA := HBNum():New( cAText )
      oB := HBNum():New( cBText )
      cAStable := oA:ToString()
      cBStable := oB:ToString()

      IF ! __ValidateNumber( oA, "SmallIntOracle A #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF ! __ValidateNumber( oB, "SmallIntOracle B #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF

      oR := oA:Add( oB )
      IF ! __ValidateNumber( oR, "SmallIntOracle Add #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF oR:ToString() != __IntExpectedText( nA + nB )
         __SetFailure( "SmallIntOracle Add mismatch #" + hb_ntos( nI ) + ;
            " => " + cAStable + " + " + cBStable + ;
            " expected " + __IntExpectedText( nA + nB ) + ;
            " got " + oR:ToString() )
         RETURN .F.
      ENDIF

      oR := oA:Sub( oB )
      IF ! __ValidateNumber( oR, "SmallIntOracle Sub #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF oR:ToString() != __IntExpectedText( nA - nB )
         __SetFailure( "SmallIntOracle Sub mismatch #" + hb_ntos( nI ) + ;
            " => expected " + __IntExpectedText( nA - nB ) + ;
            " got " + oR:ToString() )
         RETURN .F.
      ENDIF

      oR := oA:Mul( oB )
      IF ! __ValidateNumber( oR, "SmallIntOracle Mul #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF oR:ToString() != __IntExpectedText( nA * nB )
         __SetFailure( "SmallIntOracle Mul mismatch #" + hb_ntos( nI ) + ;
            " => expected " + __IntExpectedText( nA * nB ) + ;
            " got " + oR:ToString() )
         RETURN .F.
      ENDIF

      nCmpExpected := __CompareScaled( nA, nB )
      IF oA:Compare( oB ) != nCmpExpected
         __SetFailure( "SmallIntOracle Compare mismatch #" + hb_ntos( nI ) + ;
            " => expected " + hb_ntos( nCmpExpected ) + ;
            " got " + hb_ntos( oA:Compare( oB ) ) )
         RETURN .F.
      ENDIF

      oR := oA:Div( oB, 0 )
      IF ! __ValidateNumber( oR, "SmallIntOracle Div #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      nQ := __TruncDiv( nA, nB )
      IF oR:ToString() != __IntExpectedText( nQ )
         __SetFailure( "SmallIntOracle Div mismatch #" + hb_ntos( nI ) + ;
            " => expected " + __IntExpectedText( nQ ) + ;
            " got " + oR:ToString() )
         RETURN .F.
      ENDIF

      oR := oA:Mod( oB )
      IF ! __ValidateNumber( oR, "SmallIntOracle Mod #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      nR := nA - ( nQ * nB )
      IF oR:ToString() != __IntExpectedText( nR )
         __SetFailure( "SmallIntOracle Mod mismatch #" + hb_ntos( nI ) + ;
            " => expected " + __IntExpectedText( nR ) + ;
            " got " + oR:ToString() )
         RETURN .F.
      ENDIF

      oR := oA:Gcd( oB )
      IF ! __ValidateNumber( oR, "SmallIntOracle GCD #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      nG := __GcdInt( nA, nB )
      IF oR:ToString() != __IntExpectedText( nG )
         __SetFailure( "SmallIntOracle GCD mismatch #" + hb_ntos( nI ) + ;
            " => expected " + __IntExpectedText( nG ) + ;
            " got " + oR:ToString() )
         RETURN .F.
      ENDIF

      oR := oA:Lcm( oB )
      IF ! __ValidateNumber( oR, "SmallIntOracle LCM #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      nL := __LcmInt( nA, nB )
      IF oR:ToString() != __IntExpectedText( nL )
         __SetFailure( "SmallIntOracle LCM mismatch #" + hb_ntos( nI ) + ;
            " => expected " + __IntExpectedText( nL ) + ;
            " got " + oR:ToString() )
         RETURN .F.
      ENDIF

      IF oA:ToString() != cAStable .OR. oB:ToString() != cBStable
         __SetFailure( "SmallIntOracle mutation detected #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
   NEXT

RETURN .T.

STATIC FUNCTION __PropertySmallDecimalOracle( nLoops )
   LOCAL nI
   LOCAL aA
   LOCAL aB
   LOCAL cAText
   LOCAL cBText
   LOCAL oA
   LOCAL oB
   LOCAL cAStable
   LOCAL cBStable
   LOCAL oR
   LOCAL aExpected
   LOCAL nCmpExpected
   LOCAL nPrecision

   FOR nI := 1 TO nLoops
      aA := __RandomDecimalSpec( 100000, 4 )
      aB := __RandomDecimalSpec( 100000, 4 )
      IF aB[ D_SCALED ] == 0
         aB := __MakeDecimalSpec( 1, 0 )
      ENDIF

      cAText := __NoisyTextFromSpec( aA )
      cBText := __NoisyTextFromSpec( aB )

      oA := HBNum():New( cAText )
      oB := HBNum():New( cBText )
      cAStable := oA:ToString()
      cBStable := oB:ToString()

      IF ! __ValidateNumber( oA, "SmallDecimalOracle A #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF ! __ValidateNumber( oB, "SmallDecimalOracle B #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF cAStable != aA[ D_TEXT ] .OR. cBStable != aB[ D_TEXT ]
         __SetFailure( "SmallDecimalOracle round-trip mismatch #" + hb_ntos( nI ) + ;
            " => A " + cAStable + "/" + aA[ D_TEXT ] + ;
            ", B " + cBStable + "/" + aB[ D_TEXT ] )
         RETURN .F.
      ENDIF

      aExpected := __DecimalAddExpected( aA, aB )
      oR := oA:Add( oB )
      IF ! __ValidateNumber( oR, "SmallDecimalOracle Add #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF oR:ToString() != aExpected[ D_TEXT ]
         __SetFailure( "SmallDecimalOracle Add mismatch #" + hb_ntos( nI ) + ;
            " => expected " + aExpected[ D_TEXT ] + ;
            " got " + oR:ToString() )
         RETURN .F.
      ENDIF

      aExpected := __DecimalSubExpected( aA, aB )
      oR := oA:Sub( oB )
      IF ! __ValidateNumber( oR, "SmallDecimalOracle Sub #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF oR:ToString() != aExpected[ D_TEXT ]
         __SetFailure( "SmallDecimalOracle Sub mismatch #" + hb_ntos( nI ) + ;
            " => expected " + aExpected[ D_TEXT ] + ;
            " got " + oR:ToString() )
         RETURN .F.
      ENDIF

      aExpected := __DecimalMulExpected( aA, aB )
      oR := oA:Mul( oB )
      IF ! __ValidateNumber( oR, "SmallDecimalOracle Mul #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF oR:ToString() != aExpected[ D_TEXT ]
         __SetFailure( "SmallDecimalOracle Mul mismatch #" + hb_ntos( nI ) + ;
            " => expected " + aExpected[ D_TEXT ] + ;
            " got " + oR:ToString() )
         RETURN .F.
      ENDIF

      nPrecision := __RandInt( 0, 4 )
      aExpected := __DecimalDivExpected( aA, aB, nPrecision )
      oR := oA:Div( oB, nPrecision )
      IF ! __ValidateNumber( oR, "SmallDecimalOracle Div #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF oR:ToString() != aExpected[ D_TEXT ]
         __SetFailure( "SmallDecimalOracle Div mismatch #" + hb_ntos( nI ) + ;
            " => precision " + hb_ntos( nPrecision ) + ;
            ", expected " + aExpected[ D_TEXT ] + ;
            ", got " + oR:ToString() )
         RETURN .F.
      ENDIF

      aExpected := __DecimalModExpected( aA, aB )
      oR := oA:Mod( oB )
      IF ! __ValidateNumber( oR, "SmallDecimalOracle Mod #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF oR:ToString() != aExpected[ D_TEXT ]
         __SetFailure( "SmallDecimalOracle Mod mismatch #" + hb_ntos( nI ) + ;
            " => expected " + aExpected[ D_TEXT ] + ;
            " got " + oR:ToString() )
         RETURN .F.
      ENDIF

      nCmpExpected := __ExpectedCompare( aA, aB )
      IF oA:Compare( oB ) != nCmpExpected
         __SetFailure( "SmallDecimalOracle Compare mismatch #" + hb_ntos( nI ) + ;
            " => expected " + hb_ntos( nCmpExpected ) + ;
            " got " + hb_ntos( oA:Compare( oB ) ) )
         RETURN .F.
      ENDIF

      IF oA:Add( oB ):Sub( oB ):ToString() != cAStable
         __SetFailure( "SmallDecimalOracle Add/Sub inverse mismatch #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF

      IF oA:ToString() != cAStable .OR. oB:ToString() != cBStable
         __SetFailure( "SmallDecimalOracle mutation detected #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
   NEXT

RETURN .T.

STATIC FUNCTION __StressLargeConstructed( nLoops )
   LOCAL nI
   LOCAL cBase
   LOCAL cMulX
   LOCAL cMulY
   LOCAL oBase
   LOCAL oQ
   LOCAL oR
   LOCAL oA
   LOCAL oB
   LOCAL oDiv
   LOCAL oMod
   LOCAL oG
   LOCAL oL
   LOCAL cAStable
   LOCAL cBStable
   LOCAL nPrecision

   FOR nI := 1 TO nLoops
      cBase := __RandomLargeIntegerText( 40, 90, .F., .F. )
      cMulX := __IntExpectedText( __RandInt( 11, 9999 ) )
      cMulY := IIf( __RandInt( 0, 1 ) == 0, "37", "91" )

      oBase := HBNum():New( cBase )
      oQ := HBNum():New( cMulX )
      oR := HBNum():New( __IntExpectedText( __RandInt( 0, 9 ) ) )
      oA := oBase:Mul( oQ ):Add( oR )
      oB := oBase:Clone()

      cAStable := oA:ToString()
      cBStable := oB:ToString()

      IF ! __ValidateNumber( oA, "LargeConstructed Dividend #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF ! __ValidateNumber( oB, "LargeConstructed Divisor #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF

      oDiv := oA:Div( oB, 0 )
      oMod := oA:Mod( oB )

      IF ! __ValidateNumber( oDiv, "LargeConstructed Div #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF ! __ValidateNumber( oMod, "LargeConstructed Mod #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF oDiv:ToString() != oQ:ToString()
         __SetFailure( "LargeConstructed exact division mismatch #" + hb_ntos( nI ) + ;
            " => expected " + oQ:ToString() + ;
            " got " + oDiv:ToString() )
         RETURN .F.
      ENDIF
      IF oMod:ToString() != oR:ToString()
         __SetFailure( "LargeConstructed exact modulo mismatch #" + hb_ntos( nI ) + ;
            " => expected " + oR:ToString() + ;
            " got " + oMod:ToString() )
         RETURN .F.
      ENDIF
      IF oDiv:Mul( oB ):Add( oMod ):ToString() != cAStable
         __SetFailure( "LargeConstructed recomposition mismatch #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF oB:ToString() != cBStable
         __SetFailure( "LargeConstructed divisor mutation detected #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF

      oA := oBase:Mul( cMulY )
      oB := oBase:Mul( IIf( cMulY == "37", "91", "37" ) )
      oG := oA:Gcd( oB )
      oL := oA:Lcm( oB )

      IF ! __ValidateNumber( oG, "LargeConstructed GCD #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF ! __ValidateNumber( oL, "LargeConstructed LCM #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF oG:ToString() != oBase:ToString()
         __SetFailure( "LargeConstructed GCD mismatch #" + hb_ntos( nI ) + ;
            " => expected " + oBase:ToString() + ;
            " got " + oG:ToString() )
         RETURN .F.
      ENDIF
      IF oG:Mul( oL ):ToString() != oA:Abs():Mul( oB:Abs() ):ToString()
         __SetFailure( "LargeConstructed gcd*lcm identity mismatch #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF

      nPrecision := __RandInt( 4, 18 )
      oA := HBNum():New( __RandomLargeDecimalText( 30, 70, 18 ) )
      oB := HBNum():New( __RandomLargeDecimalText( 15, 35, 10 ) )

      IF oB:IsZero()
         oB := HBNum():New( "1.25" )
      ENDIF

      cAStable := oA:ToString()
      cBStable := oB:ToString()

      IF ! __ValidateNumber( oA:Add( oB ), "LargeConstructed AddDecimal #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF ! __ValidateNumber( oA:Sub( oB ), "LargeConstructed SubDecimal #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF ! __ValidateNumber( oA:Mul( oB ), "LargeConstructed MulDecimal #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF ! __ValidateNumber( oA:Div( oB, nPrecision ), "LargeConstructed DivDecimal #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF

      IF oA:ToString() != cAStable .OR. oB:ToString() != cBStable
         __SetFailure( "LargeConstructed decimal mutation detected #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
   NEXT

RETURN .T.

STATIC FUNCTION __StressLifecycle( nLoops )
   LOCAL nI
   LOCAL oA
   LOCAL oB
   LOCAL oC
   LOCAL oR

   FOR nI := 1 TO nLoops
      oA := HBNum():New( __RandomLargeDecimalText( 10, 30, 8 ) )
      oB := HBNum():New( __RandomLargeDecimalText( 5, 20, 6 ) )
      oC := HBNum():New( __RandomLargeIntegerText( 1, 4, .F., .T. ) )

      IF oB:IsZero()
         oB := HBNum():New( "2.5" )
      ENDIF
      IF oC:IsZero()
         oC := HBNum():New( "3" )
      ENDIF

      oR := oA:Add( oB ):Mul( oC ):Sub( oB ):Div( oC:Abs():Add( 1 ), __RandInt( 2, 10 ) )
      IF ! __ValidateNumber( oR, "Lifecycle chain #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF

      oR := oA:Abs():Add( 1 ):PowInt( __RandInt( 0, 5 ) )
      IF ! __ValidateNumber( oR, "Lifecycle PowInt #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF

      oR := HBNum():New( __RandomLargeIntegerText( 8, 20, .F., .T. ) )
      oA := HBNum():New( __RandomLargeIntegerText( 8, 20, .F., .T. ) )
      oB := HBNum():New( __RandomLargeIntegerText( 8, 20, .F., .T. ) )
      IF oB:IsZero()
         oB := HBNum():New( "5" )
      ENDIF

      IF ! __ValidateNumber( oA:Gcd( oB ), "Lifecycle GCD #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF ! __ValidateNumber( oA:Lcm( oB ), "Lifecycle LCM #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
      IF ! __ValidateNumber( oR:Add( oA ):Sub( oB ), "Lifecycle AddSub #" + hb_ntos( nI ) )
         RETURN .F.
      ENDIF
   NEXT

RETURN .T.

FUNCTION Main()
   LOCAL nSeed := __ReadEnvInt( "HBNUM_ROBUST_SEED", 20260418 )
   LOCAL nIntLoops := __ReadEnvInt( "HBNUM_ROBUST_INT_LOOPS", 250 )
   LOCAL nDecimalLoops := __ReadEnvInt( "HBNUM_ROBUST_DECIMAL_LOOPS", 250 )
   LOCAL nLargeLoops := __ReadEnvInt( "HBNUM_ROBUST_LARGE_LOOPS", 80 )
   LOCAL nLifecycleLoops := __ReadEnvInt( "HBNUM_ROBUST_LIFECYCLE_LOOPS", 1000 )
   LOCAL lOk := .T.

   __SeedRand( nSeed )
   __InitRobustLog()

   ? "HBNum Robustness Suite"
   ? "seed            :", hb_ntos( nSeed )
   ? "int loops       :", hb_ntos( nIntLoops )
   ? "decimal loops   :", hb_ntos( nDecimalLoops )
   ? "large loops     :", hb_ntos( nLargeLoops )
   ? "lifecycle loops :", hb_ntos( nLifecycleLoops )

   __LogLine( "CONFIG", ;
      "seed=" + hb_ntos( nSeed ) + ;
      ", int_loops=" + hb_ntos( nIntLoops ) + ;
      ", decimal_loops=" + hb_ntos( nDecimalLoops ) + ;
      ", large_loops=" + hb_ntos( nLargeLoops ) + ;
      ", lifecycle_loops=" + hb_ntos( nLifecycleLoops ), ;
      HB_LOG_INFO )

   lOk := __RunSuiteIfEnabled( "Property_SmallIntOracle", nIntLoops, {|| __PropertySmallIntOracle( nIntLoops ) } ) .AND. lOk
   lOk := __RunSuiteIfEnabled( "Property_SmallDecimalOracle", nDecimalLoops, {|| __PropertySmallDecimalOracle( nDecimalLoops ) } ) .AND. lOk
   lOk := __RunSuiteIfEnabled( "Stress_LargeConstructed", nLargeLoops, {|| __StressLargeConstructed( nLargeLoops ) } ) .AND. lOk
   lOk := __RunSuiteIfEnabled( "Stress_Lifecycle", nLifecycleLoops, {|| __StressLifecycle( nLifecycleLoops ) } ) .AND. lOk

   IF lOk
      ? "ROBUSTNESS: PASS"
      __LogLine( "RESULT", "ROBUSTNESS: PASS", HB_LOG_INFO )
      __CloseRobustLog()
      RETURN 0
   ENDIF

   ? "ROBUSTNESS: FAIL"
   __LogLine( "RESULT", "ROBUSTNESS: FAIL", HB_LOG_ERROR )
   __CloseRobustLog()
RETURN 1
