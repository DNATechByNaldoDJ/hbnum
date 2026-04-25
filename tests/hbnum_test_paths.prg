/*
hbnum: Released to Public Domain.
*/
REQUEST hb_DirExists
REQUEST hb_DirCreate

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
