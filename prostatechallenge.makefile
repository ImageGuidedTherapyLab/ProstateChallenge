SHELL := /bin/bash
WORKDIR=Processed
ROOTDIR=$(ARCHIVE)/github/ProstateChallenge
C3DEXE=/rsrch2/ip/dtfuentes/bin/c3d
ITKSNAP=vglrun /opt/apps/itksnap/itksnap-3.2.0-20141023-Linux-x86_64/bin/itksnap
OTBOFFSET  = 3
OTBRADIUS  = 4
OTBTEXTURE=/opt/apps/ANTsR/dev//ANTsR_src/ANTsR/src/ANTS/ANTS-build//bin//otbScalarImageToTexturesFilter
NMODELS=1
ANTSIMAGEMATHCMD=$(ANTSPATH)/ImageMath
DIMENSION  = 3
ATROPOSCMD=$(ANTSPATH)/Atropos -d $(DIMENSION)  -c [3,0.0] 
#OTBTEXTURE=/rsrch2/ip/dtfuentes/github/ExLib/otbScalarImageTextures/otbScalarImageToTexturesFilter

################
# Dependencies #
################
-include $(ROOTDIR)/dependencies
dependencies: ./prostatechallenge.sql
	-$(MYSQL) --local-infile < $< 
	$(MYSQL) -sNre "call DFProstateChallenge.RFHCCDeps();"  > $@

config: $(addprefix $(WORKDIR)/,$(addsuffix /config,$(TRAINING)))  
viewdata: $(addprefix $(WORKDIR)/,$(addsuffix /viewdata,$(TRAINING)))  
truth: $(addprefix $(WORKDIR)/,$(addsuffix /TRUTH.nii.gz,$(TRAINING)))  
lmpre: $(addprefix $(WORKDIR)/,$(addsuffix /landmarks.0.txt,$(TRAINING)))   \
       $(addprefix $(WORKDIR)/,$(addsuffix /landmarks.1.txt,$(TRAINING)))   \
       $(addprefix $(WORKDIR)/,$(addsuffix /landmarks.2.txt,$(TRAINING)))   \
       $(addprefix $(WORKDIR)/,$(addsuffix /landmarks.3.txt,$(TRAINING)))   \
       $(addprefix $(WORKDIR)/,$(addsuffix /landmarks.4.txt,$(TRAINING)))    
lm: $(addprefix $(WORKDIR)/,$(addsuffix /landmarks.txt,$(TRAINING)))  
reslice: $(addprefix $(WORKDIR)/,$(addsuffix /T2Sag.reslice.nii.gz,$(TRAINING)))  $(addprefix $(WORKDIR)/,$(addsuffix /ADC.reslice.nii.gz,$(TRAINING)))  $(addprefix $(WORKDIR)/,$(addsuffix /BVAL.reslice.nii.gz,$(TRAINING)))  $(addprefix $(WORKDIR)/,$(addsuffix /KTRANS.reslice.nii.gz,$(TRAINING)))  
sform: $(addprefix $(WORKDIR)/,$(addsuffix /T2Axial.sform.nii.gz,$(TRAINING))) $(addprefix $(WORKDIR)/,$(addsuffix /T2Sag.sform.nii.gz,$(TRAINING)))  $(addprefix $(WORKDIR)/,$(addsuffix /ADC.sform.nii.gz,$(TRAINING)))  $(addprefix $(WORKDIR)/,$(addsuffix /BVAL.sform.nii.gz,$(TRAINING)))  
norm:    $(addprefix $(WORKDIR)/,$(addsuffix /T2Axial.norm.nii.gz,$(TRAINING))) $(addprefix $(WORKDIR)/,$(addsuffix /T2Sag.norm.nii.gz,$(TRAINING)))
mask:    $(addprefix $(WORKDIR)/,$(addsuffix /MASK.nii.gz,$(TRAINING)))
texture: $(addprefix $(WORKDIR)/,$(addsuffix /T2Axial.HaralickCorrelation_$(OTBRADIUS).nii.gz,$(TRAINING)))
gmm: $(addprefix $(WORKDIR)/,$(addsuffix /ADC.gmm.nii.gz,$(TRAINING))) \
     $(addprefix $(WORKDIR)/,$(addsuffix /KTRANS.gmm.nii.gz,$(TRAINING)))
# compute all RF models
rfggg:  $(addsuffix /ggg/ALL/RF_MOST.nii.gz,      $(addprefix $(WORKDIR)/,$(TRAINING)))  

#https://www.gnu.org/software/make/manual/html_node/Special-Targets.html
# do not delete secondary files
.SECONDARY: 

$(WORKDIR)/%/landmarks.txt: 
	cat $(WORKDIR)/$*/landmarks.?.txt > $@ 
$(WORKDIR)/%/TRUTH.nii.gz: $(WORKDIR)/%/landmarks.txt $(WORKDIR)/%/T2Axial.sform.nii.gz
	$(C3DEXE) $(word 2,$^) -scale 0 -lts $< 5 -o $@

$(WORKDIR)/%/TRUTHADC.nii.gz: $(WORKDIR)/%/TRUTH.nii.gz $(WORKDIR)/%/ADC.gmm.nii.gz
	if [ -f $(word 2,$^)  ] ; then $(C3DEXE) $^ -replace 2 0  -multiply  -o $@ ;else $(C3DEXE) $<  -o $@ ; fi

$(WORKDIR)/%/TRUTHKTRANS.nii.gz: $(WORKDIR)/%/TRUTH.nii.gz $(WORKDIR)/%/KTRANS.gmm.nii.gz
	if [ -f $(word 2,$^)  ] ; then $(C3DEXE) $^ -replace 1 0  -multiply  -o $@ ;else $(C3DEXE) $<  -o $@ ; fi

$(WORKDIR)/%/BIOPSYMASK.nii.gz: $(WORKDIR)/%/TRUTH.nii.gz
	$(C3DEXE)  $< -binarize -o $@

$(WORKDIR)/%.sform.nii.gz: $(WORKDIR)/%.raw.nii.gz $(WORKDIR)/%.world
	sed 's/,/ /g' $(word 2,$^) > $(basename $(word 2,$^)).mat
	$(C3DEXE)  $< -set-sform $(basename $(word 2,$^)).mat -o $@

$(WORKDIR)/%/T2Axial.norm.nii.gz: $(WORKDIR)/%/T2Axial.sform.nii.gz
	$(C3DEXE) $< -stretch 2% 98% 0.0 1.0  -type float -o $@
$(WORKDIR)/%/T2Sag.norm.nii.gz: $(WORKDIR)/%/T2Sag.reslice.nii.gz
	$(C3DEXE) $< -stretch 2% 98% 0.0 1.0  -type float -o $@
$(WORKDIR)/%/MASK.nii.gz: $(WORKDIR)/%/T2Sag.reslice.nii.gz
	$(C3DEXE) $< -thresh 10 inf 1 0  -type uchar -o $@
$(WORKDIR)/%.HaralickCorrelation_$(OTBRADIUS).nii.gz: $(WORKDIR)/%.norm.nii.gz
	if [ 0 -eq 1  ] ; then $(OTBTEXTURE) $<  $(WORKDIR)/$*.   5 $(OTBRADIUS)     0             0            0     0 1   ;fi

$(WORKDIR)/%/viewdata:
	$(C3DEXE) $(@D)/T2Axial.sform.nii.gz -info
	$(C3DEXE) $(@D)/T2Sag.sform.nii.gz   -info 
	$(C3DEXE) $(@D)/ADC.sform.nii.gz     -info
	$(C3DEXE) $(@D)/BVAL.sform.nii.gz    -info
	$(C3DEXE) $(@D)/KTRANS.sform.nii.gz  -info
	$(ITKSNAP) -g $(@D)/T2Axial.norm.nii.gz -s $(@D)/TRUTHADC.nii.gz -o $(@D)/T2Sag.norm.nii.gz   $(@D)/ADC.reslice.nii.gz     $(@D)/KTRANS.reslice.nii.gz  $(@D)/T2Axial.Entropy_4.nii.gz $(@D)/T2Axial.HaralickCorrelation_4.nii.gz 
	#$(ITKSNAP) -g $(@D)/T2Axial.norm.nii.gz -s $(@D)/TRUTH.nii.gz -o $(@D)/T2Sag.norm.nii.gz   $(@D)/ADC.reslice.nii.gz     $(@D)/BVAL.reslice.nii.gz    $(@D)/KTRANS.reslice.nii.gz  $(@D)/T2Axial.Entropy_4.nii.gz $(@D)/T2Axial.HaralickCorrelation_4.nii.gz $(@D)/ggg/ALL/RF_POSTERIORS.0001.1.nii.gz $(@D)/ggg/ALL/RF_POSTERIORS.0001.2.nii.gz $(@D)/ggg/ALL/RF_POSTERIORS.0001.3.nii.gz $(@D)/ggg/ALL/RF_POSTERIORS.0001.4.nii.gz $(@D)/ggg/ALL/RF_POSTERIORS.0001.5.nii.gz 


#####################
# Build data matrix #
#####################
FILELIST = KTRANS.reslice  T2Axial.norm ADC.reslice  T2Sag.norm T2Axial.Entropy_4 T2Axial.HaralickCorrelation_4 BVAL.reslice                                                                                                                  
LABELFILES = TRUTH TRUTHADC TRUTHKTRANS
lstat:   $(foreach idlabel,$(LABELFILES),$(foreach idimage,$(FILELIST),$(addprefix $(WORKDIR)/,$(addsuffix /$(idimage)/$(idlabel)/lstat.csv,$(TRAINING))))) 
sql:     $(foreach idlabel,$(LABELFILES),$(foreach idimage,$(FILELIST),$(addprefix $(WORKDIR)/,$(addsuffix /$(idimage)/$(idlabel).sql,$(TRAINING))))) 
# load lstat data to sql
$(WORKDIR)/%.sql: $(WORKDIR)/%/lstat.csv
	$(MYSQLIMPORT) --replace --fields-terminated-by=',' --lines-terminated-by='\n' --ignore-lines 1 DFProstateChallenge $<

echo: 
	echo $(foreach idlabel,$(LABELFILES),$(foreach idimage,$(FILELIST),$(addprefix $(WORKDIR)/,$(addsuffix /$(idimage)/$(idlabel)/lstat.csv,$(TRAINING))))) 

truthdatamatrix.csv: prostatechallenge.sql
	-$(MYSQL) --local-infile < $< 
	$(MYSQL) -re "call DFProstateChallenge.DataMatrix ('TRUTH');"       | sed "s/\t/,/g;s/NULL//g" > truthdatamatrix.csv
	$(MYSQL) -re "call DFProstateChallenge.DataMatrix ('TRUTHADC');"    | sed "s/\t/,/g;s/NULL//g" > truthadcdatamatrix.csv
	$(MYSQL) -re "call DFProstateChallenge.DataMatrix ('TRUTHKTRANS');" | sed "s/\t/,/g;s/NULL//g" > truthktransdatamatrix.csv

# build rf  model
$(WORKDIR)/%/SignificantFeatureImage.RFModel: truthdatamatrix.csv
	mkdir -p  $(@D)
	@echo 'args <- c("3","truthdatamatrix.csv","$(@D)/SignificantFeatureImage.","1", "1","2000","500","3","$(NMODELS)","$(firstword $(subst /, ,$*))","$(word 2,$(subst /, ,$*))","$(lastword $(subst /, ,$*))")'
	Rscript createRFModel.R 3  truthdatamatrix.csv  $(@D)/SignificantFeatureImage.  1    1   2000   500   3   $(NMODELS) $(subst /, ,$*)

# create WHO maps
$(WORKDIR)/%/RF_MOST.nii.gz: $(WORKDIR)/%/SignificantFeatureImage.RFModel 
	mkdir -p  $(WORKDIR)/$*
	@echo 'args <- c("3","$(@D)/SignificantFeatureImage.","$(WORKDIR)/$*/RF_POSTERIORS.%04d.","1","$(NMODELS)","$(subst /, ,$*)")'
	Rscript applyRFModel.R   3  $(WORKDIR)/$*/SignificantFeatureImage.  $(WORKDIR)/$*/RF_POSTERIORS.%04d.   1    $(NMODELS) $(subst /, ,$*)
	$(ANTSIMAGEMATHCMD) 3 $(WORKDIR)/$*/RF_MOST.nii.gz MostLikely 0 $(WORKDIR)/$*/RF_POSTERIORS.0001.*.nii.gz  

###########################################################################
.SECONDEXPANSION:
#https://www.gnu.org/software/make/manual/html_node/Secondary-Expansion.html#Secondary-Expansion
###########################################################################
#https://www.gnu.org/software/make/manual/html_node/Automatic-Variables.html

# reslice
$(WORKDIR)/%.reslice.nii.gz: $(WORKDIR)/%.sform.nii.gz $(WORKDIR)/$$(*D)/T2Axial.sform.nii.gz
	$(C3DEXE) $(word 2,$^) $< -reslice-identity -o $@

# load lstat data for each label file
$(WORKDIR)/%/lstat.csv: $(WORKDIR)/$$(firstword $$(subst /, ,$$*))/$$(word 2,$$(subst /, ,$$*)).nii.gz $(WORKDIR)/$$(firstword $$(subst /, ,$$*))/$$(word 3,$$(subst /, ,$$*)).nii.gz 
	echo $(subst /, ,$*)
	mkdir -p $(@D)
	$(C3DEXE) $<  $(word 2,$^) -lstat > $(@D)/lstat.txt &&  sed "s/^\s\+/$(firstword $(subst /, ,$*)),$(word 3 ,$(subst /, ,$*)),$(word 2 ,$(subst /, ,$*)),/g;s/\s\+/,/g;s/LabelID/InstanceUID,SegmentationID,FeatureID,LabelID/g;s/Vol(mm^3)/Vol.mm.3/g;s/Extent(Vox)/ExtentX,ExtentY,ExtentZ/g" $(@D)/lstat.txt  > $@

$(WORKDIR)/%.gmm.nii.gz: $(WORKDIR)/%.reslice.nii.gz $(WORKDIR)/$$(*D)/BIOPSYMASK.nii.gz
	$(ATROPOSCMD) -m [0.1,1x1x1] -i kmeans[2] -x $(word 2,$^) -a $<  -o $@

