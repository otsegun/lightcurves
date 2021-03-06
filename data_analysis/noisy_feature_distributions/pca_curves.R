#######
####### perform pca on normalized magnitude densities
####### look for class information
#######
####### by James Long
####### created Feb 14, 2011    last modified Feb 14, 2011
#######


rm(list = ls(all = TRUE))

library('randomForest')
library('class')

# how to get scaling right

# get the data
tfe = read.table("tfe.txt",sep=";",header=TRUE)
features = read.table("features.txt",sep=";",header=TRUE)
source.ids = data.frame(features$features.source_id,
  features$sources.classification)
names(source.ids) = c("source_id","class")
data1 = merge(tfe,source.ids,by=c("source_id"))


# make density for each curve
source.ids = unique(data1$source_id)
density.functions = list()
ecdf.functions = list()

for(i in source.ids){
  data1$flux[data1$source_id == i] =
    scale(data1$flux[data1$source_id == i])
}
for(i in 1:length(source.ids)){
  density.functions[[i]] = density(data1$flux[data1$source_id == source.ids[i]],from=-4,to=4)
  ecdf.functions[[i]] = ecdf(data1$flux[data1$source_id == source.ids[i]])  
}


### make several plots, one for each class

source.ids.class = sapply(source.ids,function(x){data1$class[data1$source_id == x][1]})
length(source.ids.class) == length(source.ids)



for(j in levels(source.ids.class)){
  clean.class = gsub("/","",j)
  clean.class = gsub(" ","",clean.class)
  filename = paste("plots/",clean.class,".pdf",sep="")
  pdf(filename)
  plot(c(-4,-4,4,4),c(0,3,3,0),col=0,main=j,xlab="Normalized Flux",ylab="Density")
  for(i in (1:length(source.ids))[source.ids.class == j]){
    lines(density.functions[[i]],col="#00000040")
  }
  dev.off()
  filename = paste("plots/ecdf",clean.class,".pdf",sep="")
  pdf(filename)
  plot(c(-4,-4,4,4),c(0,1,1,0),col=0,main=j,xlab="Normalized Flux",ylab="Empirical CDF")
  for(i in (1:length(source.ids))[source.ids.class == j]){
    lines(ecdf.functions[[i]])
  }
  dev.off()

}


###
### svd
###
densities.for.pca = matrix(0,nrow=length(source.ids),ncol=512)
for(i in 1:length(source.ids)){
  densities.for.pca[i,] = density.functions[[i]]$y
}


densities.for.pca = scale(densities.for.pca,scale=FALSE)
density.cov = t(densities.for.pca) %*% densities.for.pca
density.cov.eigen = eigen(density.cov)


#### some visualization of the eigenvectors

dev.new()
plot(density.functions[[1]]$x,density.cov.eigen$vectors[,1],type='l')

dev.new()
plot(density.functions[[1]]$x,density.cov.eigen$vectors[,1],type='l',col='blue',ylim=c(min(density.cov.eigen$vectors[,1],density.cov.eigen$vectors[,2]),max(density.cov.eigen$vectors[,1],density.cov.eigen$vectors[,2])))
lines(density.functions[[1]]$x,density.cov.eigen$vectors[,2],col='orange')


plot(density.functions[[1]]$x,density.cov.eigen$vectors[,2],type='l')

plot(density.functions[[1]]$x,density.cov.eigen$vectors[,3],type='l')

plot(density.functions[[1]]$x,density.cov.eigen$vectors[,4],type='l')

plot(density.functions[[1]]$x,density.cov.eigen$vectors[,5],type='l')


plot(density.functions[[1]]$x,density.cov.eigen$vectors[,6],type='l')



#### project densities onto first two dimensions
densities.projected = densities.for.pca %*% density.cov.eigen$vectors

# 
plot(densities.projected[,1],densities.projected[,2],col=as.numeric(source.ids.class))
plot(densities.projected[,2],densities.projected[,4],col=as.numeric(source.ids.class))
plot(densities.projected[,1],densities.projected[,4],col=as.numeric(source.ids.class))


plot(densities.projected[,13],densities.projected[,12],col=as.numeric(source.ids.class))


projections.with.class = data.frame(source.ids.class,densities.projected[,1:10])

rf = randomForest(densities.projected[,1:40],source.ids.class)
sum(diag(rf$confusion[,1:26])) / sum(rf$confusion[,1:26])



varImpPlot(rf)


number.eigens.to.use = 40
project.with.sources.ids = data.frame(densities.projected[,1:number.eigens.to.use],source.ids)
names(project.with.sources.ids) = c(paste("eigen",1:number.eigens.to.use,sep=""),"features.source_id")
features.with.eigens = merge(project.with.sources.ids,features,by="features.source_id")


# with eigenvectors
formula.predictors = names(features.with.eigens)[grep("features.*",names(features.with.eigens))]
to_remove = c("features.n_points","features.source_id","features.n_points.noisified","features.source_id.noisified","features.min","features.max","features.max_slope","features.max","features.std","features.amplitude","features.median","features.weighted_average")
to_add = paste("eigen",1:number.eigens.to.use,sep="")
formula.predictors = formula.predictors[!(formula.predictors %in% to_remove)]
formula.predictors = c(formula.predictors,to_add)
rf.formula.eigen = formula(paste("sources.classification ~ ",paste(formula.predictors,collapse=" + ")))

# formula without eigenvectors
formula.predictors = names(features.with.eigens)[grep("features.*",names(features.with.eigens))]
to_remove = c("features.n_points","features.source_id","features.n_points.noisified","features.source_id.noisified","features.min","features.max","features.max_slope","features.max","features.std","features.amplitude","features.median","features.weighted_average")
formula.predictors = formula.predictors[!(formula.predictors %in% to_remove)]
rf.formula = formula(paste("sources.classification ~ ",paste(formula.predictors,collapse=" + ")))


rf.features = randomForest(rf.formula,data=features.with.eigens)
rf.features.eigens = randomForest(rf.formula.eigen,data=features.with.eigens)

sum(diag(rf.features$confusion[,1:26])) / sum(rf.features$confusion[,1:26])
sum(diag(rf.features.eigens$confusion[,1:26])) / sum(rf.features.eigens$confusion[,1:26])


varImpPlot(rf.features)
dev.new()
varImpPlot(rf.features.eigens)



####
#### comparison of eigenfunctions to non LS features
####

# only non LS features
non.ls.features = c("small_kurtosis","beyond1std","skew","median_buffer_range_percentage","median_absolute_deviation","percent_difference_flux_percentile","chi2_per_deg","chi2","dc","flux_percentile_ratio_mid65","flux_percentile_ratio_mid65","stetson_j","stetson_k","percent_amplitude","flux_percentile_ratio_mid50","flux_percentile_ratio_mid35","flux_percentile_ratio_mid20","flux_percentile_ratio_mid80")
non.ls.features = paste("features.",non.ls.features,sep="")
rf.formula.non.ls = formula(paste("sources.classification ~ ",paste(non.ls.features,collapse=" + ")))

# only eigen features
eigen.features = paste("eigen",1:number.eigens.to.use,sep="")
rf.formula.eigen.only = formula(paste("sources.classification ~ ",paste(eigen.features,collapse=" + ")))



rf.features.non.ls = randomForest(rf.formula.non.ls,data=features.with.eigens)
rf.features.eigens.only = randomForest(rf.formula.eigen.only,data=features.with.eigens)

sum(diag(rf.features.non.ls$confusion[,1:26])) / sum(rf.features.non.ls$confusion[,1:26])
sum(diag(rf.features.eigens.only$confusion[,1:26])) / sum(rf.features.eigens.only$confusion[,1:26])


varImpPlot(rf.features.non.ls)
dev.new()
varImpPlot(rf.features.eigens.only)




####
#### distance matrix from kde and do nn classifier
####
#densities.distance = dist(densities.for.pca)


to.train = runif(length(source.ids.class)) < .75

num.nn = 3:20
error.rate = rep(0,length(num.nn))
for(i in 1:length(num.nn)){
  test.predictions = knn(train=densities.for.pca[to.train,],test=densities.for.pca[!to.train,],cl=source.ids.class[to.train],k=num.nn[i]) 
  error.rate[i] = sum(test.predictions != source.ids.class[!to.train]) / sum(!to.train)
}


plot(num.nn,error.rate)
