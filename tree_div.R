
library(vegan)
library(sp)
library(rgdal)
library(foreach)
library(doParallel)
library(scales)
library(ggplot2)
library(gridExtra)
library(gstat)
library(nlme)
library(ggeffects)
library(vegan)
library(patchwork)

### set path and working directory
# make sure all files in the data folder are in your chosen working directory
path<-getwd()
#path<-"C:/Users/User/Documents/GitHub/WT_FIA_TreeDiv/data"
path<-"C:/Users/rouf1703/Documents/UdeS/GitHub/WT_FIA_TreeDiv/data"


#################################################
### Load Data ###################################
#################################################

### data ########################################
d <- read.csv(file.path(path,"tree_div.csv"),header=TRUE)
d$township<-paste(d$TOWNNAME,d$STATE,sep="_")

spwt<-names(d)[grep("_WT",names(d))]
spfia<-names(d)[grep("_FIA",names(d))][-1]

simpson<-function(x){
  if(!isTRUE(all.equal(1,sum(x),tolerance=1e-05))){
    stop("Proportions not scaled to 1") 
  }
  s<-sum(x^2)
  1/s
  #s<-1-sum(x^2)
  #1/(1-s)
}

shannon<-function(x){
  if(!isTRUE(all.equal(1,sum(x),tolerance=1e-05))){
    stop("Proportions not scaled to 1")  
  }
  s<-x[x>0]
  exp(-sum(s*log(s)))
}

#################################################
### Compute Diversity Indices ###################
#################################################

# Three types of analysis can be ran (full, richness or trees). The type has to be given here and the rest of the script up to the dissimilarity analyses will produce the different figures accordingly.
type<-"full" # c("full","richness","trees")
set.seed(1234)

# This part implements the three ways of computing indices
l<-split(d,1:nrow(d))
l<-lapply(l,function(i){
  iwt<-i[,spwt]
  ifia<-i[,spfia]
  i$Rich_wt<-sum(i[,spwt]>0)  
  i$Rich_fia<-sum(i[,spfia]>0)
  i$Rich_dif<-i$Rich_fia-i$Rich_wt
  if(type=="trees" & (i$Trees_Wit!=i$Trees_FIA)){ # if the same number of trees, no resampling is done
    w<-which.max(c(i$Trees_Wit,i$Trees_FIA))
    n<-min(c(i$Trees_Wit,i$Trees_FIA))
    nreps<-1000
    if(w==1){
      s<-lapply(1:nreps,function(j){
        tab<-table(sample(as.factor(spwt),n,prob=as.vector(iwt),replace=TRUE))
        tab<-tab/sum(tab)
        c(shannon(tab),simpson(tab),sum(tab>0))
      })
      ss<-colMeans(do.call("rbind",s))
      i$Shan_fia<-apply(ifia,1,shannon)
      i$Shan_wt<-ss[1]
      i$Shan_dif<-i$Shan_fia-i$Shan_wt
      i$Simp_fia<-apply(ifia,1,simpson)
      i$Simp_wt<-ss[2]
      i$Simp_dif<-i$Simp_fia-i$Simp_wt
      i$Rich_wt<-ss[3]  
      i$Rich_dif<-i$Rich_fia-i$Rich_wt
    }else{
      s<-lapply(1:nreps,function(j){
        tab<-table(sample(as.factor(spfia),n,prob=as.vector(ifia),replace=TRUE))
        tab<-tab/sum(tab)
        c(shannon(tab),simpson(tab),sum(tab>0))
      })
      ss<-colMeans(do.call("rbind",s))
      i$Shan_fia<-ss[1]
      i$Shan_wt<-apply(iwt,1,shannon)
      i$Shan_dif<-i$Shan_fia-i$Shan_wt
      i$Simp_fia<-ss[2]
      i$Simp_wt<-apply(iwt,1,simpson)
      i$Simp_dif<-i$Simp_fia-i$Simp_wt
      i$Rich_fia<-ss[3]  
      i$Rich_dif<-i$Rich_fia-i$Rich_wt
    }
  }else{
    if(type=="richness" & (i$Rich_wt!=i$Rich_fia)){ # if same richness diversity, no resampling is done
      w<-which.max(c(i$Rich_wt,i$Rich_fia))
      n<-min(c(i$Rich_wt,i$Rich_fia))
      if(w==1){
        spsel<-names(rev(sort(i[,spwt]))[1:n])  
        iwt<-i[,spsel]
        iwt<-iwt/sum(iwt)
        i[,setdiff(spwt,spsel)]<-0 # this "erases" species not selected in original data to perform modified beta diversity analysis below 
        i[,spwt]<-i[,spwt]/sum(i[,spwt])
      }else{
        spsel<-names(rev(sort(i[,spfia]))[1:n])
        ifia<-i[,spsel]  
        ifia<-ifia/sum(ifia)
        i[,setdiff(spfia,spsel)]<-0 # this "erases" species not selected in original data to perform modified beta diversity analysis below 
        i[,spfia]<-i[,spfia]/sum(i[,spfia])
      }
    }
    i$Shan_fia<-apply(ifia,1,shannon)
    i$Shan_wt<-apply(iwt,1,shannon)
    i$Shan_dif<-i$Shan_fia-i$Shan_wt
    i$Simp_fia<-apply(ifia,1,simpson)
    i$Simp_wt<-apply(iwt,1,simpson)
    i$Simp_dif<-i$Simp_fia-i$Simp_wt
  }
  i
})
d<-do.call("rbind",l)

### exploratory graphs ##########################

# only meaningfull with type="full"
gg1<-ggplot(d,aes(log(Trees_Wit/Trees_FIA),Shan_dif))+geom_point()+geom_smooth()+theme_bw()
gg2<-ggplot(d,aes(log(Trees_Wit/Trees_FIA),Simp_dif))+geom_point()+geom_smooth()+theme_bw()
gg3<-ggplot(d,aes(log(Trees_Wit/Trees_FIA),peak_ag))+geom_point()+geom_smooth()+theme_bw()

png(file.path(path,"div_logratio_peak_ag.png"),pointsize=4,width=10,height=8,units="in",res=300)
wrap_plots(gg1,gg2,gg3)
dev.off()


#################################################
### averages and wt fia comparison ##############
#################################################

### means #######################################
v<-c("FIA_Plots","Trees_FIA","Trees_Wit")
li<-list(
  apply(d[,v],2,mean),
  apply(d[,v],2,sd),
  apply(d[,v],2,min),
  apply(d[,v],2,max)
)
means<-t(do.call("rbind",li))
colnames(means)<-c("mean","sd","min","max")
means

### scatterplot #################################

par(mfrow=c(1,2))
lim<-c(30,max(c(d[,"Trees_Wit"],d[,"Trees_FIA"])))
plot(d[,"Trees_Wit"],d[,"Trees_FIA"],xlim=lim,ylim=lim,xlab="Number of trees, historical",ylab="Number of trees, contemporary",pch=16,col=gray(0,0.15),asp=1,log="xy")
abline(0,1)
lim<-c(2,max(c(d[,"Rich_wt"],d[,"Rich_fia"])))
plot(jitter(d[,"Rich_wt"],amount=0.25),jitter(d[,"Rich_fia"],amount=0.25),xlim=lim,ylim=lim,xlab="Historical richness",ylab="Contemporary richness",pch=16,col=gray(0,0.15),asp=1)
abline(0,1)


#################################################
### Load other environmental variables ##########
#################################################

### environmental PCA ###########################
pca.input<-d[,c("clay","elevation","ph_soil","sand","ruggedness")]
env.pca<-rda(pca.input,scale=TRUE)
env.pca$CA$eig/env.pca$tot.chi
scores(env.pca)$species
biplot(env.pca,display=c("sites","species"),type=c("text","points"))
d$envPCA1<-scores(env.pca)$sites[,1]
d$envPCA2<-scores(env.pca)$sites[,2]

### correlate PCA axes with peak_ag
par(mfrow=c(1,2))
plot(d$envPCA1,d$peak_ag,main=round(cor(d$envPCA1,d$peak_ag),2))
plot(d$envPCA2,d$peak_ag,main=round(cor(d$envPCA2,d$peak_ag),2))
par(mfrow=c(1,1))

### turn data to spatial object #################
ds<-d
coordinates(ds)<-~LONGITUDE+LATITUDE
proj4string(ds)<-"+init=epsg:4326"

### climate data ################################
div<-readOGR(path,"climate_div")
div<-div[!is.na(div$ST),]

temp<-read.csv(file.path(path,"temperature_fig-3.csv"),skip=6)
names(temp)<-c("div","tempc")
temp$div<-ifelse(nchar(temp$div)==5,gsub("00","0",temp$div),temp$div)
div$div<-paste0(div$ST_,formatC(div$DIV_,flag="0",width=2))
div$tempc<-temp$tempc[match(div$div,temp$div)]

### nitrogen data ################################
n<-read.csv(file.path(path,"US_historical_deposition_rev.csv"))
coordinates(n)<- ~lon + lat
proj4string(n)<-"+init=epsg:4326"

# project data to climate data projection
ds<-spTransform(ds,CRS(proj4string(div)))
n<-spTransform(n,CRS(proj4string(div)))


################################################
### Interpolate Temperature
#################################################

x <- idw(tempc~1,locations=div,newdata=ds,nmax=4,idp=2)

vals<-x@data[,1]

d$tempdiff_i<-vals
ds$tempdiff_i<-vals

o<-over(spTransform(ds,CRS(proj4string(div))),div)

d$tempdiff<-o$tempc
ds$tempdiff<-o$tempc


#################################################
### Interpolate Nitrogen
#################################################

nm<-c("N_khy_1850","N_khy_2000","N_to_1984","N_to_2000")
logn<-as.data.frame(apply(n@data[,nm],2,identity))
n@data[,paste0("log",nm)]<-logn
nm<-paste0("log",nm)

l<-list()
for(i in seq_along(nm)){
	n$value<-n@data[,nm[i]]
	x<-idw(value~1,locations=n,newdata=ds,nmax=4,idp=2)
 vals<-x@data[,1]
	l[[i]]<-vals
}

nvals<-do.call("data.frame",l)
d[,paste0(nm,"_i")]<-nvals
ds@data[,paste0(nm,"_i")]<-nvals


#################################################
### Models
#################################################

### add projected coordinates to data.frame
ds$X<-coordinates(ds)[,1]
ds$Y<-coordinates(ds)[,2]

### variable names and scaled variable names
ds$logratio<-log(ds$Trees_Wit/ds$Trees_FIA)
if(type=="full"){
  v<-c("peak_ag","tempdiff_i","N_to_1984_i","Area_SqKM","envPCA1","temp_gdd")
}else{
  v<-c("peak_ag","tempdiff_i","N_to_1984_i","Area_SqKM","envPCA1","temp_gdd")  
}
vs<-paste0(v,"_sc")

### scale variables and save means and sds of unscaled variables
s<-lapply(ds@data[,v],function(i){c(mean(i),sd(i))})
names(s)<-v
ds@data[,vs]<-lapply(1:length(v),function(i){
	(ds@data[,v[i]]-s[[i]][1])/s[[i]][2]
})

### check for spatial autocorrelation
fit<-lme(formula(paste0("Simp_dif~",paste(vs,collapse="+"))),ds@data,random=~1|Ecoregion)
ds$resid<-resid(fit,type="n")
va<-variogram(resid~1,data=ds,width=1000,cutoff=200000)
plot(va)

### models
m_Simp<-lme(formula(paste0("Simp_dif~",paste(vs,collapse="+"))),ds@data,random=~1|Ecoregion,correlation=corExp(30000,form=~X+Y,nugget=TRUE))
m_Shan<-lme(formula(paste0("Shan_dif~",paste(vs,collapse="+"))),ds@data,random=~1|Ecoregion,correlation=corExp(30000,form=~X+Y,nugget=TRUE))
m_Rich<-lme(formula(paste0("Rich_dif~",paste(vs,collapse="+"))),ds@data,random=~1|Ecoregion,correlation=corExp(30000,form=~X+Y,nugget=TRUE))

#plot(ggpredict(m_Shan,terms="peak_ag_sc"),add=TRUE)
#plot(ggpredict(m_Shan,terms="logratio_sc"),add=TRUE)

### model checking
hist(resid(m_Shan))
plot(fitted(m_Shan),resid(m_Shan))

### model coefficients
as.data.frame(summary(m_Shan)$tTable)
as.data.frame(summary(m_Simp)$tTable)
as.data.frame(summary(m_Rich)$tTable)

### t.test and correlations
cor(d$Simp_dif,d$Shan_dif)

mean(d$Shan_wt)
mean(d$Shan_fia)
t.test(d$Shan_wt,d$Shan_fia,paired=TRUE)

mean(d$Simp_wt)
mean(d$Simp_fia)
t.test(d$Simp_wt,d$Simp_fia,paired=TRUE)

mean(d$Rich_wt)
mean(d$Rich_fia)
t.test(d$Rich_wt,d$Rich_fia,paired=TRUE)

### Figure 1
### marginal effects and change distributions
png(file.path(path,paste0("peak_ag",paste0("_",type),".png")),pointsize=4,width=10,height=ifelse(type=="trees",12,8),units="in",res=300)

g1<-as.data.frame(ggpredict(m_Simp,terms=c("peak_ag_sc[n=100]")))
g1[,c("x")]<-(g1[,c("x")]*s[["peak_ag"]][2])+s[["peak_ag"]][1] # rescale variables
g1<-ggplot(g1)+
	geom_hline(yintercept=0,linetype=2,colour=gray(0.2))+
	geom_point(data=d,aes(peak_ag,Simp_dif),size=1.75,alpha=0.5,colour="green4")+
	geom_ribbon(aes(x=x,ymin=conf.low,ymax=conf.high),fill=gray(0.5,0.75))+
	geom_line(aes(x=x,y=predicted),size=1)+
	xlab("Maximum historical agriculture (proportion)")+
	ylab("Change in Simpson diversity")+
	theme_light()+
	theme(axis.text=element_text(size=rel(1.25)),axis.title=element_text(size=rel(1.25)),panel.grid=element_blank(),plot.margin=unit(rep(0.5,4),"cm"),panel.border = element_rect(colour=gray(0.15), fill = NA))+
	scale_y_continuous(breaks=seq(-8,8,by=2))+scale_x_continuous(breaks=seq(0,1,by=0.2))+
	annotate(geom='text',label='C',x=-Inf,y=Inf,hjust=-0.6,vjust=1.4,size=8)

g2<-as.data.frame(ggpredict(m_Shan,terms=c("peak_ag_sc[n=100]")))
g2[,c("x")]<-(g2[,c("x")]*s[["peak_ag"]][2])+s[["peak_ag"]][1]
g2<-ggplot(g2)+
	geom_hline(yintercept=0,linetype=2,colour=gray(0.2))+
	geom_point(data=d,aes(peak_ag,Shan_dif),size=1.75,alpha=0.5,colour="green4")+
	geom_ribbon(aes(x=x,ymin=conf.low,ymax=conf.high),fill=gray(0.5,0.75))+
	geom_line(aes(x=x,y=predicted),size=1)+
	xlab("Maximum historical agriculture (proportion)")+
	ylab("Change in Shannon diversity")+
	theme_light()+
	theme(axis.text=element_text(size=rel(1.25)),axis.title=element_text(size=rel(1.25)),panel.grid=element_blank(),plot.margin=unit(rep(0.5,4),"cm"),panel.border = element_rect(colour=gray(0.15), fill = NA))+
	scale_y_continuous(breaks=seq(-8,8,by=2))+scale_x_continuous(breaks=seq(0,1,by=0.2))+
	annotate(geom='text',label='A',x=-Inf,y=Inf,hjust=-0.6,vjust=1.4,size=8)

g3<-as.data.frame(ggpredict(m_Rich,terms=c("peak_ag_sc[n=100]")))
g3[,c("x")]<-(g3[,c("x")]*s[["peak_ag"]][2])+s[["peak_ag"]][1]
g3<-ggplot(g3)+
  geom_hline(yintercept=0,linetype=2,colour=gray(0.2))+
  geom_point(data=d,aes(peak_ag,Rich_dif),size=1.75,alpha=0.5,colour="green4")+
  geom_ribbon(aes(x=x,ymin=conf.low,ymax=conf.high),fill=gray(0.5,0.75))+
  geom_line(aes(x=x,y=predicted),size=1)+
  xlab("Maximum historical agriculture (proportion)")+
  ylab("Change in Richness")+
  theme_light()+
  theme(axis.text=element_text(size=rel(1.25)),axis.title=element_text(size=rel(1.25)),panel.grid=element_blank(),plot.margin=unit(rep(0.5,4),"cm"),panel.border = element_rect(colour=gray(0.15), fill = NA))+
  scale_y_continuous(breaks=seq(-14,8,by=2))+scale_x_continuous(breaks=seq(0,1,by=0.2))+
  annotate(geom='text',label='E',x=-Inf,y=Inf,hjust=-0.6,vjust=1.4,size=8)

g4<-ggplot(data=d,aes(Simp_dif))+
  geom_histogram(fill=gray(0.75,1),colour="white",breaks=seq(-8,8,by=1))+
  geom_vline(xintercept=mean(d$Simp_dif),size=0.7,colour="tomato")+
  xlab("Change in Simpson diversity")+
  ylab("Frequency")+
  theme_light()+
  theme(axis.text=element_text(size=rel(1.25)),axis.title=element_text(size=rel(1.25)),panel.grid=element_blank(),plot.margin=unit(rep(0.5,4),"cm"),panel.border = element_rect(colour=gray(0.15), fill = NA))+
  scale_x_continuous(breaks=seq(-8,8,by=2))+
  annotate(geom='text',label='D',x=-Inf,y=Inf,hjust=-0.6,vjust=1.4,size=8)

g5<-ggplot(data=d,aes(Shan_dif))+
	geom_histogram(fill=gray(0.75,1),colour="white",breaks=seq(-8,8,by=1))+
	geom_vline(xintercept=mean(d$Shan_dif),size=0.7,colour="tomato")+
	xlab("Change in Shannon diversity")+
	ylab("Frequency")+
	theme_light()+
	theme(axis.text=element_text(size=rel(1.25)),axis.title=element_text(size=rel(1.25)),panel.grid=element_blank(),plot.margin=unit(rep(0.5,4),"cm"),panel.border = element_rect(colour=gray(0.15), fill = NA))+
	scale_x_continuous(breaks=seq(-8,8,by=2))+
	annotate(geom='text',label='B',x=-Inf,y=Inf,hjust=-0.6,vjust=1.4,size=8)

g6<-ggplot(data=d,aes(Rich_dif))+
  geom_histogram(fill=gray(0.75,1),colour="white",breaks=seq(-14,8,by=1))+
  geom_vline(xintercept=mean(d$Rich_dif),size=0.7,colour="tomato")+
  xlab("Change in Richness")+
  ylab("Frequency")+
  theme_light()+
  theme(axis.text=element_text(size=rel(1.25)),axis.title=element_text(size=rel(1.25)),panel.grid=element_blank(),plot.margin=unit(rep(0.5,4),"cm"),panel.border = element_rect(colour=gray(0.15), fill = NA))+
  scale_x_continuous(breaks=seq(-14,8,by=2))+
  annotate(geom='text',label='F',x=-Inf,y=Inf,hjust=-0.6,vjust=1.4,size=8)

if(type=="trees"){
  grid.arrange(grobs=list(g2,g5,g1,g4,g3,g6),ncol=2)
  #grid.arrange(grobs=list(g2,g5,g1,g4),ncol=2)
}else{
  grid.arrange(grobs=list(g2,g5,g1,g4),ncol=2)
}

dev.off()


#################################################
### Bray-Curtis Dissimilarity
#################################################

### d object needs to be taken from what precedes since species proportions are modified in richness method (but not in trees method)

### species names for each surveys
fix<-c("_WT","_FIA")
g1<-grep(fix[1],names(d))
g2<-grep(fix[2],names(d))[-1] # removes the generic trees column

### Bray-Curtis dissimilarities
bc1<-as.matrix(vegdist(d[,g1]))
bc2<-as.matrix(vegdist(d[,g2]))

### calculates great circle distances
s<-spDists(as.matrix(d[,c("LONGITUDE","LATITUDE")]),longlat=TRUE)

### remove duplicate pairs
bc1[upper.tri(bc1,diag=TRUE)]<-NA
bc2[upper.tri(bc2,diag=TRUE)]<-NA
s[upper.tri(s,diag=TRUE)]<-NA
x<-data.frame(dist=as.vector(s),bc1=as.vector(bc1),bc2=as.vector(bc2))
x<-x[!is.na(x$dist),]

### set number of cores used
registerDoParallel(detectCores()-1) 
getDoParWorkers()

### bootstrap loess curves and difference and generate predictions
nboot<-500 # 500 in paper 
nsamp<-50000 #50000 in paper
res<-foreach(i=1:nboot,.packages=c("stats"),.verbose=TRUE) %dopar% {
	samp<-sample(1:nrow(x),nsamp,replace=TRUE)
	v<-seq(0,max(x$dist),by=1)
	m1<-loess(bc1~dist,data=x[samp,],degree=2)
	m2<-loess(bc2~dist,data=x[samp,],degree=2)
	p1<-predict(m1,data.frame(dist=v))
	p2<-predict(m2,data.frame(dist=v))
	cbind(p1,p2)
}

### bind bootstrapped predictions together
val1<-do.call("cbind",lapply(res,function(i){i[,1]}))
val2<-do.call("cbind",lapply(res,function(i){i[,2]}))

### extract confidence intervals
ci1<-t(apply(val1,1,function(i){quantile(i,c(0.025,0.975),na.rm=TRUE)}))
ci2<-t(apply(val2,1,function(i){quantile(i,c(0.025,0.975),na.rm=TRUE)}))

### colors
colsp<-c("dodgerblue3","tomato","black")
colsl<-c("dodgerblue4","darkred","black")


### Figure 2
### Dissimilarity
png(file.path(path,paste0("beta_div_",type,".png")),pointsize=9,width=10,height=8,units="in",res=100)
par(mar=c(4,4.5,3,3))
plot(x$dist,x$bc1,pch=16,col=alpha(colsp[1],0.15),cex=0.45,ylim=c(-0.1,1),xlab="",ylab="",axes=FALSE,xlim=c(0,1300),xaxs="i")
points(x$dist,x$bc2,pch=16,col=alpha(colsp[2],0.15),cex=0.45)
acol<-gray(0.15)
box(col=acol)
axis(1,tcl=-0.2,mgp=c(1.5,0.75,0),col=acol,cex.axis=1.75)
mtext("Distance (km)",side=1,line=2.5,cex=2)
axis(2,las=2,tcl=-0.2,mgp=c(1.5,0.5,0),col=acol,cex.axis=1.75)
mtext("Bray-Curtis dissimilarity",side=2,line=3,cex=2)

v<-seq(0,max(x$dist),by=1)

pol1<-na.omit(cbind(c(v,rev(v),v[1]),c(ci1[,1],rev(ci1[,2]),ci1[,1][1])))
polygon(pol1,col=alpha(colsl[1],0.5),border=NA)
lines(v,rowMeans(val1,na.rm=TRUE),col=colsl[1],lwd=2)

pol2<-na.omit(cbind(c(v,rev(v),v[1]),c(ci2[,1],rev(ci2[,2]),ci2[,1][1])))
polygon(pol2,col=alpha(colsl[2],0.5),border=NA)
lines(v,rowMeans(val2,na.rm=TRUE),col=colsl[2],lwd=2)

### difference
dif<-do.call("cbind",lapply(res,function(i){i[,2]-i[,1]}))
ci<-t(apply(dif,1,function(i){quantile(i,c(0.025,0.975),na.rm=TRUE)}))

pol<-na.omit(cbind(c(v,rev(v),v[1]),c(ci[,1],rev(ci[,2]),ci[,1][1])))
polygon(pol,col=alpha(colsp[3],0.25),border=NA,xpd=TRUE)
lines(v,rowMeans(dif,na.rm=TRUE),col=colsl[3],lwd=2,xpd=TRUE)

abline(0,0,lty=2,col=acol)

lx<-rep(600,3)
ly<-0.15-(0:2)*0.05
points(lx,ly,pch=15,col=alpha(colsl,c(0.5,0.5,0.25)),cex=3)
w<-9
segments(lx-w,ly,x1=lx+w,y1=ly,col=colsl,lwd=2,lend=2)
text(lx+20,ly,labels=c("Historical","Contemporary","Difference (Contemporary - Historical)"),adj=c(0,0.5),cex=2)
dev.off()



