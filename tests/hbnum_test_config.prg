/*
hbnum: Released to Public Domain.
*/

STATIC s_hHBNumTestConfig := NIL
STATIC s_lHBNumTestConfigLoaded := .F.
STATIC s_cHBNumTestConfigPath := ""

FUNCTION HBNumTestConfigPath()
   LOCAL cEnvPath := AllTrim( GetEnv( "HBNUM_TEST_INI" ) )

   IF ! Empty( cEnvPath )
      RETURN cEnvPath
   ENDIF

RETURN HBNumTestProjectPath( "tests/hbnum_test.ini" )

FUNCTION HBNumTestConfigProfileName()
RETURN Lower( AllTrim( GetEnv( "HBNUM_TEST_PROFILE" ) ) )

FUNCTION HBNumTestConfigLoadedPath()
   HBNumTestConfigLoad()
RETURN s_cHBNumTestConfigPath

FUNCTION HBNumTestConfigLoad()
   LOCAL cPath
   LOCAL cMemo
   LOCAL cLine
   LOCAL cSection := ""
   LOCAL nEq
   LOCAL cKey
   LOCAL cValue

   IF s_lHBNumTestConfigLoaded
      RETURN ! Empty( s_cHBNumTestConfigPath ) .AND. File( s_cHBNumTestConfigPath )
   ENDIF

   s_lHBNumTestConfigLoaded := .T.
   s_hHBNumTestConfig := { => }
   cPath := HBNumTestConfigPath()
   s_cHBNumTestConfigPath := cPath

   IF Empty( cPath ) .OR. ! File( cPath )
      RETURN .F.
   ENDIF

   cMemo := hb_MemoRead( cPath )
   FOR EACH cLine IN hb_ATokens( cMemo, .T. )
      cLine := AllTrim( cLine )

      IF Empty( cLine ) .OR. Left( cLine, 1 ) == "#" .OR. Left( cLine, 1 ) == ";"
         LOOP
      ENDIF

      IF Left( cLine, 1 ) == "[" .AND. Right( cLine, 1 ) == "]"
         cSection := Lower( AllTrim( SubStr( cLine, 2, Len( cLine ) - 2 ) ) )
         LOOP
      ENDIF

      nEq := At( "=", cLine )
      IF Empty( cSection ) .OR. nEq <= 0
         LOOP
      ENDIF

      cKey := Lower( AllTrim( Left( cLine, nEq - 1 ) ) )
      cValue := __HBNumTestConfigUnquote( AllTrim( SubStr( cLine, nEq + 1 ) ) )

      IF ! Empty( cKey )
         s_hHBNumTestConfig[ cSection + "." + cKey ] := cValue
      ENDIF
   NEXT

RETURN .T.

FUNCTION HBNumTestConfigGet( cSection, cKey, cDefault )
   LOCAL cLookup
   LOCAL cProfileLookup
   LOCAL cProfile
   LOCAL xValue

   HBNumTestConfigLoad()

   cSection := Lower( AllTrim( cSection ) )
   cKey := Lower( AllTrim( cKey ) )
   cLookup := cSection + "." + cKey
   cProfile := HBNumTestConfigProfileName()

   IF ! Empty( cProfile )
      cProfileLookup := "profile." + cProfile + "." + cLookup
      xValue := hb_HGetDef( s_hHBNumTestConfig, cProfileLookup, NIL )
      IF xValue != NIL
         RETURN xValue
      ENDIF
   ENDIF

RETURN hb_HGetDef( s_hHBNumTestConfig, cLookup, cDefault )

FUNCTION HBNumTestConfigGetText( cSection, cKey, cDefault, cEnvName )
   LOCAL cEnvValue
   LOCAL xValue

   hb_default( @cEnvName, "" )

   IF ! Empty( cEnvName )
      cEnvValue := AllTrim( GetEnv( cEnvName ) )
      IF ! Empty( cEnvValue )
         RETURN cEnvValue
      ENDIF
   ENDIF

   xValue := HBNumTestConfigGet( cSection, cKey, cDefault )
   IF xValue == NIL
      RETURN cDefault
   ENDIF

   DO CASE
   CASE ValType( xValue ) == "C"
      RETURN AllTrim( xValue )
   CASE ValType( xValue ) == "N"
      RETURN hb_ntos( xValue )
   CASE ValType( xValue ) == "L"
      RETURN IIf( xValue, "true", "false" )
   ENDCASE

RETURN AllTrim( hb_ValToExp( xValue ) )

FUNCTION HBNumTestConfigGetInt( cSection, cKey, nDefault, cEnvName )
   LOCAL cValue := HBNumTestConfigGetText( cSection, cKey, "", cEnvName )
   LOCAL nValue

   IF Empty( cValue )
      RETURN nDefault
   ENDIF

   nValue := Int( Val( cValue ) )
   IF nValue < 0
      RETURN nDefault
   ENDIF

RETURN nValue

FUNCTION HBNumTestConfigGetLogical( cSection, cKey, lDefault, cEnvName )
   LOCAL cValue := Upper( HBNumTestConfigGetText( cSection, cKey, "", cEnvName ) )

   IF Empty( cValue )
      RETURN lDefault
   ENDIF

   IF cValue == "1" .OR. cValue == "TRUE" .OR. cValue == "YES" .OR. ;
      cValue == "ON" .OR. cValue == ".T."
      RETURN .T.
   ENDIF

   IF cValue == "0" .OR. cValue == "FALSE" .OR. cValue == "NO" .OR. ;
      cValue == "OFF" .OR. cValue == ".F."
      RETURN .F.
   ENDIF

RETURN lDefault

FUNCTION HBNumTestConfigListHas( cList, cNeedle )
   LOCAL cNormList := Upper( AllTrim( cList ) )
   LOCAL cNormNeedle := Upper( AllTrim( cNeedle ) )

   IF Empty( cNormList )
      RETURN .T.
   ENDIF

   cNormList := StrTran( cNormList, " ", "" )
   cNormList := StrTran( cNormList, Chr( 9 ), "" )
   cNormList := StrTran( cNormList, ";", "," )
   cNormList := StrTran( cNormList, "|", "," )

RETURN "," + cNormNeedle + "," $ "," + cNormList + ","

STATIC FUNCTION __HBNumTestConfigUnquote( cValue )
   IF Len( cValue ) >= 2
      IF ( Left( cValue, 1 ) == '"' .AND. Right( cValue, 1 ) == '"' ) .OR. ;
         ( Left( cValue, 1 ) == "'" .AND. Right( cValue, 1 ) == "'" )
         RETURN SubStr( cValue, 2, Len( cValue ) - 2 )
      ENDIF
   ENDIF

RETURN cValue
