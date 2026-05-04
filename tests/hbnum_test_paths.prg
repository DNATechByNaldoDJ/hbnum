/*
hbnum: Released to Public Domain.
*/
REQUEST hb_DirExists
REQUEST hb_DirCreate

FUNCTION HBNumTestRootDir()
   LOCAL cDir := hb_FNameDir( hb_ProgName() )
   LOCAL cSep := hb_ps()
   LOCAL cMarker := cSep + "exe" + cSep
   LOCAL nAt
   LOCAL nTailAt
   LOCAL cTail

   IF Empty( cDir )
      cDir := "."
   ENDIF

   IF Right( cDir, 1 ) == cSep
      cDir := Left( cDir, Len( cDir ) - 1 )
   ENDIF

   nAt := At( cMarker, cDir )
   IF nAt > 0
      cDir := Left( cDir, nAt - 1 )
   ELSE
      nTailAt := RAt( cSep, cDir )
      cTail := Lower( IIf( nTailAt > 0, SubStr( cDir, nTailAt + 1 ), cDir ) )
      IF nTailAt > 0 .AND. ( cTail == "tests" .OR. cTail == "mk" )
         cDir := Left( cDir, nTailAt - 1 )
      ENDIF
   ENDIF

RETURN cDir + cSep

FUNCTION HBNumTestLogDir()
   LOCAL cDir := hb_FNameDir( hb_ProgName() )
   LOCAL cSep := hb_ps()
   LOCAL cMarker := cSep + "exe" + cSep
   LOCAL nAt

   IF Empty( cDir )
      cDir := "."
   ENDIF

   IF Right( cDir, 1 ) == cSep
      cDir := Left( cDir, Len( cDir ) - 1 )
   ENDIF

   nAt := At( cMarker, cDir )
   IF nAt > 0
      cDir := Left( cDir, nAt - 1 ) + cSep + "log" + cSep + ;
         SubStr( cDir, nAt + Len( cMarker ) )
   ELSE
      cDir += cSep + "log"
   ENDIF

   __EnsureDir( cDir )

RETURN cDir + cSep

FUNCTION HBNumTestProjectPath( cPath )
   hb_default( @cPath, "" )
RETURN HBNumTestRootDir() + StrTran( cPath, "/", hb_ps() )

FUNCTION HBNumTestArtifactPath( cFileName )
   hb_default( @cFileName, "" )
RETURN HBNumTestLogDir() + cFileName

STATIC PROCEDURE __EnsureDir( cDir )
   LOCAL cSep := hb_ps()
   LOCAL nPos
   LOCAL cParent

   IF Empty( cDir )
      RETURN
   ENDIF

   IF Right( cDir, 1 ) == cSep
      cDir := Left( cDir, Len( cDir ) - 1 )
   ENDIF

   IF hb_DirExists( cDir )
      RETURN
   ENDIF

   nPos := Len( cDir )
   DO WHILE nPos > 0 .AND. SubStr( cDir, nPos, 1 ) != cSep
      nPos--
   ENDDO

   IF nPos > 0
      cParent := Left( cDir, nPos - 1 )
      IF Len( cParent ) > 2 .AND. ! hb_DirExists( cParent )
         __EnsureDir( cParent )
      ENDIF
   ENDIF

   IF ! hb_DirExists( cDir )
      hb_DirCreate( cDir )
   ENDIF
RETURN
