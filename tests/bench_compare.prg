#include "hbnum.ch"
#include "hblog.ch"
#include "fileio.ch"

#ifdef HBNUM_BENCH_WITH_TBIG
   #include "tBigNumber.ch"
#endif

#define C_ID        1
#define C_OP        2
#define C_A         3
#define C_B         4
#define C_PREC      5
#define C_EXP       6
#define C_EXPECT    7
#define C_LOOPS     8

STATIC __cLogFileName := "hbnum_bench_compare.log"
STATIC __cCsvFileName := "hbnum_bench_compare.csv"
STATIC __lCsvHeader := .F.

STATIC PROCEDURE __InitBenchLog()
   LOCAL nStyle := HB_LOG_ST_DATE + HB_LOG_ST_ISODATE + HB_LOG_ST_TIME + HB_LOG_ST_LEVEL
   LOCAL nSeverity := HB_LOG_DEBUG
   LOCAL nFileSize := 2 * 1024 * 1024
   LOCAL nFileCount := 5

   INIT LOG ON FILE ( nSeverity, __cLogFileName, nFileSize, nFileCount )
   SET LOG STYLE ( nStyle )
   __LogLine( "BENCH", "Benchmark log started. File: " + __cLogFileName, HB_LOG_INFO )
RETURN

STATIC PROCEDURE __CloseBenchLog()
   __LogLine( "BENCH", "Benchmark log finished.", HB_LOG_INFO )
   CLOSE LOG
RETURN

STATIC PROCEDURE __LogLine( cKey, cMessage, nSeverity )
   hb_default( @nSeverity, HB_LOG_DEBUG )
   LOG cKey + ": " + cMessage PRIORITY nSeverity
RETURN

STATIC FUNCTION __NowMs()
RETURN Int( Seconds() * 1000 )

STATIC FUNCTION __ToChar( uValue )
   LOCAL cType := ValType( uValue )

   DO CASE
   CASE cType == "C"
      RETURN uValue
   CASE cType == "N"
      RETURN hb_ntos( uValue )
   CASE cType == "L"
      RETURN IIf( uValue, ".T.", ".F." )
   CASE cType == "D"
      RETURN DToC( uValue )
   CASE cType == "U"
      RETURN ""
   OTHERWISE
      RETURN hb_ValToExp( uValue )
   ENDCASE
RETURN ""

STATIC FUNCTION __CsvEscape( cText )
   LOCAL cOut := __ToChar( cText )
   cOut := StrTran( cOut, '"', '""' )
RETURN '"' + cOut + '"'

STATIC PROCEDURE __CsvAppend( cLine )
   LOCAL nHandle

   IF ! hb_FileExists( __cCsvFileName )
      nHandle := FCreate( __cCsvFileName )
   ELSE
      nHandle := FOpen( __cCsvFileName, FO_READWRITE )
   ENDIF

   IF nHandle >= 0
      FSeek( nHandle, 0, FS_END )
      FWrite( nHandle, cLine + hb_eol() )
      FClose( nHandle )
   ENDIF
RETURN

STATIC PROCEDURE __CsvEnsureHeader()
   IF __lCsvHeader
      RETURN
   ENDIF

   IF ! hb_FileExists( __cCsvFileName )
      __CsvAppend( ;
         "timestamp,suite,engine,case_id,operation,loops,total_ms,avg_ms,expected,actual,status" )
   ENDIF

   __lCsvHeader := .T.
RETURN

STATIC PROCEDURE __CsvWrite( cSuite, cEngine, cCaseId, cOp, nLoops, nTotalMs, cExpected, cActual, cStatus )
   LOCAL nAvg := IIf( nLoops > 0, ( nTotalMs / nLoops ), 0 )
   LOCAL cLine := ;
      __CsvEscape( DToS( Date() ) + " " + Time() ) + "," + ;
      __CsvEscape( cSuite ) + "," + ;
      __CsvEscape( cEngine ) + "," + ;
      __CsvEscape( cCaseId ) + "," + ;
      __CsvEscape( cOp ) + "," + ;
      __CsvEscape( hb_ntos( nLoops ) ) + "," + ;
      __CsvEscape( hb_ntos( nTotalMs ) ) + "," + ;
      __CsvEscape( hb_ntos( nAvg ) ) + "," + ;
      __CsvEscape( cExpected ) + "," + ;
      __CsvEscape( cActual ) + "," + ;
      __CsvEscape( cStatus )

   __CsvEnsureHeader()
   __CsvAppend( cLine )
RETURN

STATIC FUNCTION __Canonical( cValue )
   LOCAL cText := AllTrim( __ToChar( cValue ) )
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

STATIC FUNCTION __BuildAccuracyCases()
   LOCAL aCases := {}

   AAdd( aCases, { "ACC_ADD_CARRY", "add", "999999999999999999999999999999", "1", 0, 0, "1000000000000000000000000000000", 1 } )
   AAdd( aCases, { "ACC_SUB_NEG", "sub", "12345678901234567890", "22345678901234567890", 0, 0, "-10000000000000000000", 1 } )
   AAdd( aCases, { "ACC_MUL", "mul", "123456789", "987654321", 0, 0, "121932631112635269", 1 } )
   AAdd( aCases, { "ACC_DIV_EXACT", "div", "144", "12", 0, 0, "12", 1 } )
   AAdd( aCases, { "ACC_MOD", "mod", "1000", "37", 0, 0, "1", 1 } )
   AAdd( aCases, { "ACC_POWINT", "powint", "2", "", 0, 32, "4294967296", 1 } )
   AAdd( aCases, { "ACC_GCD", "gcd", "12345678901234567890", "9876543210", 0, 0, "90", 1 } )
   AAdd( aCases, { "ACC_LCM", "lcm", "21", "6", 0, 0, "42", 1 } )

RETURN aCases

STATIC FUNCTION __BuildPerfCases()
   LOCAL aCases := {}

   AAdd( aCases, { "PERF_ADD_96D", "add", "999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999", "1", 0, 0, "", 3000 } )
   AAdd( aCases, { "PERF_MUL_48D", "mul", "123456789012345678901234567890123456789012345678", "876543210987654321098765432109876543210987654321", 0, 0, "", 600 } )
   AAdd( aCases, { "PERF_MOD_96D", "mod", "123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456", "9876543210123456789", 0, 0, "", 900 } )
   AAdd( aCases, { "PERF_POWINT", "powint", "3", "", 0, 120, "", 220 } )
   AAdd( aCases, { "PERF_GCD", "gcd", "123456789012345678901234567890", "98765432109876543210", 0, 0, "", 1200 } )

RETURN aCases

STATIC FUNCTION __EvalHBNum( aCase )
   LOCAL oA := HBNum():New( aCase[ C_A ] )
   LOCAL oR := HBNum():New( "0" )

   DO CASE
   CASE aCase[ C_OP ] == "add"
      oR := oA:Add( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "sub"
      oR := oA:Sub( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "mul"
      oR := oA:Mul( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "div"
      oR := oA:Div( aCase[ C_B ], aCase[ C_PREC ] )
   CASE aCase[ C_OP ] == "mod"
      oR := oA:Mod( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "powint"
      oR := oA:PowInt( aCase[ C_EXP ] )
   CASE aCase[ C_OP ] == "gcd"
      oR := oA:Gcd( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "lcm"
      oR := oA:Lcm( aCase[ C_B ] )
   OTHERWISE
      BREAK
   ENDCASE

RETURN __Canonical( oR:ToString() )

#ifdef HBNUM_BENCH_WITH_TBIG
STATIC FUNCTION __EvalTBig( aCase )
   LOCAL oA := tBigNumber():New( aCase[ C_A ] )
   LOCAL oR
   LOCAL cOut

   DO CASE
   CASE aCase[ C_OP ] == "add"
      oR := oA:Add( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "sub"
      oR := oA:Sub( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "mul"
      oR := oA:Mult( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "div"
      oR := oA:Div( aCase[ C_B ], .F. )
   CASE aCase[ C_OP ] == "mod"
      oR := oA:Mod( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "powint"
      oR := oA:Pow( hb_ntos( aCase[ C_EXP ] ), .T. )
   CASE aCase[ C_OP ] == "gcd"
      oR := oA:GCD( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "lcm"
      oR := oA:LCM( aCase[ C_B ] )
   OTHERWISE
      BREAK
   ENDCASE

   IF ValType( oR ) == "O"
      cOut := oR:ExactValue( .F., .F. )
   ELSE
      cOut := __ToChar( oR )
   ENDIF

RETURN __Canonical( cOut )
#endif

STATIC FUNCTION __RunAccuracyHBNum( aCases )
   LOCAL nI
   LOCAL aCase
   LOCAL cExpected
   LOCAL cActual
   LOCAL lPass
   LOCAL nStart
   LOCAL nElapsed
   LOCAL lOk := .T.

   ? "== ACCURACY (HBNum) =="
   __LogLine( "ACCURACY", "HBNum accuracy suite started.", HB_LOG_INFO )

   FOR nI := 1 TO Len( aCases )
      aCase := aCases[ nI ]
      cExpected := __Canonical( aCase[ C_EXPECT ] )

      BEGIN SEQUENCE
         nStart := __NowMs()
         cActual := __EvalHBNum( aCase )
         nElapsed := __NowMs() - nStart
         lPass := cActual == cExpected
      RECOVER
         cActual := "[EXCEPTION]"
         nElapsed := 0
         lPass := .F.
      END SEQUENCE

      ? IIf( lPass, "[PASS]", "[FAIL]" ), aCase[ C_ID ], ;
        "op:", aCase[ C_OP ], ;
        "expected:", cExpected, ;
        "actual:", cActual

      __LogLine( "ACCURACY_HBNUM", ;
         aCase[ C_ID ] + " op=" + aCase[ C_OP ] + ;
         " expected=[" + cExpected + "] actual=[" + cActual + "]" + ;
         " status=" + IIf( lPass, "PASS", "FAIL" ), ;
         IIf( lPass, HB_LOG_INFO, HB_LOG_ERROR ) )

      __CsvWrite( ;
         "accuracy", ;
         "hbnum", ;
         aCase[ C_ID ], ;
         aCase[ C_OP ], ;
         1, ;
         nElapsed, ;
         cExpected, ;
         cActual, ;
         IIf( lPass, "PASS", "FAIL" ) )

      lOk := lOk .AND. lPass
   NEXT

RETURN lOk

#ifdef HBNUM_BENCH_WITH_TBIG
STATIC FUNCTION __RunAccuracyCompare( aCases )
   LOCAL nI
   LOCAL aCase
   LOCAL cExpected
   LOCAL cHB
   LOCAL cTB
   LOCAL lPass
   LOCAL nStart
   LOCAL nElapsed
   LOCAL lOk := .T.

   ? "== ACCURACY (HBNum x tBigNumber) =="
   __LogLine( "ACCURACY", "Comparative accuracy suite started.", HB_LOG_INFO )

   FOR nI := 1 TO Len( aCases )
      aCase := aCases[ nI ]
      cExpected := __Canonical( aCase[ C_EXPECT ] )

      BEGIN SEQUENCE
         nStart := __NowMs()
         cHB := __EvalHBNum( aCase )
         cTB := __EvalTBig( aCase )
         nElapsed := __NowMs() - nStart
         lPass := ( cHB == cExpected ) .AND. ( cTB == cExpected ) .AND. ( cHB == cTB )
      RECOVER
         cHB := "[EXCEPTION]"
         cTB := "[EXCEPTION]"
         nElapsed := 0
         lPass := .F.
      END SEQUENCE

      ? IIf( lPass, "[PASS]", "[FAIL]" ), aCase[ C_ID ], ;
        "HBNum:", cHB, ;
        "tBig:", cTB, ;
        "expected:", cExpected

      __LogLine( "ACCURACY_COMPARE", ;
         aCase[ C_ID ] + " op=" + aCase[ C_OP ] + ;
         " hbnum=[" + cHB + "] tbig=[" + cTB + "] expected=[" + cExpected + "]" + ;
         " status=" + IIf( lPass, "PASS", "FAIL" ), ;
         IIf( lPass, HB_LOG_INFO, HB_LOG_ERROR ) )

      __CsvWrite( ;
         "accuracy_compare", ;
         "hbnum_vs_tbig", ;
         aCase[ C_ID ], ;
         aCase[ C_OP ], ;
         1, ;
         nElapsed, ;
         cExpected, ;
         "HBNum=" + cHB + "; tBig=" + cTB, ;
         IIf( lPass, "PASS", "FAIL" ) )

      lOk := lOk .AND. lPass
   NEXT

RETURN lOk
#endif

STATIC PROCEDURE __RunPerfHBNum( aCases )
   LOCAL nI
   LOCAL aCase
   LOCAL nLoop
   LOCAL nStart
   LOCAL nElapsed
   LOCAL cLast := ""

   ? "== PERFORMANCE (HBNum) =="
   __LogLine( "PERF", "HBNum performance suite started.", HB_LOG_INFO )

   FOR nI := 1 TO Len( aCases )
      aCase := aCases[ nI ]

      nStart := __NowMs()
      FOR nLoop := 1 TO aCase[ C_LOOPS ]
         cLast := __EvalHBNum( aCase )
      NEXT
      nElapsed := __NowMs() - nStart

      ? "[PERF][HBNum]", aCase[ C_ID ], ;
        "op:", aCase[ C_OP ], ;
        "loops:", hb_ntos( aCase[ C_LOOPS ] ), ;
        "total_ms:", hb_ntos( nElapsed ), ;
        "avg_ms:", hb_ntos( nElapsed / aCase[ C_LOOPS ] )

      __LogLine( "PERF_HBNUM", ;
         aCase[ C_ID ] + " op=" + aCase[ C_OP ] + ;
         " loops=" + hb_ntos( aCase[ C_LOOPS ] ) + ;
         " total_ms=" + hb_ntos( nElapsed ) + ;
         " avg_ms=" + hb_ntos( nElapsed / aCase[ C_LOOPS ] ) + ;
         " last=[" + cLast + "]", ;
         HB_LOG_INFO )

      __CsvWrite( ;
         "performance", ;
         "hbnum", ;
         aCase[ C_ID ], ;
         aCase[ C_OP ], ;
         aCase[ C_LOOPS ], ;
         nElapsed, ;
         "", ;
         cLast, ;
         "OK" )
   NEXT
RETURN

#ifdef HBNUM_BENCH_WITH_TBIG
STATIC PROCEDURE __RunPerfTBig( aCases )
   LOCAL nI
   LOCAL aCase
   LOCAL nLoop
   LOCAL nBenchLoops
   LOCAL nStart
   LOCAL nElapsed
   LOCAL cLast := ""

   ? "== PERFORMANCE (tBigNumber) =="
   __LogLine( "PERF", "tBigNumber performance suite started.", HB_LOG_INFO )

   FOR nI := 1 TO Len( aCases )
      aCase := aCases[ nI ]
      nBenchLoops := ;
         IIf( aCase[ C_OP ] == "powint", 20, ;
         IIf( aCase[ C_OP ] == "mul", 120, ;
         IIf( aCase[ C_OP ] == "mod", 120, ;
         IIf( aCase[ C_OP ] == "gcd", 180, ;
         Min( aCase[ C_LOOPS ], 1000 ) ) ) ) )

      BEGIN SEQUENCE
         nStart := __NowMs()
         FOR nLoop := 1 TO nBenchLoops
            cLast := __EvalTBig( aCase )
         NEXT
         nElapsed := __NowMs() - nStart
      RECOVER
         cLast := "[EXCEPTION]"
         nElapsed := 0
      END SEQUENCE

      ? "[PERF][tBig]", aCase[ C_ID ], ;
        "op:", aCase[ C_OP ], ;
        "loops:", hb_ntos( nBenchLoops ), ;
        "total_ms:", hb_ntos( nElapsed ), ;
        "avg_ms:", hb_ntos( IIf( nBenchLoops > 0, ( nElapsed / nBenchLoops ), 0 ) )

      __LogLine( "PERF_TBIG", ;
         aCase[ C_ID ] + " op=" + aCase[ C_OP ] + ;
         " loops=" + hb_ntos( nBenchLoops ) + ;
         " total_ms=" + hb_ntos( nElapsed ) + ;
         " avg_ms=" + hb_ntos( IIf( nBenchLoops > 0, ( nElapsed / nBenchLoops ), 0 ) ) + ;
         " last=[" + cLast + "]", ;
         HB_LOG_INFO )

      __CsvWrite( ;
         "performance", ;
         "tbig", ;
         aCase[ C_ID ], ;
         aCase[ C_OP ], ;
         nBenchLoops, ;
         nElapsed, ;
         "", ;
         cLast, ;
         "OK" )
   NEXT
RETURN
#endif

FUNCTION Main()
   LOCAL aAccuracyCases := __BuildAccuracyCases()
   LOCAL aPerfCases := __BuildPerfCases()
   LOCAL lOk := .T.

   __InitBenchLog()

   ? "HBNum Benchmark/Accuracy Suite"
   ? "Log file :", __cLogFileName
   ? "CSV file :", __cCsvFileName

   lOk := __RunAccuracyHBNum( aAccuracyCases ) .AND. lOk

#ifdef HBNUM_BENCH_WITH_TBIG
   lOk := __RunAccuracyCompare( aAccuracyCases ) .AND. lOk
#else
   ? "Comparative mode with tBigNumber is disabled in this build."
   __LogLine( "ACCURACY", "Comparative mode disabled (build without HBNUM_BENCH_WITH_TBIG).", HB_LOG_INFO )
#endif

   __RunPerfHBNum( aPerfCases )

#ifdef HBNUM_BENCH_WITH_TBIG
   __RunPerfTBig( aPerfCases )
#endif

   IF lOk
      ? "BENCHMARK/ACCURACY: PASS"
      __LogLine( "RESULT", "BENCHMARK/ACCURACY: PASS", HB_LOG_INFO )
      __CloseBenchLog()
      RETURN 0
   ENDIF

   ? "BENCHMARK/ACCURACY: FAIL"
   __LogLine( "RESULT", "BENCHMARK/ACCURACY: FAIL", HB_LOG_ERROR )
   __CloseBenchLog()
RETURN 1
