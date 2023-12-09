%***************************************************************************;
%* Antengene                                                                ;
%*Project Name/No.   ATG-010-MM-002                                            ;
%*Purpose:           Create ADAE (Adverse Events) dataset                    ;
%*Original Author (Date): Karen Chen (2/23/2022)                           ;
%*Type of Program:                                                          ;
%*Program Source:                                                           ;
%***************************************************************************;
 
%* -------------------------------------------------------;
%* ---------- Generate ADAE (Adverse Events) data set ----------;
%* --------------------------------------------------------;
%* --------------------------------------------------------;
%let homedir=%sysget(OneDrive);
%let projdir =&homedir\Biometrics\ATG-010\ATG-010-MM-002\Programming;

%inc "&projdir\Programs\Utilities\Macros\init.sas";
****** Clean up log, output and work library datasets;

dm "log;clear";
dm "output;clear";
proc datasets lib=work nolist memtype=data kill; quit;

%cnddtm(indir="&projdir\dataset\sdtm\&loc",
      memname=where memname in ('AE'),
      outdir=work);

  %let ae = ae;
 
  
data suppae;
   set s.suppae;
run;
data ae;
   set &ae;
run;
%suppqual(domain=ae, outds=ae);

data adsl;
   set a.adsl;
   keep usubjid tr01sdt tr01edt;
run;

%* Imputed partial date in order to generate TEAE flag in SDTM;
%cimpdt(domain=AE,
        inds=ae,
        adsl=adsl,
        startdt=tr01sdt,
        enddt =tr01edt,
        outds=ae01,
        cleanup=YES);

data adae01;
   length astdtf aendtf $1 ; 
   set ae01;
   astdt = aesdt;

   astdtf = aesdtf;
   aendt = aeedt;
   aendtf = AEEDTF;
   format astdt aendt date9.;

   drop aesdt aesdtf aeedt AEEDTF /*tr01sdt tr01edt*/; 
run;


data adae02;
   length  prefl trtemfl aetrtem aeacnaj aeacnvaj aeacndaj aaeacnaj aeacnrd aeacnbrd aeacndrd aaeacnrd aeacnhd aeacnbhd aeacndhd aaeacnhd aeacnwd aeacnbwd aeacndwd AEDCTRFL $3 
           AERELBOR AERELDEX  aaerel $10 AEACNBOR AEACNDEX aacn $100 AEADDTC AEDISDTC $20;

   set adae01 (rename=(aetrtem=_aeterem   AERELBOR=_AERELBOR AERELDEX= _AERELDEX AEACNBOR=_AEACNBOR AEACNDEX=_AEACNDEX
               AEDISDTC=_AEDISDTC aeaddtc=_aeaddtc)) ;

   if nmiss(astdt, tr01sdt) = 0 then astdy = astdt - tr01sdt + (astdt >= tr01sdt);
   if nmiss(aendt, tr01sdt) = 0 then aendy = aendt - tr01sdt + (aendt >= tr01sdt);
   aedur = aeendt - aestdt + 1;
   adurn = aendt - astdt + 1;
   aetoxgrn = input(aetoxgr, 1.);
   atoxgr = aetoxgr;
   atoxgrn = aetoxgrn;
   if . < aestdt < tr01sdt then prefl ='是';
   else prefl=' ';


   %* Create a few flags;
   
   aetrtem=_aeterem;
   if aetrtem='是' then trtemfl='是';
   else trtemfl=' ';


   AERELBOR=_AERELBOR;
   AERELDEX= _AERELDEX; 
   AEACNBOR=_AEACNBOR; 
   AEACNDEX=_AEACNDEX;
   if aeacn in ('减少剂量', '增加剂量', '暂停用药') then aeacnaj='是';
   if AEACNBOR in ('减少剂量', '增加剂量', '暂停用药') then aeacnbaj='是';
   if AEACNDEX in ('减少剂量', '增加剂量', '暂停用药') then aeacndaj='是';

   if aeacnaj ='是' or aeacnbaj ='是' or aeacndaj='是' then aaeacnaj ='是';

   if aeacn in ('减少剂量') then aeacnrd='是';
   if AEACNBOR in ('减少剂量') then aeacnbrd='是';
   if AEACNDEX in ('减少剂量') then aeacndrd='是';

   if aeacnrd ='是' or aeacnbrd ='是' or aeacndrd='是' then aaeacnrd ='是';

    if aeacn in ('暂停用药') then aeacnhd='是';
   if AEACNBOR in ('暂停用药') then aeacnbhd='是';
   if AEACNDEX in ('暂停用药') then aeacndhd='是';

   if aeacnhd ='是' or aeacnbhd ='是' or aeacndhd='是' then aaeacnhd ='是';

    if aeacn in ('永久停药') then aeacnwd ='是';
    if aeacnbox ='永久停药' then aeacnbwd ='是';
    if aeacndex ='永久停药' then aeacndwd ='是';

    if aeacnwd ='是' or aeacnbwd ='是' or aeacndwd ='是' then AEDCTRFL='是';
   if aerel ='有关' or aerelbor ='有关' or aereldex ='有关' then aaerel ='有关';

   aeaddtc=_aeaddtc;
	AEDISDTC=_AEDISDTC;
	
	
	
   drop  aestdt aeendt tr01sdt tr01edt _:; 
run;

/*  */
/**/
/*%* Add cycle information into ADAE dataset;*/
/**/
/*proc sort data=a.adex out=adex01(keep=usubjid acycsdt acycedt acycle acyclen) ;*/
/*   by usubjid acyclen acycsdt acycedt;*/
/*   where acycsdt ne .;*/
/*run;*/
/**/
/*data adex02;*/
/*   set adex01;*/
/*   by usubjid acyclen acycsdt acycedt;*/
/*   if last.acyclen;*/
/*run;*/
/**/
/*proc sort data=adae02c out=adae02d(keep=usubjid astdt)  nodupkey;*/
/*    by usubjid astdt;*/
/*	where astdt ne .;*/
/*run;*/
/**/
/*proc sql;*/
/*      create table adae02e as*/
/*      select adae02d.usubjid, astdt,acycsdt, acycedt, acycle, acyclen*/
/*      from adae02d left join adex02*/
/*      on adae02d.usubjid=adex02.usubjid and (astdt >.z and acycsdt<=astdt<=acycedt)*/
/*      order by usubjid, astdt;*/
/*    quit;*/
/*run;*/
/**/
/*proc sort data=adae02c;*/
/*   by usubjid astdt;*/
/*run;*/
/**/
/*data adae03 ck01 ck02;*/
/*   merge adae02c(in=a) adae02e (in=b);*/
/*   by usubjid astdt;*/
/*   if a then output adae03;*/
/*   if a and not b then output ck01;*/
/*   if not a and b then output ck02;*/
/*run;*/
/**/
/*data adae03;*/
/*   set adae03;*/
/*   length awndw $40.;*/
/*   AWNDW = acycle ;*/
/*   AWNDWN = acyclen;  */
/*   if . < astdt < trtsdt and astdy < 0 then do;*/
/*       awndw= 'SCREENING';*/
/*	   AWNDWN=-1;*/
/*   end;*/
/*   else if astdt > tr01edt > . and acyclen = . then do;*/
/*       awndw = 'POST TREATMENT';*/
/*	   AWNDWN = 99;*/
/*   end;*/
/*   if aeser ='N' then aeser='N';*/
/*    format aendt acycsdt acycedt date9.;*/
   /*drop acycle acyclen ACYCSDT ACYCEDT; */
/*run;*/


proc sort data=adae02;
   by usubjid aeseq aeterm;
run;

proc sort data=a.adsl out=adsl(keep=&corevars trt01p trt01pn trt01a trt01an);
   by usubjid;
run;

data adae;
   merge adae02(in=a) adsl;
   by usubjid;
   if a;
   length trtp trta $40;
 
   trtp=trt01p;
   trtpn=trt01pn;
   trta = trt01a;
   trtan = trt01an;
   drop trt01p trt01pn trt01a trt01an;
run;

 %* Add Standard attributes;
   
	%m_adam_apply_attribute(
	    inds     = adae,                     /*Input data set name that needs to be preocessed(Required)                            */
        inattrib = msdtm.metadata_adam_cn,  /*ADaM metadata set name (Required)                                                    */
        sortby   = usubjid aeseq,                     /*list of variables seperated by space(Optional)                                       */
        seqvar   = ,                     /*Analysis sequence variable name used for sorting (Optional)                          */
        memname  = ADAE,                     /*Name of the data set or domain to be processed(Ex:adsl,ADQS etc)(Required)           */
        outds    = a.adae);
 
