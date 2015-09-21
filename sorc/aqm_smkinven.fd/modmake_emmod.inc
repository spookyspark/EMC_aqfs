# Version "@(#)$Id: modmake.inc,v 1.14 2004/06/28 14:16:20 cseppan Exp $ $Source: /afs/isis/depts/cep/emc/apps/archive/smoke/smoke/src/emmod/modmake.inc,v $ $Date: 2004/06/28 14:16:20 $ 
#
# Include file for making modules and doing needed copies, etc.
#
MD_OUT = $(MD_SRC)/$(EDSS_EXE)

MODSOURC = $(MD_OUT)/modsourc.o
MODMOBIL = $(MD_OUT)/modmobil.o
MODXREF  = $(MD_OUT)/modxref.o
MODTMPRL = $(MD_OUT)/modtmprl.o
MODSPRO  = $(MD_OUT)/modspro.o
MODLISTS = $(MD_OUT)/modlists.o
MODINFO  = $(MD_OUT)/modinfo.o
MODDAYHR = $(MD_OUT)/moddayhr.o
MODCNTRL = $(MD_OUT)/modcntrl.o
MODSURG  = $(MD_OUT)/modsurg.o
MODEMFAC = $(MD_OUT)/modemfac.o
MODSTCY  = $(MD_OUT)/modstcy.o
MODMERGE = $(MD_OUT)/modmerge.o
MODELEV  = $(MD_OUT)/modelev.o
MODMET   = $(MD_OUT)/modmet.o
MODBIOG  = $(MD_OUT)/modbiog.o
MODBEIS3 = $(MD_OUT)/modbeis3.o
MODREPRT = $(MD_OUT)/modreprt.o
MODREPBN = $(MD_OUT)/modrepbn.o
MODMBSET = $(MD_OUT)/modmbset.o
MODAR2PT = $(MD_OUT)/modar2pt.o

#
MODALL   = $(MODSOURC) $(MODMOBIL) $(MODXREF)  $(MODTMPRL) $(MODSPRO)  \
           $(MODCNTRL) $(MODLISTS) $(MODINFO)  $(MODDAYHR) \
           $(MODMERGE) $(MODSTCY)  $(MODSURG)  $(MODEMFAC) $(MODELEV)  \
           $(MODMET)   $(MODBIOG)  $(MODBEIS3) $(MODREPRT) $(MODREPBN) \
           $(MODMBSET) $(MODAR2PT)

MODINC = $(INC)/EMPRVT3.EXT $(INC)/EMSTRG3.EXT
#
# Module dependencies...
#
$(MODSOURC): $(MD_SRC)/modsourc.f $(MODINC)
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modsourc.mod ) ; then mv modsourc.mod $(MD_OUT) ; fi
	if ( test -f modsourc.M   ) ; then mv modsourc.M   $(MD_OUT) ; fi
	if ( test -f MODSOURC.mod ) ; then mv MODSOURC.mod $(MD_OUT) ; fi

$(MODMOBIL): $(MD_SRC)/modmobil.f $(MODINC)
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modmobil.mod ) ; then mv modmobil.mod $(MD_OUT) ; fi
	if ( test -f modmobil.M   ) ; then mv modmobil.M   $(MD_OUT) ; fi
	if ( test -f MODMOBIL.mod ) ; then mv MODMOBIL.mod $(MD_OUT) ; fi

$(MODXREF): $(MD_SRC)/modxref.f $(MODINC)
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modxref.mod ) ; then mv modxref.mod $(MD_OUT) ; fi
	if ( test -f modxref.M   ) ; then mv modxref.M   $(MD_OUT) ; fi
	if ( test -f MODXREF.mod ) ; then mv MODXREF.mod $(MD_OUT) ; fi

$(MODTMPRL):  $(MD_SRC)/modtmprl.f $(MODINC)
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modtmprl.mod ) ; then mv modtmprl.mod $(MD_OUT) ; fi
	if ( test -f modtmprl.M   ) ; then mv modtmprl.M   $(MD_OUT) ; fi
	if ( test -f MODTMPRL.mod ) ; then mv MODTMPRL.mod $(MD_OUT) ; fi

$(MODSPRO): $(MD_SRC)/modspro.f $(MODINC)
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modspro.mod ) ; then mv modspro.mod $(MD_OUT) ; fi
	if ( test -f modspro.M   ) ; then mv modspro.M   $(MD_OUT) ; fi
	if ( test -f MODSPRO.mod ) ; then mv MODSPRO.mod $(MD_OUT) ; fi

$(MODLISTS): $(MD_SRC)/modlists.f $(MODINC)
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modlists.mod ) ; then mv modlists.mod $(MD_OUT) ; fi
	if ( test -f modlists.M   ) ; then mv modlists.M   $(MD_OUT) ; fi
	if ( test -f MODLISTS.mod ) ; then mv MODLISTS.mod $(MD_OUT) ; fi

$(MODINFO): $(MD_SRC)/modinfo.f $(MODINC)
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modinfo.mod ) ; then mv modinfo.mod $(MD_OUT) ; fi
	if ( test -f modinfo.M   ) ; then mv modinfo.M   $(MD_OUT) ; fi
	if ( test -f MODINFO.mod ) ; then mv MODINFO.mod $(MD_OUT) ; fi

$(MODDAYHR): $(MD_SRC)/moddayhr.f $(MODINC)
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f moddayhr.mod ) ; then mv moddayhr.mod $(MD_OUT) ; fi
	if ( test -f moddayhr.M   ) ; then mv moddayhr.M   $(MD_OUT) ; fi
	if ( test -f MODDAYHR.mod ) ; then mv MODDAYHR.mod $(MD_OUT) ; fi

$(MODCNTRL): $(MD_SRC)/modcntrl.f $(MODINC)
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modcntrl.mod ) ; then mv modcntrl.mod $(MD_OUT) ; fi
	if ( test -f modcntrl.M   ) ; then mv modcntrl.M   $(MD_OUT) ; fi
	if ( test -f MODCNTRL.mod ) ; then mv MODCNTRL.mod $(MD_OUT) ; fi

$(MODSURG): $(MD_SRC)/modsurg.f
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modsurg.mod ) ; then mv modsurg.mod $(MD_OUT) ; fi
	if ( test -f modsurg.M   ) ; then mv modsurg.M   $(MD_OUT) ; fi
	if ( test -f MODSURG.mod ) ; then mv MODSURG.mod $(MD_OUT) ; fi

$(MODEMFAC): $(MD_SRC)/modemfac.f $(MODINC)
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modemfac.mod ) ; then mv modemfac.mod $(MD_OUT) ; fi
	if ( test -f modemfac.M   ) ; then mv modemfac.M   $(MD_OUT) ; fi
	if ( test -f MODEMFAC.mod ) ; then mv MODEMFAC.mod $(MD_OUT) ; fi

$(MODSTCY): $(MD_SRC)/modstcy.f $(MODINC)
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modstcy.mod ) ; then mv modstcy.mod $(MD_OUT) ; fi
	if ( test -f modstcy.M   ) ; then mv modstcy.M   $(MD_OUT) ; fi
	if ( test -f MODSTCY.mod ) ; then mv MODSTCY.mod $(MD_OUT) ; fi

$(MODMERGE): $(MD_SRC)/modmerge.f $(MODINC)
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modmerge.mod ) ; then mv modmerge.mod $(MD_OUT) ; fi
	if ( test -f modmerge.M   ) ; then mv modmerge.M   $(MD_OUT) ; fi
	if ( test -f MODMERGE.mod ) ; then mv MODMERGE.mod $(MD_OUT) ; fi

$(MODELEV): $(MD_SRC)/modelev.f $(MODINC)
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modelev.mod ) ; then mv modelev.mod $(MD_OUT) ; fi
	if ( test -f modelev.M   ) ; then mv modelev.M   $(MD_OUT) ; fi
	if ( test -f MODELEV.mod ) ; then mv MODELEV.mod $(MD_OUT) ; fi

$(MODMET): $(MD_SRC)/modmet.f
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modmet.mod ) ; then mv modmet.mod $(MD_OUT) ; fi
	if ( test -f modmet.M   ) ; then mv modmet.M   $(MD_OUT) ; fi
	if ( test -f MODMET.mod ) ; then mv MODMET.mod $(MD_OUT) ; fi

$(MODBIOG): $(MD_SRC)/modbiog.f $(MODINC)
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modbiog.mod ) ; then mv modbiog.mod $(MD_OUT) ; fi
	if ( test -f modbiog.M   ) ; then mv modbiog.M   $(MD_OUT) ; fi
	if ( test -f MODBIOG.mod ) ; then mv MODBIOG.mod $(MD_OUT) ; fi

$(MODBEIS3): $(MD_SRC)/modbeis3.f 
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modbeis3.mod ) ; then mv modbeis3.mod $(MD_OUT) ; fi
	if ( test -f modbeis3.M   ) ; then mv modbeis3.M   $(MD_OUT) ; fi
	if ( test -f MODBEIS3.mod ) ; then mv MODBEIS3.mod $(MD_OUT) ; fi

$(MODREPRT): $(MD_SRC)/modreprt.f $(MODINC)
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modreprt.mod ) ; then mv modreprt.mod $(MD_OUT) ; fi
	if ( test -f modreprt.M   ) ; then mv modreprt.M   $(MD_OUT) ; fi
	if ( test -f MODREPRT.mod ) ; then mv MODREPRT.mod $(MD_OUT) ; fi

$(MODREPBN): $(MD_SRC)/modrepbn.f $(MODINC)
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modrepbn.mod ) ; then mv modrepbn.mod $(MD_OUT) ; fi
	if ( test -f modrepbn.M   ) ; then mv modrepbn.M   $(MD_OUT) ; fi
	if ( test -f MODREPBN.mod ) ; then mv MODREPBN.mod $(MD_OUT) ; fi

$(MODMBSET): $(MD_SRC)/modmbset.f
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modmbset.mod ) ; then mv modmbset.mod $(MD_OUT) ; fi
	if ( test -f modmbset.M   ) ; then mv modmbset.M   $(MD_OUT) ; fi
	if ( test -f MODMBSET.mod ) ; then mv MODMBSET.mod $(MD_OUT) ; fi

$(MODAR2PT): $(MD_SRC)/modar2pt.f $(MODINC)
	$(FC) $(FFLAGS) -c -o $@ $<
	if ( test -f modar2pt.mod ) ; then mv modar2pt.mod $(MD_OUT) ; fi
	if ( test -f modar2pt.M   ) ; then mv modar2pt.M   $(MD_OUT) ; fi
	if ( test -f MODAR2PT.mod ) ; then mv MODAR2PT.mod $(MD_OUT) ; fi