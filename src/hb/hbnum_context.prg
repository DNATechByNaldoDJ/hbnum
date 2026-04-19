/*
 _      _
| |__  | |__   _ __   _   _  _ __ ___
| '_ \ | '_ \ | '_ \ | | | || '_ ` _ \
| | | || |_) || | | || |_| || | | | | |
|_| |_||_.__/ |_| |_| \__,_||_| |_| |_|

hbnum: Released to Public Domain.
--------------------------------------------------------------------------------------

*/

#include "hbnum.ch"
#include "hbclass.ch"

STATIC s_oHBNumDefaultContext

CLASS HBNumContext

   DATA nPrecision INIT NIL
   DATA nRootPrecision INIT NIL
   DATA nLogPrecision INIT NIL

   METHOD New( nPrecision, nRootPrecision, nLogPrecision )
   METHOD Clone()
   METHOD SetPrecision( nPrecision )
   METHOD GetPrecision()
   METHOD SetRootPrecision( nPrecision )
   METHOD GetRootPrecision()
   METHOD SetLogPrecision( nPrecision )
   METHOD GetLogPrecision()

ENDCLASS


STATIC FUNCTION __HBNumNormalizePrecision( nPrecision, nDefault )

   IF nPrecision == NIL
      RETURN NIL
   ENDIF

   IF ! HB_ISNUMERIC( nPrecision )
      RETURN nDefault
   ENDIF

   IF nPrecision < 0
      RETURN 0
   ENDIF

RETURN Int( nPrecision )


METHOD New( nPrecision, nRootPrecision, nLogPrecision ) CLASS HBNumContext

   ::nPrecision := __HBNumNormalizePrecision( nPrecision, ::nPrecision )
   ::nRootPrecision := __HBNumNormalizePrecision( nRootPrecision, ::nRootPrecision )
   ::nLogPrecision := __HBNumNormalizePrecision( nLogPrecision, ::nLogPrecision )

RETURN Self


METHOD Clone() CLASS HBNumContext
RETURN HBNumContext():New( ::nPrecision, ::nRootPrecision, ::nLogPrecision )


METHOD SetPrecision( nPrecision ) CLASS HBNumContext

   ::nPrecision := __HBNumNormalizePrecision( nPrecision, ::nPrecision )

RETURN ::nPrecision


METHOD GetPrecision() CLASS HBNumContext
RETURN ::nPrecision


METHOD SetRootPrecision( nPrecision ) CLASS HBNumContext

   ::nRootPrecision := __HBNumNormalizePrecision( nPrecision, ::nRootPrecision )

RETURN ::nRootPrecision


METHOD GetRootPrecision() CLASS HBNumContext
RETURN ::nRootPrecision


METHOD SetLogPrecision( nPrecision ) CLASS HBNumContext

   ::nLogPrecision := __HBNumNormalizePrecision( nPrecision, ::nLogPrecision )

RETURN ::nLogPrecision


METHOD GetLogPrecision() CLASS HBNumContext
RETURN ::nLogPrecision


FUNCTION HBNumGetDefaultContext()

   IF s_oHBNumDefaultContext == NIL
      s_oHBNumDefaultContext := HBNumContext():New()
   ENDIF

RETURN s_oHBNumDefaultContext:Clone()


FUNCTION HBNumSetDefaultContext( oContext )

   IF HB_ISOBJECT( oContext ) .AND. oContext:ClassName() == "HBNUMCONTEXT"
      s_oHBNumDefaultContext := oContext:Clone()
   ELSE
      s_oHBNumDefaultContext := HBNumContext():New()
   ENDIF

RETURN s_oHBNumDefaultContext:Clone()


FUNCTION HBNumGetDefaultPrecision()

   IF s_oHBNumDefaultContext == NIL
      s_oHBNumDefaultContext := HBNumContext():New()
   ENDIF

RETURN s_oHBNumDefaultContext:GetPrecision()


FUNCTION HBNumSetDefaultPrecision( nPrecision )

   IF s_oHBNumDefaultContext == NIL
      s_oHBNumDefaultContext := HBNumContext():New()
   ENDIF

RETURN s_oHBNumDefaultContext:SetPrecision( nPrecision )


FUNCTION HBNumGetDefaultRootPrecision()

   IF s_oHBNumDefaultContext == NIL
      s_oHBNumDefaultContext := HBNumContext():New()
   ENDIF

RETURN s_oHBNumDefaultContext:GetRootPrecision()


FUNCTION HBNumSetDefaultRootPrecision( nPrecision )

   IF s_oHBNumDefaultContext == NIL
      s_oHBNumDefaultContext := HBNumContext():New()
   ENDIF

RETURN s_oHBNumDefaultContext:SetRootPrecision( nPrecision )


FUNCTION HBNumGetDefaultLogPrecision()

   IF s_oHBNumDefaultContext == NIL
      s_oHBNumDefaultContext := HBNumContext():New()
   ENDIF

RETURN s_oHBNumDefaultContext:GetLogPrecision()


FUNCTION HBNumSetDefaultLogPrecision( nPrecision )

   IF s_oHBNumDefaultContext == NIL
      s_oHBNumDefaultContext := HBNumContext():New()
   ENDIF

RETURN s_oHBNumDefaultContext:SetLogPrecision( nPrecision )
