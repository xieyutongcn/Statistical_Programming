%******************************************************************************;
%* Antengene                                                                   ;
%*Project Name/No.   ATG-017-001                                               ;
%*Purpose:           Create ADSL (Subject Level) dataset                       ;
%*Original Author (Date): Karen Chen (12/08/2020)                              ;
%*Type of Program:                                                             ;
%*Program Source:   s.dm s.ds s.ex r.dd s.ie s.qs                              ;
%*version history:  Tao Wang 12Jan2022   take over program from Karen          ;
%*version history:  Tao Wang 25Apr2022   derived DLTFL,DLTPOPFL                ;
%******************************************************************************;
options notes nosource;
proc datasets lib=work nolist memtype=data kill; quit;
dm "log;clear";
dm "output;clear";
%let homedir=%sysget(OneDrive);
%let projdir =&homedir\Biometrics\ATG-017\ATG-017-001\Programming;
%inc "&projdir.\Programs\Utilities\macros\init_Clinsum_21Mar2022.sas";
%cnddtm(indir="&projdir.\Datasets\SDTM\&loc",
      memname=where memname in ('DM', 'EX', 'DS',  'MH', 'FA',
                                'QS', 'AE', 'VS', 'LB', 'EG', 'CV', 'CM', 'DD'),
      outdir=work);

  %let dm = dm;
  %let ds = ds;
  %let ex = ex;
  %let ae = ae;
  %let mh = mh;
  %let qs = qs;
  %let vs = vs;
  %let lb = lb;
  %let fa = fa;
  %let eg = eg;
  %let cv = cv;
  %let cm = cm;
  %let vs = vs;
  %let qs = qs;

data suppdm;
   set s.suppdm;
run;

data dm;
  set &dm;
run;
%suppqual(domain=dm, outds=dm);

data suppds;
   set s.suppds;
run;
data ds;
   set &ds;
run;
%suppqual(domain=ds, outds=ds);

data suppex;
   set s.suppex;
run;

%suppqual(domain=ex, outds=ex);

data _ex;
	set ex;
	if exendtc>"&cutoffdate" then exendtc="&cutoffdate";
	if EXDOSFRQ="QD" then freq=1;
	else if EXDOSFRQ="BID" then freq=2;
	if cmiss(exstdtc,exendtc)=0 then DOSDURD=input(exendtc,e8601da.)-input(exstdtc,e8601da.)+1;
	if nmiss(exdose,freq,DOSDURD)=0 then exdose=exdose*freq*DOSDURD;
	proc sort;
	by usubjid;
run;

data _ex;
	merge _ex(in=a) dm(keep=usubjid cohort);
	by usubjid;
	if a;
run;

proc sql noprint;
	create table _ex_1 as select distinct usubjid,cohort,sum(exdose) as adose from _ex where CYCLE="Cycle 1" group by usubjid;
quit;

data ex_1;
	set _ex_1;
/* Treatment Compliance in First Cycle(%) = Actual cumulative dose/ Planned cumulative dose. */
	if not missing(cohort) then cohortn=input(compress(cohort,"","kd"),best.);
	if index(cohort,"QD") then do;
		pdose_=cohortn*21;
	end;
	else if index(cohort,"BID") then do;
		pdose_=cohortn*1+cohortn*2*20;
	end;
	aval=adose/pdose_*100;
	if aval>75;
run;

%let dm =dm;
%let ds = ds;

  proc sort data=&dm out=popdef01;
     by usubjid;
  run;

  %* Get the first exposure date;
  
  proc sort data=&ex out=ex01;
     by usubjid exstdt exendt;
     where exdose > 0;
  run;

  data popdef02;
     set ex01;
     by usubjid exstdt;
     if first.usubjid;
     keep usubjid exstdt;
  run;


/*proc sort data=s.dm(where=(not missing(rfstdtc))) out=_dm;*/
/*	by rficdtc;*/
/*run;*/
/**/
/*data _null_;*/
/*	set _dm end=eof;*/
/*	if eof then call symputx("lstsubj",USUBJID);*/
/*run;*/
/**/
/*%put &lstsubj.;*/
/**/
/*proc sort data=s.ex(where=(not missing(exdose) and not missing(exendtc) and usubjid="&lstsubj.")) out=lstsub;*/
/*by exendtc;*/
/*run;*/
/**/
/*data _null_;*/
/*	set lstsub end=eof;*/
/*	exendt=input(exendtc,e8601da.);*/
/*	if eof then call symputx("lstendt",exendt);*/
/*run;*/
/**/
/*%put &lstendt.;*/

/*data exendt;*/
/*	set ex01;*/
/*    by usubjid exstdt exendt;*/
/*	if last.usubjid;*/
/*	if missing(exendt) then exendt=&lstendt.;*/
/*	rename exendt=_exendt;*/
/*	keep usubjid exendt;*/
/*run;*/
	
%* Get the last dose date;

  data dosedt01;
     set ex01;
     by usubjid exstdt exendt;
     if last.usubjid then do; 
       lstdt = exendt;
       output; 
     end;
     format lstdt date9.;
     keep usubjid exstdt lstdt cycle;
   run;

   data dosedt01a;
      set dosedt01;
      if lstdt = . and exstdt ne . then lstdt = exstdt;
      keep usubjid lstdt;
   run;

   proc sort data=ex01 out=ex03;
      by usubjid cycle;
   run;

   data ex04;
      merge ex03 dosedt01(in=a keep=usubjid cycle);
      by usubjid cycle;
      if a;
    run; 

   
	 proc sort data=ex04;
	    by usubjid cycle exstdt;
	 run;   

     data ex05(rename= (exendt=trtpedt));
        retain fstdt;
        set ex04;
        by usubjid cycle exstdt;
        if first.usubjid then do;
		   fstdt = exstdt;
		end;
          
        if last.usubjid then do; 
           if exendt=. or (exendt>. and exendt-fstdt+1<21) then exendt=fstdt+20;
           output; 
        end;
        keep usubjid exendt;
      run;
       
	  %*Bring inform consent date;
      proc sort data=&ds out=popdef03(keep=usubjid dsstdt studyver rename=(dsstdt=RFICDT));
          where dsdecod='INFORMED CONSENT OBTAINED';
          by usubjid;
      run;

        %* Bring discontinuate date and resons for Treatment;
	   proc sort data=&ds out=popdef04(keep=usubjid dsstdt dsdecod dsterm );
	      where dscat = 'DISPOSITION EVENT' and dsscat ='END OF TREATMENT';
          by usubjid dsstdt;
	   run;

	   %* Screening status;
	     proc sort data=&ds out=popdef04a(keep = usubjid dsdecod dsterm OTHSPCFY rename=(dsdecod=srndsdecod dsterm=srndsterm));
		    where dscat = 'OTHER EVENT'  and dsterm ='SUBJECTS DID NOT MEET ELIGIBILITY CRITERIA';
			by usubjid;
		run;

       %* Bring discontinuate date and resons for end of study;
	   proc sort data=&ds out=popdef05(keep=usubjid dsstdt dsdecod dsterm rename=(dsstdt=eos_dsstdt dsdecod=eos_dsdecod dsterm=eos_dsterm) );
	      where dscat = 'DISPOSITION EVENT' and dsscat ='END OF STUDY';
          by usubjid dsstdt;
	   run;
	   %* bring ie;
	    proc sort data=s.ie out=ie(keep=usubjid ietest);
		    by usubjid;
		run;

		data ie01;
		   set ie;
		   by usubjid;
		   if first.usubjid;
		run;

		data dlt;
		   set qs;
		   if qstestcd ='DLT' and QSSTRESC="YES";
		   dltfl ="Y";
		   keep usubjid dltfl;
		run;

		proc sort data=dd(where=(DDTESTCD="PRCDTH")) out=dd1;
			by usubjid;
		run;

		data popdef(rename=(ncohort=cohort));
          merge popdef01 (in=in1)   /*demog*/
                popdef02 (in=in2)   /*First dose date*/
				popdef03 (in=in3)   /*Inform consent date*/
                dosedt01a           /*last dose date*/
				ex05               /*end date of medicatoin */
				popdef04 (in=in4)   /*End of treatment*/
                popdef04a (in=in5)  /* End of screening */
				popdef05  (in=in6)  /* End of study */
				ie01 (in=inie)
				dlt
				dd1
               ;
		   by usubjid; 
        %* Define all randomized subjects, safety analysis set and itt analysis set;
          if in1; 
		  
		%* Define informed content population;
		 RFIFL = 'N';
		 if in3 then rfifl='Y';
		 %* Define Safety Population;
		  saffl='N';
          if in2 then saffl='Y';

          eligfl ='Y';
		  if inie then eligFL ='N';

        %* Define treatment discontinus reasons; 
          length dctreas dctreasp DCSREAS DCSREASP $200 eotstt eosstt $15 scnreas $100 scnreasp $200 PROTVERS $5 ncohort $80;
		  if in4 then do;
		     eotstt ='DISCONTINUED';
             eotdt =  dsstdt;
             dctreas = dsdecod;
             if dsdecod =:'OTHER' then dctreasp =  strip(dsterm);
          end;
    
		%* Define end of screening;
         if in5 then do;
		    scnreas = srndsdecod;
			if srndsdecod = 'OTHER' then scnreasp = OTHSPCFY  ;
		 end;

	 %* Define end of study status;
		 if in6 then do;
		    eosstt ='DISCONTINUED';
			eosdt = eos_dsstdt;
            DCSREAS = eos_dsdecod;
			if DCSREAS =:'OTHER' then DCSREASP = eos_dsterm;
         end;

	  %* Trial dates;
/*		 tr01sdt = exstdt;*/
/*		 tr01edt = lstdt;*/
		 trtsdt = exstdt;
		 if not missing(rfxendtc) then trtedt=input(rfxendtc,e8601da.);
/*		 if trtpedt ne .   and (dthdt ^= . and eotdt ^= .) then trtedt = min(dthdt, min(trtpedt, eotdt));*/
/*         else if trtpedt ne . and dthdt = . and eotdt ^= . then trtedt = min(trtpedt, eotdt); */
/*         else trtedt = trtpedt;*/
/*		 trtedt=_exendt;*/
		 tr01sdt = trtsdt;
		 tr01edt = trtedt;		 
        %* Overall Treatment Duration;
         if nmiss(trtedt,trtsdt)=0 then TOTDURN = (trtedt - trtsdt + 1);
		 format trtedt trtsdt tr01sdt tr01edt rficdt date9.;
		 ncohort = cohort;
		 if cohort ne ' '  then do;
            trt01p ='ATG-017';
		    trt01pn=1;
		 end;
		
		 if cohort = '5 MG QD' then cohortn=1;
		 else if cohort ='5 MG BID' then cohortn=2;
		 else if cohort ='10 MG BID' then cohortn = 3;
		 else if cohort ='20 MG BID' then cohortn = 4;
		 else if cohort ='40 MG BID' then cohortn = 5;
/*         if cohort ='SCREEN FAILURE' then cohort = ' ';*/
		 trt01a = trt01p;
		 trt01an = trt01pn;
/*		 if scnreas = 'SCREEN FAILURE' then scnreasp = strip(ietest);*/
		 PROTVERS = studyver;
		 DTHCAUS=strip(DDORRES);
         drop dsstdt dsdecod dsterm srndsdecod srndsterm  studyver cohort;
      run;

	  %* Add last contact date;
    proc sql;
          create table dsurvi01 as
            select usubjid,
                   max(dsstdt) as max1_d format date9. label='Treatment Termination Date'
            from   &ds
            where dscat='DISPOSITION EVENT' and dsdecod not in ( 'SURVIVAL STATUS')
            group  by usubjid;
          create table dsurvi02 as
            select usubjid,
                   max(aestdt) as max2_d format date9. label='AE Start Date'
/*                   max(aeendt) as max3_d format date9. label='AE End Date'*/
            from   &ae
            group  by usubjid;

          create table dsurvi04 as
            select usubjid,
                   max(exstdt) as max5_d format date9. label='TRT Start Date',
                   max(exendt) as max6_d format date9.   label='TRT End Date'
            from &ex
            group by usubjid;
	
          create table dsurvi05 as
            select usubjid,
                   max(lbdt) as max7_d format date9. label='Last Sample Date'
            from &lb
            group by usubjid;
/*          create table dsurvi06 as*/
/*            select usubjid,*/
/*                   max(brdt) as max8_d format date9. label='Last Bone Marrow Assess. Date'*/
/*            from &br*/
/*            where brdt ne .  and brcat in ('BONE MARROW BIOPSY', 'BONE MARROW ASPIRATE')*/
/*            group by usubjid;*/
/*          create table dsurvi07 as*/
/*            select usubjid,*/
/*                   max(trdt) as max9_d format date9. label='Last Plasma Assess. Date'*/
/*            from &tr*/
/*            where trdt ne .*/
/*            group by usubjid;*/
/*         */
/*          create table dsurvi08 as*/
/*            select usubjid,*/
/*                   max(brdt) as max10_d format date9. label='Last Cytoma Assess. Date'*/
/*            from &br*/
/*            where brdt ne . and brcat in ('CYTOGENETICS')*/
/*            group by usubjid;*/
/*          */
		     create table dsurvi09 as
		        select usubjid,
			      max(vsdt) as max11_d format date9. label = 'Last Vital Sign visit date'
			      from &vs
			      where vsdt ne .
			      group by usubjid;
		     create table dsurvi10 as
		        select usubjid,
			      max(egdt) as max12_d format date9. label = 'Last EG visit date'
			      from &eg
			      where egdt ne .
			      group by usubjid;
             create table dsurvi11 as
		        select usubjid,
			      max(qsdt) as max13_d format date9. label = 'Last QS visit date'
			      from &qs
			      where qsdt ne . and qscat='ECOG Performance Status'
			      group by usubjid;

		 create table dsurvi12 as
		        select usubjid,
			      max(cmstdt) as max14_d format date9. label = 'Last CM Start visit date',
				    max(cmendt) as max15_d format date9. label = 'Last CM End visit date'
			      from &cm
			      where cmstdt ne . or cmendt ne .
			      group usubjid;
      
/*		 create table dsurvi13 as*/
/*		        select usubjid,*/
/*			      max(rsdt) as max16_d format date9. label = 'Last RS visit date'*/
/*			      from &rs*/
/*			      where rsdt ne . */
/*			      group usubjid;*/
/*          create table dsurvi14 as*/
/*		        select usubjid,*/
/*			      max(tudt) as max17_d format date9. label = 'Last TU visit date'*/
/*			      from &tu*/
/*			      where tudt ne . */
/*			      group usubjid;*/
         create table dsurvi15 as
            select usubjid,
                   max(dsstdt) as max18_d format date9. label='Follow-up Date'
            from   &ds
            where dsstdt ne . and dsdecod ne 'DEATH' and dscat='OTHER EVENT'
            group  by usubjid;

/*		  create table dsurvi16 as*/
/*            select usubjid,*/
/*                   max(HOSTDT) as max19_d format date9. label='Hospital Start Date',*/
/*				   max(HOENDT) as max20_d format date9. label='Hospital End Date'*/
/*            from   &ho*/
/*            where hostdt ne . or hoendt ne .*/
/*            group  by usubjid;*/
/**/
/*		*/
/*		create table dsurvi17 as*/
/*            select usubjid,*/
/*                   max(xpstdt) as max21_d format date9. label='Concomitant Procedure Date'*/
/*            from   &xp*/
/*            where xpstdt ne . */
/*            group  by usubjid;*/
      quit;

  
	   %macro sortit(ind=,maxvar=,outind=);
          proc sort data=&ind; by usubjid &maxvar;
             data &outind;
             set &ind;
             by usubjid &maxvar;
             if last.usubjid;
          run;
      %mend;
      %sortit(ind=dsurvi01,maxvar=max1_d,outind=dsurvi01);
      %sortit(ind=dsurvi02,maxvar=max2_d,outind=dsurv02a);
    /*  %sortit(ind=dsurvi02,maxvar=max3_d,outind=dsurv02b);*/
/*      %sortit(ind=dsurvi03,maxvar=max4_d,outind=dsurvi03);*/
      %sortit(ind=dsurvi04,maxvar=max5_d,outind=dsurv04a);
      %sortit(ind=dsurvi04,maxvar=max6_d,outind=dsurv04b);
      %sortit(ind=dsurvi05,maxvar=max7_d,outind=dsurvi05);
/*      %sortit(ind=dsurvi06,maxvar=max8_d,outind=dsurvi06);*/
/*      %sortit(ind=dsurvi07,maxvar=max9_d,outind=dsurvi07);*/
/*      %sortit(ind=dsurvi08,maxvar=max10_d,outind=dsurv08a);*/
      %sortit(ind=dsurvi09,maxvar=max11_d,outind=dsurv08b);
      %sortit(ind=dsurvi10,maxvar=max12_d,outind=dsurvi09);
      %sortit(ind=dsurvi11,maxvar=max13_d,outind=dsurvi10);
	  %sortit(ind=dsurvi12,maxvar=max14_d,outind=dsurv11a);
	  %sortit(ind=dsurvi12,maxvar=max15_d,outind=dsurv11b);
/*	  %sortit(ind=dsurvi13,maxvar=max16_d,outind=dsurv12);*/
/*      %sortit(ind=dsurvi14,maxvar=max17_d,outind=dsurv13);*/
      %sortit(ind=dsurvi15,maxvar=max18_d,outind=dsurv14);
/*      %sortit(ind=dsurvi16,maxvar=max19_d,outind=dsurv15);*/
/*      %sortit(ind=dsurvi16,maxvar=max20_d,outind=dsurv16);*/
/*      %sortit(ind=dsurvi17,maxvar=max21_d,outind=dsurv17);*/


      data dsurv (keep=usubjid LSTALVDT);
         merge dsurvi01 dsurv02a /*dsurv02b dsurvi03*/ dsurv04a dsurv04b dsurvi05 /*dsurvi06 dsurvi07 dsurv08a*/ dsurv08b
               dsurvi09 dsurvi10 dsurv11a dsurv11b /*dsurv12 dsurv13 */ dsurv14 /*dsurv15 dsurv16 dsurv17*/;
         by usubjid;
         attrib LSTALVDT label='Date Last Known Alive' format=date9.;
         %* This code will be reomved after data is clean;
         LSTALVDT=max(max1_d, max2_d, /*max3_d, max4_d ,*/  max5_d, max6_d, max7_d/*, max8_d,max9_d,max10_d*/,max11_d, max12_d,
                      max13_d, max14_d, max15_d/*, max16_d, max17_d*/, max18_d/*, max19_d, max20_d, max21_d*/);

      run;

   proc sql noprint;
      select distinct quote(strip(usubjid)) into : basetr separated by "," from s.tr where trblfl="Y";
      select distinct quote(strip(usubjid)) into : pbasers separated by "," from s.rs where rstestcd="OVRLRESP";
      select distinct quote(strip(usubjid)) into : pksubj separated by "," from s.pc where not missing(pcorres);
      select distinct quote(strip(usubjid)) into : dltsubj separated by "," from ex_1;
      select distinct quote(strip(usubjid)) into : pdsubj separated by "," from s.pd where not missing(pdorres);
   quit;

   data adsl;
      length agegr1 $11;
      merge popdef(in=a) dsurv;
      by usubjid;
      if a;
	   %* Create age group variable;
	  if . < age < 70 then agegr1 = '< 70 years';
	  else if age >= 70 then agegr1 = '>= 70 years';
	  format eotdt date9.;
	  if CHILDYN in ('N', ' ') then CHLDBEFL='';
      else if childyn ='Y' then chldbefl='Y';
	  format tr01sdt tr01edt date9.;
	  %* Calculate TRTEDY;
	  if nmiss(tr01edt,tr01sdt)=0 then trtedy = tr01edt - tr01sdt + 1;
	  if saffl='Y' and dctreas = ' ' then ontrtfl ='Y';
	  if saffl='Y' and dcsreas = ' ' then onstdyfl ='Y';
	  cutdtc="2022-03-21";
	  if not missing(cutdtc) and not missing(trtsdt) then do;
	      DURFU=(input(cutdtc,e8601da.)-trtsdt+1)/30.4375;
	  end;
	  if saffl="Y" then do;
	  	if usubjid in (&pksubj.) then PKFL="Y";
	  	if usubjid in (&basetr.) and usubjid in (&pbasers.) then efffl="Y";
		if usubjid in (&pdsubj.) then PDFL="Y";
	  end;
	  if efffl^="Y" then efffl="N";
	  if PKFL^="Y" then PKFL="N";
	  if PDFL^="Y" then PDFL="N";
	  if not missing(rfpendtc) then LSTALVDT=input(rfpendtc,e8601da.);
	  else LSTALVDT=.;
	  if LSTALVDT>&cutdate. then LSTALVDT=&cutdate.;
	  if not missing(dthdt) then LSTALVDT=dthdt-1;
	  if nmiss(DTHDT,TRTEDT)=0 then do;
		  if .<DTHDT<=TRTEDT+30 then DTH30FL="Y";
		  if DTHDT>TRTEDT+30>. then DTHA30FL="Y";
	  end;
	  if DLTFL="Y" or usubjid in (&dltsubj.) then DLTPOPFL="Y";
	  else DLTPOPFL="N";
	  format eosdt date9.;
	  drop domain rficdtc rfstdtc rfendtc RFXSTDTC RFXENDTC rfstdt RFXSTDT RFXENDT rfpendtc dmdtc;
   run; 
	  
	%m_adam_apply_attribute(
	    inds     = adsl,                     /*Input data set name that needs to be preocessed(Required)                            */
        inattrib = msdtm.metadata_adam,  /*ADaM metadata set name (Required)                                                    */
        sortby   = usubjid ,                     /*list of variables seperated by space(Optional)                                       */
        seqvar   = ,                     /*Analysis sequence variable name used for sorting (Optional)                          */
        memname  = ADSL,                     /*Name of the data set or domain to be processed(Ex:adsl,ADQS etc)(Required)           */
        outds    = a.adsl);
 
