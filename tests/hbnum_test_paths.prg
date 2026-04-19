/*
hbnum: Released to Public Domain.
*/
REQUEST hb_DirExists
REQUEST hb_DirCreate

FUNCTION HBNumTestLogDir()
   LOCAL cDir := hb_FNameDir( hb_ProgName() )

   IF Empty( cDir )
      cDir := "."
   ENDIF

   IF Right( cDir, 1 ) == hb_ps()
      cDir := Left( cDir, Len( cDir ) - 1 )
   ENDIF

   cDir += hb_ps() + "log"

   IF ! hb_DirExists( cDir )
      hb_DirCreate( cDir )
   ENDIF

RETURN cDir + hb_ps()

FUNCTION HBNumTestArtifactPath( cFileName )
   hb_default( @cFileName, "" )
RETURN HBNumTestLogDir() + cFileName
