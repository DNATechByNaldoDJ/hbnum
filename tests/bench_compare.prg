/*
hbnum: Released to Public Domain.
*/
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
#define C_TBIG_CFG  9
#define C_TBIG_VIEW 10

#define TBIG_CFG_SETDEC   1
#define TBIG_CFG_ROOTACC  2
#define TBIG_CFG_SYSSQRT  3

#define TBIG_VIEW_MODE    1
#define TBIG_VIEW_DIGITS  2

#define TBIG_VIEW_EXACT   1
#define TBIG_VIEW_RND     2
#define TBIG_VIEW_NORND   3

STATIC __cLogFileName := ""
STATIC __cCsvFileName := ""
STATIC __lCsvHeader := .F.

STATIC PROCEDURE __InitBenchLog()
   LOCAL nStyle := HB_LOG_ST_DATE + HB_LOG_ST_ISODATE + HB_LOG_ST_TIME + HB_LOG_ST_LEVEL
   LOCAL nSeverity := HB_LOG_DEBUG
   LOCAL nFileSize := 2 * 1024 * 1024
   LOCAL nFileCount := 5

   __cLogFileName := HBNumTestArtifactPath( "hbnum_bench_compare.log" )
   __cCsvFileName := HBNumTestArtifactPath( "hbnum_bench_compare.csv" )
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

STATIC PROCEDURE __AppendCases( aTarget, aSource )
   LOCAL nI

   FOR nI := 1 TO Len( aSource )
      AAdd( aTarget, aSource[ nI ] )
   NEXT
RETURN

STATIC FUNCTION __TBigCfg( nSetDecimals, nRootAcc, nSysSQRT )
RETURN { nSetDecimals, nRootAcc, nSysSQRT }

STATIC FUNCTION __TBigView( nMode, nDigits )
RETURN { nMode, nDigits }

STATIC FUNCTION __ShiftText( cText, nZeros )
RETURN cText + Replicate( "0", Max( Int( nZeros ), 0 ) )

STATIC FUNCTION __Pow10Text( nExp )
RETURN __ShiftText( "1", nExp )

#ifdef HBNUM_BENCH_WITH_TBIG
STATIC FUNCTION __BuildAccuracyCompareRootLogCases()
   LOCAL aCases := {}
   LOCAL aRootCfg := __TBigCfg( 50, 50, 0 )
   LOCAL aLog0Cfg := __TBigCfg( 50, 49, 0 )
   LOCAL aLog1Cfg := __TBigCfg( 50, 50, 0 )
   LOCAL aExactView := __TBigView( TBIG_VIEW_EXACT, NIL )
   LOCAL aPrecView := __TBigView( TBIG_VIEW_NORND, NIL )

   AAdd( aCases, { "ACC_SQRT_BIG_EXACT", "sqrt", "15241578753238836750495351562536198787501905199875019052100", "", 0, 0, "123456789012345678901234567890", 1, aRootCfg, aPrecView } )
   AAdd( aCases, { "ACC_SQRT_POW10_200", "sqrt", __Pow10Text( 200 ), "", 0, 0, __Pow10Text( 100 ), 1, aRootCfg, aExactView } )
   AAdd( aCases, { "ACC_NTHROOT_BIG_IDENTITY", "nthroot", "1234567890123456789012345678901234567890", 1, 0, 0, "1234567890123456789012345678901234567890", 1, aRootCfg, aExactView } )
   AAdd( aCases, { "ACC_LOG_BASE2_POW2_512", "log", "13407807929942597099574024998205846127479365820592393377723561443721764030073546976801874298166903427690031858186486050853753882811946569946433649006084096", "2", NIL, 0, "512", 1, aLog0Cfg, aExactView } )
   AAdd( aCases, { "ACC_LOG_BASE10POW100_POW10_300", "log", __Pow10Text( 300 ), __Pow10Text( 100 ), NIL, 0, "3", 1, aLog0Cfg, aExactView } )
   AAdd( aCases, { "ACC_LOG10_POW10_300", "log10", __Pow10Text( 300 ), "", NIL, 0, "300", 1, aLog0Cfg, aExactView } )
   AAdd( aCases, { "ACC_LN_POW10_80_12", "ln", "100000000000000000000000000000000000000000000000000000000000000000000000000000000", "", 12, 0, "184.206807439523", 1, aLog1Cfg, aPrecView } )

RETURN aCases
#endif

STATIC FUNCTION __BuildRootLogCases()
   LOCAL aCases := {}
   LOCAL aRootCfg := __TBigCfg( 50, 50, 0 )
   LOCAL aLog0Cfg := __TBigCfg( 50, 49, 0 )
   LOCAL aLog1Cfg := __TBigCfg( 50, 50, 0 )
   LOCAL aExactView := __TBigView( TBIG_VIEW_EXACT, NIL )
   LOCAL aPrecView := __TBigView( TBIG_VIEW_NORND, NIL )

   AAdd( aCases, { "ACC_SQRT_BIG_EXACT", "sqrt", "15241578753238836750495351562536198787501905199875019052100", "", 0, 0, "123456789012345678901234567890", 1, aRootCfg, aPrecView } )
   AAdd( aCases, { "ACC_SQRT_POW10_200", "sqrt", __Pow10Text( 200 ), "", 0, 0, __Pow10Text( 100 ), 1, aRootCfg, aExactView } )
   AAdd( aCases, { "ACC_NTHROOT_BIG_IDENTITY", "nthroot", "1234567890123456789012345678901234567890", 1, 0, 0, "1234567890123456789012345678901234567890", 1, aRootCfg, aPrecView } )
   AAdd( aCases, { "ACC_NTHROOT_POW10_300_CUBE", "nthroot", __Pow10Text( 300 ), 3, 0, 0, __Pow10Text( 100 ), 1, aRootCfg, aExactView } )
   AAdd( aCases, { "ACC_LOG_BASE2_POW2_512", "log", "13407807929942597099574024998205846127479365820592393377723561443721764030073546976801874298166903427690031858186486050853753882811946569946433649006084096", "2", NIL, 0, "512", 1, aLog0Cfg, aExactView } )
   AAdd( aCases, { "ACC_LOG_BASE10POW100_POW10_300", "log", __Pow10Text( 300 ), __Pow10Text( 100 ), NIL, 0, "3", 1, aLog0Cfg, aExactView } )
   AAdd( aCases, { "ACC_LOG10_POW10_300", "log10", __Pow10Text( 300 ), "", NIL, 0, "300", 1, aLog0Cfg, aExactView } )
   AAdd( aCases, { "ACC_LN_POW10_80_12", "ln", "100000000000000000000000000000000000000000000000000000000000000000000000000000000", "", 12, 0, "184.206807439523", 1, aLog1Cfg, aPrecView } )

RETURN aCases

STATIC FUNCTION __BuildRootLogPerfCases()
   LOCAL aCases := {}
   LOCAL aRootCfg := __TBigCfg( 50, 50, 0 )
   LOCAL aLog0Cfg := __TBigCfg( 50, 49, 0 )
   LOCAL aLog1Cfg := __TBigCfg( 50, 50, 0 )

   AAdd( aCases, { "PERF_SQRT_10P200", "sqrt", __Pow10Text( 200 ), "", 0, 0, "", 24, aRootCfg } )
   AAdd( aCases, { "PERF_NTHROOT_10P300_CUBE", "nthroot", __Pow10Text( 300 ), 3, 0, 0, "", 16, aRootCfg } )
   AAdd( aCases, { "PERF_LOG_BASE10P100_10P300", "log", __Pow10Text( 300 ), __Pow10Text( 100 ), 0, 0, "", 12, aLog0Cfg } )
   AAdd( aCases, { "PERF_LOG10_10P300", "log10", __Pow10Text( 300 ), "", 0, 0, "", 14, aLog0Cfg } )
   AAdd( aCases, { "PERF_LN_10P200", "ln", __Pow10Text( 200 ), "", 12, 0, "", 10, aLog1Cfg } )

RETURN aCases

STATIC FUNCTION __BuildAccuracyCases()
   LOCAL aCases := {}

   AAdd( aCases, { "ACC_COMPARE_BIG_GT", "compare", "98765432109876543210987654321098765432109876543211", "98765432109876543210987654321098765432109876543210", 0, 0, "1", 1 } )
   AAdd( aCases, { "ACC_COMPARE_BIG_EQ_SCALE", "compare", "1234567890123456789012345678901234567890.1234500", "1234567890123456789012345678901234567890.12345", 0, 0, "0", 1 } )
   AAdd( aCases, { "ACC_COMPARE_BIG_NEG", "compare", "-99999999999999999999999999999999999999999999999999", "-99999999999999999999999999999999999999999999999998", 0, 0, "-1", 1 } )
   AAdd( aCases, { "ACC_ADD_CARRY_180D", "add", Replicate( "9", 180 ), "1", 0, 0, __Pow10Text( 180 ), 1 } )
   AAdd( aCases, { "ACC_ADD_SCALE_BIG", "add", "1234567890123456789012345678901234567890.4500", "0.55", 0, 0, "1234567890123456789012345678901234567891", 1 } )
   AAdd( aCases, { "ACC_ADD_BIG_TBIG", "add", "12345678901234567890123456789012345678901234567890", "98765432109876543210987654321098765432109876543210", 0, 0, "111111111011111111101111111110111111111011111111100", 1 } )
   AAdd( aCases, { "ACC_SUB_NEG_POW10_200", "sub", __Pow10Text( 200 ), __ShiftText( "2", 200 ), 0, 0, "-" + __Pow10Text( 200 ), 1 } )
   AAdd( aCases, { "ACC_SUB_DEC_NEG_BIG", "sub", "-" + __Pow10Text( 120 ) + ".25", "0.75", 0, 0, "-" + "1" + Replicate( "0", 119 ) + "1", 1 } )
   AAdd( aCases, { "ACC_SUB_BIG_TBIG", "sub", "12345678901234567890123456789012345678901234567890", "98765432109876543210987654321098765432109876543210", 0, 0, "-86419753208641975320864197532086419753208641975320", 1 } )
   AAdd( aCases, { "ACC_MUL_BIG_TBIG", "mul", "12345678901234567890123456789", "98765432109876543210987654321", 0, 0, "1219326311370217952261850327336229233322374638011112635269", 1 } )
   AAdd( aCases, { "ACC_MUL_DEC_BIG", "mul", __ShiftText( "125", 118 ), "0.4", 0, 0, __ShiftText( "5", 119 ), 1 } )
   AAdd( aCases, { "ACC_MUL_POW10_120_80", "mul", __Pow10Text( 120 ), __Pow10Text( 80 ), 0, 0, __Pow10Text( 200 ), 1 } )
   AAdd( aCases, { "ACC_DIV_BIG_TBIG", "div", "1219326311370217952261850327336229233322374638011112635269", "12345678901234567890123456789", 0, 0, "98765432109876543210987654321", 1 } )
   AAdd( aCases, { "ACC_DIV_DEC_EXACT_BIG", "div", __ShiftText( "125", 118 ), "0.5", 0, 0, __ShiftText( "25", 119 ), 1 } )
   AAdd( aCases, { "ACC_DIV_POW10_300_120", "div", __Pow10Text( 300 ), __Pow10Text( 120 ), 0, 0, __Pow10Text( 180 ), 1 } )
   AAdd( aCases, { "ACC_MOD_BIG_TBIG", "mod", "1219326311370217952249657064224965706422496570642237463801112498094790", "12345678901234567890123456789012345678901234567890", 0, 0, "1234567890", 1 } )
   AAdd( aCases, { "ACC_MOD_SCALE_BIG", "mod", __Pow10Text( 120 ) + ".5", "0.2", 0, 0, "0.1", 1 } )
   AAdd( aCases, { "ACC_MOD_NEG_DIVISOR_BIG", "mod", __Pow10Text( 120 ) + ".5", "-0.2", 0, 0, "0.1", 1 } )
   AAdd( aCases, { "ACC_MOD_POW10_200_DELTA", "mod", "1" + Replicate( "0", 180 ) + "12345678901234567890", __Pow10Text( 200 ), 0, 0, "12345678901234567890", 1 } )
   AAdd( aCases, { "ACC_POWINT_NEG_EVEN_BIG", "powint", "-" + __Pow10Text( 30 ), "", 0, 4, __Pow10Text( 120 ), 1 } )
   AAdd( aCases, { "ACC_POWINT_GOOLOL", "powint", "10", "", 0, 100, "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000", 1 } )
   AAdd( aCases, { "ACC_POWINT_POW10_100_CUBE", "powint", __Pow10Text( 100 ), "", 0, 3, __Pow10Text( 300 ), 1 } )
   AAdd( aCases, { "ACC_GCD_BIG_COPRIME", "gcd", __Pow10Text( 200 ), "1" + Replicate( "0", 199 ) + "1", 0, 0, "1", 1 } )
   AAdd( aCases, { "ACC_GCD_BIG_TBIG", "gcd", "456790119345679011934567901193456790119345679011930", "1123456780012345678001234567800123456780012345677990", 0, 0, "12345678901234567890123456789012345678901234567890", 1 } )
   AAdd( aCases, { "ACC_GCD_POW10_FACTORED", "gcd", __ShiftText( "37", 120 ), __ShiftText( "74", 120 ), 0, 0, __ShiftText( "37", 120 ), 1 } )
   AAdd( aCases, { "ACC_LCM_BIG_TBIG", "lcm", "456790119345679011934567901193456790119345679011930", "1123456780012345678001234567800123456780012345677990", 0, 0, "41567900860456790086045679008604567900860456790085630", 1 } )
   AAdd( aCases, { "ACC_LCM_POW10_FACTORED", "lcm", __ShiftText( "37", 120 ), __ShiftText( "91", 120 ), 0, 0, __ShiftText( "3367", 120 ), 1 } )

   __AppendCases( aCases, __BuildRootLogCases() )

RETURN aCases

#ifdef HBNUM_BENCH_WITH_TBIG
STATIC FUNCTION __BuildAccuracyCompareCases()
   LOCAL aCases := {}

   AAdd( aCases, { "ACC_COMPARE_BIG_GT", "compare", "98765432109876543210987654321098765432109876543211", "98765432109876543210987654321098765432109876543210", 0, 0, "1", 1 } )
   AAdd( aCases, { "ACC_COMPARE_BIG_EQ_SCALE", "compare", "1234567890123456789012345678901234567890.1234500", "1234567890123456789012345678901234567890.12345", 0, 0, "0", 1 } )
   AAdd( aCases, { "ACC_COMPARE_BIG_NEG", "compare", "-99999999999999999999999999999999999999999999999999", "-99999999999999999999999999999999999999999999999998", 0, 0, "-1", 1 } )
   AAdd( aCases, { "ACC_ADD_BIG_TBIG", "add", "12345678901234567890123456789012345678901234567890", "98765432109876543210987654321098765432109876543210", 0, 0, "111111111011111111101111111110111111111011111111100", 1 } )
   AAdd( aCases, { "ACC_ADD_POW10_200", "add", __Pow10Text( 200 ), __Pow10Text( 200 ), 0, 0, __ShiftText( "2", 200 ), 1 } )
   AAdd( aCases, { "ACC_SUB_BIG_TBIG", "sub", "12345678901234567890123456789012345678901234567890", "98765432109876543210987654321098765432109876543210", 0, 0, "-86419753208641975320864197532086419753208641975320", 1 } )
   AAdd( aCases, { "ACC_SUB_POW10_200", "sub", __ShiftText( "2", 200 ), __Pow10Text( 200 ), 0, 0, __Pow10Text( 200 ), 1 } )
   AAdd( aCases, { "ACC_MUL_BIG_TBIG", "mul", "12345678901234567890123456789", "98765432109876543210987654321", 0, 0, "1219326311370217952261850327336229233322374638011112635269", 1 } )
   AAdd( aCases, { "ACC_MUL_POW10_120_80", "mul", __Pow10Text( 120 ), __Pow10Text( 80 ), 0, 0, __Pow10Text( 200 ), 1 } )
   AAdd( aCases, { "ACC_DIV_BIG_TBIG", "div", "1219326311370217952261850327336229233322374638011112635269", "12345678901234567890123456789", 0, 0, "98765432109876543210987654321", 1 } )
   AAdd( aCases, { "ACC_DIV_POW10_300_120", "div", __Pow10Text( 300 ), __Pow10Text( 120 ), 0, 0, __Pow10Text( 180 ), 1 } )
   AAdd( aCases, { "ACC_MOD_BIG_TBIG", "mod", "1219326311370217952249657064224965706422496570642237463801112498094790", "12345678901234567890123456789012345678901234567890", 0, 0, "1234567890", 1 } )
   AAdd( aCases, { "ACC_MOD_POW10_200_DELTA", "mod", "1" + Replicate( "0", 180 ) + "12345678901234567890", __Pow10Text( 200 ), 0, 0, "12345678901234567890", 1 } )
   AAdd( aCases, { "ACC_POWINT_POW10_100_CUBE", "powint", __Pow10Text( 100 ), "", 0, 3, __Pow10Text( 300 ), 1 } )
   AAdd( aCases, { "ACC_GCD_POW10_FACTORED", "gcd", __ShiftText( "37", 120 ), __ShiftText( "74", 120 ), 0, 0, __ShiftText( "37", 120 ), 1 } )
   AAdd( aCases, { "ACC_LCM_POW10_FACTORED", "lcm", __ShiftText( "37", 120 ), __ShiftText( "91", 120 ), 0, 0, __ShiftText( "3367", 120 ), 1 } )

   __AppendCases( aCases, __BuildAccuracyCompareRootLogCases() )

RETURN aCases
#endif

STATIC FUNCTION __BuildPerfCases()
   LOCAL aCases := {}

   AAdd( aCases, { "PERF_ADD_384D", "add", Replicate( "9", 384 ), "1", 0, 0, "", 1200 } )
   AAdd( aCases, { "PERF_MUL_192D", "mul", Replicate( "1234567890", 19 ) + "12", Replicate( "9876543210", 19 ) + "98", 0, 0, "", 180 } )
   AAdd( aCases, { "PERF_MOD_512D", "mod", Replicate( "1234567890", 51 ) + "12", "98765432101234567899876543210123456789", 0, 0, "", 280 } )
   AAdd( aCases, { "PERF_POWINT_10P100_CUBE", "powint", __Pow10Text( 100 ), "", 0, 3, "", 48 } )
   AAdd( aCases, { "PERF_GCD_240D", "gcd", "456790119345679011934567901193456790119345679011930", "1123456780012345678001234567800123456780012345677990", 0, 0, "", 240 } )

   __AppendCases( aCases, __BuildRootLogPerfCases() )

RETURN aCases

STATIC FUNCTION __ReadEnvText( cName, cDefault )
   LOCAL cValue := Upper( AllTrim( GetEnv( cName ) ) )

   IF Empty( cValue )
      RETURN cDefault
   ENDIF

RETURN cValue

STATIC FUNCTION __BenchCaseEnabled( aCase )
   LOCAL cFilter := __ReadEnvText( "HBNUM_BENCH_FILTER", "" )
   LOCAL cId := Upper( __ToChar( aCase[ C_ID ] ) )
   LOCAL cOp := Upper( __ToChar( aCase[ C_OP ] ) )

   IF Empty( cFilter )
      RETURN .T.
   ENDIF

   IF cFilter == "ROOTLOG"
      RETURN cOp == "SQRT" .OR. cOp == "NTHROOT" .OR. cOp == "LOG" .OR. cOp == "LOG10" .OR. cOp == "LN"
   ENDIF

RETURN cFilter $ cId .OR. cFilter $ cOp

STATIC FUNCTION __BenchSkipPerf()
   LOCAL cValue := __ReadEnvText( "HBNUM_BENCH_SKIP_PERF", "" )

RETURN cValue == "1" .OR. cValue == "TRUE" .OR. cValue == "YES" .OR. cValue == "ON"

#ifdef HBNUM_BENCH_WITH_TBIG
STATIC FUNCTION __CaseValue( aCase, nIndex )
   IF nIndex <= Len( aCase )
      RETURN aCase[ nIndex ]
   ENDIF
RETURN NIL

STATIC FUNCTION __TBigWorkPrecision( nPrecision )
   LOCAL nDigits := 48

   IF HB_ISNUMERIC( nPrecision )
      nDigits := Max( Int( nPrecision ), 0 ) + 8
      nDigits := Max( nDigits, 16 )
   ENDIF

RETURN nDigits

STATIC FUNCTION __CaseTBigCfgValue( aCase, nIndex )
   LOCAL aCfg := __CaseValue( aCase, C_TBIG_CFG )

   IF ValType( aCfg ) == "A" .AND. nIndex <= Len( aCfg )
      RETURN aCfg[ nIndex ]
   ENDIF
RETURN NIL

STATIC FUNCTION __CaseTBigViewValue( aCase, nIndex )
   LOCAL aView := __CaseValue( aCase, C_TBIG_VIEW )

   IF ValType( aView ) == "A" .AND. nIndex <= Len( aView )
      RETURN aView[ nIndex ]
   ENDIF
RETURN NIL

STATIC PROCEDURE __PrepareTBigCase( oValue, aCase )
   LOCAL nPrecision := aCase[ C_PREC ]
   LOCAL nDigits := __TBigWorkPrecision( nPrecision )
   LOCAL nSetDecimals := __CaseTBigCfgValue( aCase, TBIG_CFG_SETDEC )
   LOCAL nRootAcc := __CaseTBigCfgValue( aCase, TBIG_CFG_ROOTACC )
   LOCAL nSysSQRT := __CaseTBigCfgValue( aCase, TBIG_CFG_SYSSQRT )

   IF ! HB_ISNUMERIC( nSetDecimals )
      nSetDecimals := nDigits + 1
   ELSE
      nSetDecimals := Max( Int( nSetDecimals ), 0 )
   ENDIF

   IF ! HB_ISNUMERIC( nRootAcc )
      nRootAcc := nDigits
   ELSE
      nRootAcc := Max( Int( nRootAcc ), 0 )
   ENDIF

   IF ! HB_ISNUMERIC( nSysSQRT )
      nSysSQRT := 0
   ELSE
      nSysSQRT := Max( Int( nSysSQRT ), 0 )
   ENDIF

   oValue:SetDecimals( nSetDecimals )
   oValue:nthRootAcc( nRootAcc )
   oValue:SysSQRT( nSysSQRT )
RETURN

STATIC FUNCTION __TBigResultToCanonical( uValue, aCase )
   LOCAL cOut
   LOCAL nMode := __CaseTBigViewValue( aCase, TBIG_VIEW_MODE )
   LOCAL nDigits := __CaseTBigViewValue( aCase, TBIG_VIEW_DIGITS )

   IF ValType( uValue ) == "O"
      IF HB_ISNUMERIC( nMode )
         nMode := Max( Int( nMode ), 0 )
      ENDIF

      IF HB_ISNUMERIC( nDigits )
         nDigits := Max( Int( nDigits ), 0 )
      ELSEIF HB_ISNUMERIC( aCase[ C_PREC ] ) .AND. nMode != TBIG_VIEW_EXACT
         nDigits := Max( Int( aCase[ C_PREC ] ), 0 )
      ELSE
         nDigits := NIL
      ENDIF

      IF ! HB_ISNUMERIC( nMode )
         IF HB_ISNUMERIC( aCase[ C_PREC ] )
            nMode := TBIG_VIEW_NORND
            nDigits := Max( Int( aCase[ C_PREC ] ), 0 )
         ELSE
            nMode := TBIG_VIEW_EXACT
         ENDIF
      ENDIF

      DO CASE
      CASE nMode == TBIG_VIEW_RND .AND. HB_ISNUMERIC( nDigits )
         uValue := uValue:Rnd( nDigits )
      CASE nMode == TBIG_VIEW_NORND .AND. HB_ISNUMERIC( nDigits )
         uValue := uValue:NoRnd( nDigits )
      ENDCASE

      IF nMode == TBIG_VIEW_EXACT .AND. HB_ISNUMERIC( aCase[ C_PREC ] ) .AND. ;
            __CaseValue( aCase, C_TBIG_VIEW ) == NIL
         uValue := uValue:NoRnd( Max( Int( aCase[ C_PREC ] ), 0 ) )
      ENDIF
      cOut := uValue:ExactValue( .F., .F. )
   ELSE
      cOut := __ToChar( uValue )
   ENDIF

RETURN __Canonical( cOut )
#endif

STATIC FUNCTION __EvalHBNum( aCase )
   LOCAL oA := HBNum():New( aCase[ C_A ] )
   LOCAL oR := HBNum():New( "0" )

   DO CASE
   CASE aCase[ C_OP ] == "compare"
      RETURN hb_ntos( oA:Compare( aCase[ C_B ] ) )
   CASE aCase[ C_OP ] == "add"
      oR := oA:Add( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "sub"
      oR := oA:Sub( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "mul"
      oR := oA:Mul( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "div"
      IF aCase[ C_PREC ] == NIL
         oR := oA:Div( aCase[ C_B ] )
      ELSE
         oR := oA:Div( aCase[ C_B ], aCase[ C_PREC ] )
      ENDIF
   CASE aCase[ C_OP ] == "mod"
      oR := oA:Mod( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "powint"
      oR := oA:PowInt( aCase[ C_EXP ] )
   CASE aCase[ C_OP ] == "sqrt"
      IF aCase[ C_PREC ] == NIL
         oR := oA:Sqrt()
      ELSE
         oR := oA:Sqrt( aCase[ C_PREC ] )
      ENDIF
   CASE aCase[ C_OP ] == "nthroot"
      IF aCase[ C_PREC ] == NIL
         oR := oA:NthRoot( aCase[ C_B ] )
      ELSE
         oR := oA:NthRoot( aCase[ C_B ], aCase[ C_PREC ] )
      ENDIF
   CASE aCase[ C_OP ] == "log"
      IF aCase[ C_PREC ] == NIL
         oR := oA:Log( aCase[ C_B ] )
      ELSE
         oR := oA:Log( aCase[ C_B ], aCase[ C_PREC ] )
      ENDIF
   CASE aCase[ C_OP ] == "log10"
      IF aCase[ C_PREC ] == NIL
         oR := oA:Log10()
      ELSE
         oR := oA:Log10( aCase[ C_PREC ] )
      ENDIF
   CASE aCase[ C_OP ] == "ln"
      IF aCase[ C_PREC ] == NIL
         oR := oA:Ln()
      ELSE
         oR := oA:Ln( aCase[ C_PREC ] )
      ENDIF
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

   DO CASE
   CASE aCase[ C_OP ] == "compare"
      oR := tBigNumber():New( aCase[ C_B ] )
      IF oA > oR
         RETURN "1"
      ENDIF
      IF oA < oR
         RETURN "-1"
      ENDIF
      RETURN "0"
   CASE aCase[ C_OP ] == "add"
      oR := oA:Add( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "sub"
      oR := oA:Sub( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "mul"
      oR := oA:Mult( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "div"
      oR := oA:Div( aCase[ C_B ], .T. )
   CASE aCase[ C_OP ] == "mod"
      oR := oA:Mod( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "powint"
      oR := oA:Pow( hb_ntos( aCase[ C_EXP ] ), .T. )
   CASE aCase[ C_OP ] == "sqrt"
      __PrepareTBigCase( oA, aCase )
      oR := oA:SQRT()
   CASE aCase[ C_OP ] == "nthroot"
      __PrepareTBigCase( oA, aCase )
      oR := oA:nthRoot( IIf( HB_ISNUMERIC( aCase[ C_B ] ), hb_ntos( aCase[ C_B ] ), aCase[ C_B ] ) )
   CASE aCase[ C_OP ] == "log"
      __PrepareTBigCase( oA, aCase )
      oR := oA:Log( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "log10"
      __PrepareTBigCase( oA, aCase )
      oR := oA:Log10()
   CASE aCase[ C_OP ] == "ln"
      __PrepareTBigCase( oA, aCase )
      oR := oA:Ln()
   CASE aCase[ C_OP ] == "gcd"
      oR := oA:GCD( aCase[ C_B ] )
   CASE aCase[ C_OP ] == "lcm"
      oR := oA:LCM( aCase[ C_B ] )
   OTHERWISE
      BREAK
   ENDCASE

RETURN __TBigResultToCanonical( oR, aCase )
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

      IF ! __BenchCaseEnabled( aCase )
         LOOP
      ENDIF

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

      IF ! __BenchCaseEnabled( aCase )
         LOOP
      ENDIF

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

      IF ! __BenchCaseEnabled( aCase )
         LOOP
      ENDIF

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

      IF ! __BenchCaseEnabled( aCase )
         LOOP
      ENDIF

      DO CASE
      CASE aCase[ C_OP ] == "powint"
         nBenchLoops := 20
      CASE aCase[ C_OP ] == "mul"
         nBenchLoops := 120
      CASE aCase[ C_OP ] == "mod"
         nBenchLoops := 120
      CASE aCase[ C_OP ] == "gcd"
         nBenchLoops := 180
      CASE aCase[ C_OP ] == "sqrt"
         nBenchLoops := Min( aCase[ C_LOOPS ], 24 )
      CASE aCase[ C_OP ] == "nthroot"
         nBenchLoops := Min( aCase[ C_LOOPS ], 16 )
      CASE aCase[ C_OP ] == "log"
         nBenchLoops := Min( aCase[ C_LOOPS ], 10 )
      CASE aCase[ C_OP ] == "log10"
         nBenchLoops := Min( aCase[ C_LOOPS ], 12 )
      CASE aCase[ C_OP ] == "ln"
         nBenchLoops := Min( aCase[ C_LOOPS ], 8 )
      OTHERWISE
         nBenchLoops := Min( aCase[ C_LOOPS ], 1000 )
      ENDCASE

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
#ifdef HBNUM_BENCH_WITH_TBIG
   LOCAL aAccuracyCompareCases := __BuildAccuracyCompareCases()
#endif
   LOCAL aPerfCases := __BuildPerfCases()
   LOCAL lOk := .T.
   LOCAL lSkipPerf := __BenchSkipPerf()
   LOCAL cFilter := __ReadEnvText( "HBNUM_BENCH_FILTER", "" )

   __InitBenchLog()

   ? "HBNum Benchmark/Accuracy Suite"
   ? "Log file :", __cLogFileName
   ? "CSV file :", __cCsvFileName
   IF ! Empty( cFilter )
      ? "Filter   :", cFilter
      __LogLine( "BENCH", "Case filter active: " + cFilter, HB_LOG_INFO )
   ENDIF

   lOk := __RunAccuracyHBNum( aAccuracyCases ) .AND. lOk

#ifdef HBNUM_BENCH_WITH_TBIG
   lOk := __RunAccuracyCompare( aAccuracyCompareCases ) .AND. lOk
#else
   ? "Comparative mode with tBigNumber is disabled in this build."
   __LogLine( "ACCURACY", "Comparative mode disabled (build without HBNUM_BENCH_WITH_TBIG).", HB_LOG_INFO )
#endif

   IF lSkipPerf
      ? "Performance suites skipped by HBNUM_BENCH_SKIP_PERF."
      __LogLine( "PERF", "Performance suites skipped by environment request.", HB_LOG_INFO )
   ELSE
      __RunPerfHBNum( aPerfCases )

#ifdef HBNUM_BENCH_WITH_TBIG
      __RunPerfTBig( aPerfCases )
#endif
   ENDIF

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
