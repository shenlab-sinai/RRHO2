##' An improved version for RRHO, which aims to correct the intepretation for top left region (up in x and down in y) nad bottom right region.
##'
##' We improved the algorithm such that all four regions of RRHO plot are meaningful
##' @title RRHO2
##' @param list1 data.frame. First column is the element (possibly gene) identifier, and the second is its value on which to sort. For differential gene expression, values are often -log10(P-value) * sign(effect).
##' @param list2 data.frame. Same as list1.
##' @param stepsize Controls the resolution of the test: how many items between any two overlap tests.
##' @param labels Character vector with two elements: the labels of the two lists.
##' @param plots Logical. Should output plots be returned?
##' @param outputdir Path name where plots ae returned.
##' @param BY Logical. Should Benjamini-Yekutieli FDR corrected pvalues be computed?
##' @param log10.ind Logical. Should pvalues be reported and plotted in -log10 scale and not -log scale?
##' @param maximum maximum value for a union scale, default is 200.
##' @param alternative RRHO algorithm "split" gives the new stratified representation, "enrichment" and "two-sided" refer to the original RRHO implementations
##' @param boundary boundary interval between different quadrant.
##' @param sort determines whether gene list should be sorted by p-values or effect size
##' @param method method for odds ratio or pvalue representation "fisher" used odds ratio and "hyper" uses p-value 
##' @param p_max maximum P-value to display in split RRHO2. Only affects the plot for "hyper" method
##' @return list of result
##' \item{hypermat}{Matrix of -log(pvals) of the test for the first i,j elements of the lists.}
##' @author Kelly and Caleb
##' @export
##' @examples
##' 
##' plotFolder <- 'plot'
##' system(paste('mkdir -p', plotFolder))
##' list.length <- 2000
##' list.names <- paste('Gene',1:list.length, sep='')
##' set.seed(15213)
##' gene.list1<- data.frame(list.names, sample(list.length)*sample(c(1,-1),list.length,replace=TRUE))
##' gene.list2<- data.frame(list.names, sample(list.length)*sample(c(1,-1),list.length,replace=TRUE))
##' # Enrichment alternative
##' RRHO.example <-  RRHO2(gene.list1, gene.list2, 
##'                       labels=c('x','y'), plots=TRUE, outputdir=plotFolder, BY=TRUE, log10.ind=TRUE)
##'

RRHO2 <- function (list1, list2, stepsize = defaultStepSize(list1, list2),
          labels, p_max=350, plots = FALSE, outputdir = NULL, BY = FALSE,
          log10.ind = FALSE, maximum=50, boundary = 0.1, res=100, method="hyper", alternative="split")
{
    # Standard checks
    if (length(list1[, 1]) != length(unique(list1[, 1])))
    stop("Non-unique gene identifier found in list1")
    if (length(list2[, 1]) != length(unique(list2[, 1])))
    stop("Non-unique gene identifier found in list2")
    if (plots && (missing(outputdir) || missing(labels)))
    stop("When plots=TRUE, outputdir and labels are required.")
    result <- list(hypermat = NA, hypermat.counts = NA, hypermat.signs = NA,
                 hypermat.by = NA, n.items = nrow(list1), stepsize = stepsize,
                 log10.ind = log10.ind, call = match.call())

    # Order the signed lists
    list1 <- list1[order(list1[, 2], decreasing = TRUE), ]
    list2 <- list2[order(list2[, 2], decreasing = TRUE), ]

    nlist1 <- length(list1[, 1])
    nlist2 <- length(list2[, 1])

    N <- max(nlist1, nlist2)

    # Assemble the initial enrichment matrices (split method)
    .hypermat_normal<- numericListOverlap(list1[, 1], list2[, 1], stepsize, method=method, alternative = alternative, maximum = maximum)
    hypermat_normal<- .hypermat_normal$log.pval

    .hypermat_flipX <- numericListOverlap(rev(list1[, 1]), list2[, 1], stepsize, method=method, alternative = alternative, maximum = maximum)
    hypermat_flipX <- .hypermat_flipX$log.pval
    hypermat_flipX2 <- hypermat_flipX[nrow(hypermat_flipX):1,]

    stepList1 <- seq(1, nlist1, stepsize)
    stepList2 <- seq(1, nlist2, stepsize)

    len1 <- length(stepList1)
    len2 <- length(stepList2)

    lenStrip1 <- round(len1*boundary)
    lenStrip2 <- round(len2*boundary)


    boundary1 <- sum(list1[stepList1,2] > 0)
    boundary2 <- sum(list2[stepList2,2] > 0)

    hypermat <- matrix(NA,nrow=nrow(hypermat_normal) + lenStrip1,ncol=ncol(hypermat_normal) + lenStrip2)
    hypermat[1:boundary1,1:boundary2] <- hypermat_normal[1:boundary1,1:boundary2] ## u1u2, quadrant III
    hypermat[lenStrip1 + (boundary1+1):len1,lenStrip2 + (boundary2+1):len2] <- hypermat_normal[(boundary1+1):len1,(boundary2+1):len2] ## d1d2, quadrant I
    hypermat[1:boundary1,lenStrip2 + (boundary2+1):len2] <- hypermat_flipX[len1:(len1 - boundary1 + 1),(boundary2+1):len2] ## u1d2, quadrant II
    hypermat[lenStrip1 + (boundary1+1):len1,1:boundary2] <- hypermat_flipX[(len1 - boundary1):1,1:boundary2] ## u1d2, quadrant IV

    if (log10.ind){
        hypermat <- hypermat * log10(exp(1))
    }

    if (BY) {
    hypermatvec <- matrix(hypermat, nrow = nrow(hypermat) *
                            ncol(hypermat), ncol = 1)
    hypermat.byvec <- p.adjust(exp(-hypermatvec), method = "BY")
    hypermat.by <- matrix(-log(hypermat.byvec), nrow = nrow(hypermat),
                          ncol = ncol(hypermat))
    if (log10.ind)
      hypermat.by <- hypermat.by * log10(exp(1))
    result$hypermat.by <- hypermat.by
    }
    maxind.dd <- which(max(hypermat[lenStrip1 + (boundary1+1):len1, lenStrip2 + (boundary2+1):len2],
                         na.rm = TRUE) == hypermat, arr.ind = TRUE)
    #
    maxind.dd <- maxind.dd[maxind.dd[,1]>=lenStrip1 + (boundary1+1) & maxind.dd[,1]<=lenStrip1 +len1 & 
                    maxind.dd[,2]>=lenStrip2 + (boundary2+1) & maxind.dd[,2]<=lenStrip2 + len2,]

    indlist1.dd <- seq(1, nlist1, stepsize)[maxind.dd[1] - lenStrip1]
    indlist2.dd <- seq(1, nlist2, stepsize)[maxind.dd[2] - lenStrip2]
    genelist.dd <- intersect(list1[indlist1.dd:nlist1,
                                 1], list2[indlist2.dd:nlist2, 1])
    maxind.uu <- which(max(hypermat[1:boundary1, 1:boundary2],
                         na.rm = TRUE) == hypermat, arr.ind = TRUE)
    #
    maxind.uu <- maxind.uu[maxind.uu[,1]>=1 & maxind.uu[,1]<=boundary1 & maxind.uu[,2]>=1 & maxind.uu[,2]<=boundary2,]

    indlist1.uu <- seq(1, nlist1, stepsize)[maxind.uu[1]]
    indlist2.uu <- seq(1, nlist2, stepsize)[maxind.uu[2]]
    genelist.uu <- intersect(list1[1:indlist1.uu, 1],
                           list2[1:indlist2.uu, 1])
    #
    maxind.ud <- which(max(hypermat[1:boundary1, lenStrip2 + (boundary2+1):len2],
                         na.rm = TRUE) == hypermat, arr.ind = TRUE)
    #
    maxind.ud <- maxind.ud[maxind.ud[,1]>=1 & maxind.ud[,1]<=boundary1 & maxind.ud[,2]>= lenStrip2 + (boundary2+1) & maxind.ud[,2]<=lenStrip2 + len2,]

    indlist1.ud <- seq(1, nlist1, stepsize)[maxind.ud[1]]
    indlist2.ud <- seq(1, nlist2, stepsize)[maxind.ud[2] - lenStrip2]
    genelist.ud <- intersect(list1[1:indlist1.ud,
                                 1], list2[indlist2.ud:nlist2, 1])
    maxind.du <- which(max(hypermat[lenStrip1 + (boundary1+1):len1, 1:boundary2],
                         na.rm = TRUE) == hypermat, arr.ind = TRUE)
    #
    maxind.du <- maxind.du[maxind.du[,1]>=lenStrip1 + (boundary1+1) & maxind.du[,1]<=lenStrip1 + len1 & maxind.du[,2]>=1 & maxind.du[,2]<=boundary2,]

    indlist1.du <- seq(1, nlist1, stepsize)[maxind.du[1] - lenStrip1]
    indlist2.du <- seq(1, nlist2, stepsize)[maxind.du[2]]
        if(is.na(indlist2.du) == TRUE){
            indlist2.du<-max(seq(1, nlist2, stepsize))
            }
    genelist.du <- intersect(list1[indlist1.du:nlist1, 1],
                           list2[1:indlist2.du, 1])

    # Generate plots, if desired
    if (plots) {
        try({
          #Define function for color bar
          color.bar <- function(lut, min, max = -min, nticks = 11,
                                ticks = seq(min, max, len = nticks), title = "") {
            scale <- (length(lut) - 1)/(max - min)
            plot(c(0, 10), c(min, max), type = "n", bty = "n",
                 xaxt = "n", xlab = "", yaxt = "n", ylab = "")
            mtext(title, 2, 2.3, cex = 0.8)
            axis(2, round(ticks, 0), las = 1, cex.lab = 0.8)
            for (i in 1:(length(lut) - 1)) {
              y <- (i - 1)/scale + min
              rect(0, y, 10, y + 1/scale, col = lut[i], border = NA)
            }
          }

        # Generate split RRHO2 plot
        .filename <- paste("RRHOMap_combined_", labels[1], "_VS_",
                         labels[2], "_pmax", p_max, ".tiff", sep = "")
        tiff(filename = paste(outputdir, .filename, sep = "/"),
           width = 8, height = 8, units = "in", 
           res = res)
        jet.colors <- colorRampPalette(c("#00007F", "blue",
                                       "#007FFF", "cyan", "#7FFF7F", "yellow", "#FF7F00",
                                       "red", "#7F0000"))
        layout(matrix(c(rep(1, 5), 2), 1, 6, byrow = TRUE))
        # image(hypermat, xlab = "", ylab = "", col = jet.colors(101),
        #       axes = FALSE, main = "Rank Rank Hypergeometric Overlap Map")
        image(hypermat, xlab = "", ylab = "", col = jet.colors(101),breaks=c(seq(0,p_max,length.out = 101),1e10),
         axes = FALSE, main = "Rank Rank Hypergeometric Overlap Map")
        segments(x0 = boundary1/len1 ,x1 = boundary1 /len1 ,y0 = -0.2,y1 = 1.2,lwd=4,col='white')
        segments(x0 = -0.2,x1 = 1.2,y0 = boundary2/len2,y1 = boundary2/len2,lwd=4,col='white')	  
        mtext(labels[2], 2, 0.5)
        mtext(labels[1], 1, 0.5)

        finite.ind <- is.finite(hypermat)
        color.bar(jet.colors(101), min = min(hypermat[finite.ind], na.rm = TRUE), 
                                max = p_max, nticks = 6, title = "-log(P-value)")
        dev.off()   

        #Generate accessory files of gene name overlaps
        .filename <- paste(outputdir, "/RRHO_down_",
                     labels[1], "_VS_down_", labels[2], ".csv", sep = "")
        write.table(genelist.dd, .filename, row.names = F,
                  quote = F, col.names = F)
        .filename <- paste(outputdir, "/RRHO_up_",
                         labels[1], "_VS_up_", labels[2], ".csv", sep = "")
        write.table(genelist.uu, .filename, row.names = F,
                  quote = F, col.names = F)

        .filename <- paste(outputdir, "/RRHO_down_",
                 labels[1], "_VS_up_", labels[2], ".csv", sep = "")
        write.table(genelist.du, .filename, row.names = F,
                  quote = F, col.names = F)
        .filename <- paste(outputdir, "/RRHO_up_",
                         labels[1], "_VS_down_", labels[2], ".csv", sep = "")
        write.table(genelist.ud, .filename, row.names = F,
                  quote = F, col.names = F)

        # Generate venn diagrams
        .filename <- paste(outputdir, "/RRHO_VennCon", labels[1],
                         "_VS_", labels[2], ".tiff", sep = "")
        tiff(.filename, width = 8.5, height = 5, units = "in",
            res = res)
        vp1 <- viewport(x = 0.25, y = 0.5, width = 0.5, height = 0.9)
        vp2 <- viewport(x = 0.75, y = 0.5, width = 0.5, height = 0.9)
        pushViewport(vp1)
        h1 <- draw.pairwise.venn(length(indlist1.dd:nlist1),
                               length(indlist2.dd:nlist2), length(genelist.dd),
                               category = c(labels[1], labels[2]), scaled = TRUE,
                               lwd = c(0, 0), fill = c("cornflowerblue", "darkorchid1"),
                               cex = 1, cat.cex = 1.2, cat.pos = c(0, 0), ext.text = FALSE,
                               ind = FALSE, cat.dist = 0.01)
        grid.draw(h1)
        grid.text(paste("Down",labels[1],"Down",labels[2]), y = 1)
        upViewport()
        pushViewport(vp2)
        h2 <- draw.pairwise.venn(length(1:indlist1.uu), length(1:indlist2.uu),
                               length(genelist.uu), category = c(labels[1],
                                                                 labels[2]), scaled = TRUE, lwd = c(0, 0), fill = c("cornflowerblue",
                                                                                                                    "darkorchid1"), cex = 1, cat.cex = 1.2, cat.pos = c(0,0), cat.dist = 0.01)
        grid.draw(h2)
        grid.text(paste("Up",labels[1],"Up",labels[2]), y = 1)
        dev.off()

        .filename <- paste(outputdir, "/RRHO_VennDis", labels[1],
                         "_VS_", labels[2], ".tiff", sep = "")
        tiff(.filename, width = 8.5, height = 5, units = "in",
            res = res)
        vp1 <- viewport(x = 0.25, y = 0.5, width = 0.5, height = 0.9)
        vp2 <- viewport(x = 0.75, y = 0.5, width = 0.5, height = 0.9)
        pushViewport(vp1)
        h1 <- draw.pairwise.venn(length(indlist1.du:nlist1),
                               length(1:indlist2.du), length(genelist.du),
                               category = c(labels[1], labels[2]), scaled = TRUE,
                               lwd = c(0, 0), fill = c("cornflowerblue", "darkorchid1"),
                               cex = 1, cat.cex = 1.2, cat.pos = c(0, 0), ext.text = FALSE,
                               ind = FALSE, cat.dist = 0.01)
        grid.draw(h1)
        grid.text(paste("Down",labels[1],"Up",labels[2]), y = 1)
        upViewport()
        pushViewport(vp2)
        h2 <- draw.pairwise.venn(length(1:indlist1.ud), length(indlist2.ud:nlist2),
                               length(genelist.ud), category = c(labels[1], labels[2]), scaled = TRUE,
        					   lwd = c(0, 0), fill = c("cornflowerblue", "darkorchid1"), cex = 1, cat.cex = 1.2, cat.pos = c(0, 0), ext.text = FALSE,
        					   main = "Negative", ind = FALSE,
                               cat.dist = 0.01)
        grid.draw(h2)
        grid.text(paste("Up",labels[1],"Down",labels[2]), y = 1)
        dev.off()
    })
  }
  result$hypermat <- hypermat
  return(result)
}

