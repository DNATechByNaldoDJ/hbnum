/*
hbnum: Released to Public Domain.
--------------------------------------------------------------------------------------
*/

#include "tBigNumber.ch"

static s_cLog := ""

static procedure AddLog( cLine )
   s_cLog += cLine + Chr( 13 ) + Chr( 10 )
return

static function Expect( cLabel, uGot, uWant )
   local lOk := hb_ValToExp( uGot ) == hb_ValToExp( uWant )
   local cLine := iif( lOk, "PASS", "FAIL" ) + " " + cLabel + " " + hb_ValToExp( uGot ) + " " + hb_ValToExp( uWant )

   AddLog( cLine )

   return lOk

procedure Main()
   local lOk := .T.
   local o
   local a

   o := tBigNumber():New( "123.45" )
   a := o:SplitNumber()

   lOk := Expect( "split-int-1", a[ 1 ][ 1 ], "100" ) .and. lOk
   lOk := Expect( "split-int-2", a[ 1 ][ 2 ], "20" ) .and. lOk
   lOk := Expect( "split-int-3", a[ 1 ][ 3 ], "3" ) .and. lOk
   lOk := Expect( "split-dec-1", a[ 2 ][ 1 ], "40" ) .and. lOk
   lOk := Expect( "split-dec-2", a[ 2 ][ 2 ], "5" ) .and. lOk

   o := tBigNumber():New( "10", 2 )
   lOk := Expect( "new-base-valid", o:__nBase(), 2 ) .and. lOk

   o := tBigNumber():New( "10", 99 )
   lOk := Expect( "new-base-normalized", o:__nBase(), 10 ) .and. lOk

   o := tBigNumber():New( "10", 2 )
   o:SetValue( "10", 99 )
   lOk := Expect( "setvalue-base-normalized", o:__nBase(), 10 ) .and. lOk

   lOk := Expect( "lcm-zero-zero", tBigNumber():New( "0" ):LCM( "0" ):ExactValue(), "0" ) .and. lOk
   lOk := Expect( "lcm-zero-big", tBigNumber():New( "0" ):LCM( "1234567890123456789012345678901234567890" ):ExactValue(), "0" ) .and. lOk
   lOk := Expect( "lcm-negative-small", tBigNumber():New( "-21" ):LCM( "6" ):ExactValue(), "42" ) .and. lOk
   lOk := Expect( "lcm-negative-large", tBigNumber():New( "-100000000000000000000" ):LCM( "25000000000000000000" ):ExactValue(), "100000000000000000000" ) .and. lOk

   lOk := Expect( "gcd-negative-small", tBigNumber():New( "-48" ):GCD( "18" ):ExactValue(), "6" ) .and. lOk
   lOk := Expect( "gcd-zero-negative", tBigNumber():New( "0" ):GCD( "-18" ):ExactValue(), "18" ) .and. lOk
   lOk := Expect( "gcd-negative-large", tBigNumber():New( "-100000000000000000000" ):GCD( "25000000000000000000" ):ExactValue(), "25000000000000000000" ) .and. lOk
   lOk := Expect( "gcd-order-small", tBigNumber():New( "18" ):GCD( "48" ):ExactValue(), "6" ) .and. lOk
   lOk := Expect( "gcd-coprime-small", tBigNumber():New( "35" ):GCD( "64" ):ExactValue(), "1" ) .and. lOk
   lOk := Expect( "gcd-order-large", tBigNumber():New( "25000000000000000000" ):GCD( "100000000000000000000" ):ExactValue(), "25000000000000000000" ) .and. lOk

   lOk := Expect( "div-large-exact", tBigNumber():New( "100000000000000000000" ):Div( "25000000000000000000", .F. ):ExactValue(), "4" ) .and. lOk
   lOk := Expect( "sqrt-pow10-200", tBigNumber():New( "100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" ):SQRT():ExactValue(), "10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" ) .and. lOk

   o := tBigNumber():New( "1000000000000000000000000000000" )
   o:SetDecimals( 50 )
   o:nthRootAcc( 50 )
   o:SysSQRT( 0 )
   lOk := Expect( "ln-pow10-30", o:Ln():NoRnd( 12 ):ExactValue( .F., .F. ), "69.077552789821" ) .and. lOk

   o := tBigNumber():New( "100000000000000000000000000000000000000000000000000000000000000000000000000000000" )
   o:SetDecimals( 50 )
   o:nthRootAcc( 50 )
   o:SysSQRT( 0 )
   lOk := Expect( "ln-pow10-80", o:Ln():NoRnd( 12 ):ExactValue( .F., .F. ), "184.206807439523" ) .and. lOk

   o := tBigNumber():New( "1" )
   o:SetDecimals( 50 )
   o:nthRootAcc( 50 )
   o:SysSQRT( 0 )
   lOk := Expect( "exp-one", o:Exp():NoRnd( 12 ):ExactValue( .F., .F. ), "2.718281828459" ) .and. lOk

   AddLog( iif( lOk, "SMOKE PASS", "SMOKE FAIL" ) )
   MemoWrit( HBNumTestArtifactPath( "tbig_smoke.log" ), s_cLog )
   ErrorLevel( iif( lOk, 0, 1 ) )

return
