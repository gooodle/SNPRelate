#######################################################################
#
# Package name: SNPRelate
#
# Description:
#     A High-performance Computing Toolset for Relatedness and
# Principal Component Analysis of SNP Data
#
# Copyright (C) 2011 - 2022        Xiuwen Zheng
# License: GPL-3
#


#######################################################################
# Identity-by-Descent (IBD) analysis
#######################################################################

#######################################################################
# Calculate the IBD matrix (PLINK method of moment)
#

snpgdsIBDMoM <- function(gdsobj, sample.id=NULL, snp.id=NULL,
    autosome.only=TRUE, remove.monosnp=TRUE, maf=NaN, missing.rate=NaN,
    allele.freq=NULL, kinship=FALSE, kinship.constraint=FALSE, num.thread=1L,
    useMatrix=FALSE, verbose=TRUE)
{
    # check
    ws <- .InitFile2(
        cmd="IBD analysis (PLINK method of moment) on genotypes:",
        gdsobj=gdsobj, sample.id=sample.id, snp.id=snp.id,
        autosome.only=autosome.only, remove.monosnp=remove.monosnp,
        maf=maf, missing.rate=missing.rate, allele.freq=allele.freq,
        num.thread=num.thread,
        verbose=verbose)

    stopifnot(is.logical(kinship), length(kinship)==1L)
    stopifnot(is.logical(kinship.constraint), length(kinship.constraint)==1L)
    stopifnot(is.logical(useMatrix), length(useMatrix)==1L)

    # verbose
    if (verbose & !is.null(ws$allele.freq))
    {
        cat(sprintf("Specifying allele frequencies, mean: %0.3f, sd: %0.3f\n",
            mean(ws$allele.freq, na.rm=TRUE),
            sd(ws$allele.freq, na.rm=TRUE)))
        cat("*** A correction factor based on allele count is not used,",
            "since the allele frequencies are specified.\n")
    }

    # call C function
    rv <- .Call(gnrIBD_PLINK, ws$num.thread, as.double(ws$allele.freq),
        !is.null(ws$allele.freq), kinship.constraint, useMatrix, verbose)
    names(rv) <- c("k0", "k1", "afreq")

    # return
    ans <- list(sample.id=ws$sample.id, snp.id=ws$snp.id, afreq=rv$afreq)
    ans$afreq[ans$afreq < 0] <- NaN
    if (isTRUE(useMatrix))
    {
        ans$k0 <- .newmat(ws$n.samp, rv$k0)
        ans$k1 <- .newmat(ws$n.samp, rv$k1)
    } else {
        ans$k0 <- rv$k0
        ans$k1 <- rv$k1
    }
    if (kinship)
        ans$kinship <- 0.5*(1 - ans$k0 - ans$k1) + 0.25*ans$k1
    class(ans) <- "snpgdsIBDClass"
    return(ans)
}

print.snpgdsIBDClass <- function(x, ...) str(x)


#######################################################################
# Calculate the identity-by-descent (IBD) matrix (MLE)
#

snpgdsIBDMLE <- function(gdsobj, sample.id=NULL, snp.id=NULL,
    autosome.only=TRUE, remove.monosnp=TRUE, maf=NaN, missing.rate=NaN,
    kinship=FALSE, kinship.constraint=FALSE, allele.freq=NULL,
    method=c("EM", "downhill.simplex", "Jacquard"), max.niter=1000L,
    reltol=sqrt(.Machine$double.eps), coeff.correct=TRUE, out.num.iter=TRUE,
    num.thread=1, verbose=TRUE)
{
    # check
    ws <- .InitFile2(
        cmd="Identity-By-Descent analysis (MLE) on genotypes:",
        gdsobj=gdsobj, sample.id=sample.id, snp.id=snp.id,
        autosome.only=autosome.only, remove.monosnp=remove.monosnp,
        maf=maf, missing.rate=missing.rate, allele.freq=allele.freq,
        num.thread=num.thread, verbose=verbose)

    method <- match.arg(method)
    if (method == "EM")
        method <- 0L
    else if (method == "downhill.simplex")
        method <- 1L
    else if (method == "Jacquard")
        method <- 2L
    else
        stop("Invalid MLE method!")

    stopifnot(is.logical(kinship))
    stopifnot(is.logical(kinship.constraint))
    stopifnot(is.numeric(max.niter))
    stopifnot(is.numeric(reltol))
    stopifnot(is.logical(coeff.correct))
    stopifnot(is.logical(out.num.iter))

    # check
    if (verbose & !is.null(ws$allele.freq))
    {
        cat(sprintf("Specifying allele frequencies, mean: %0.3f, sd: %0.3f\n",
            mean(ws$allele.freq, na.rm=TRUE),
            sd(ws$allele.freq, na.rm=TRUE)))
    }

    if (method != 2L)
    {
        # call C function
        rv <- .Call(gnrIBD_MLE, ws$allele.freq,
            as.logical(kinship.constraint), as.integer(max.niter),
            as.double(reltol), as.logical(coeff.correct), method,
            out.num.iter, ws$num.thread, verbose)

        # return
        rv <- list(sample.id=ws$sample.id, snp.id=ws$snp.id, afreq=rv[[3L]],
            k0=rv[[1L]], k1=rv[[2L]], niter=rv[[4L]])
        if (kinship)
            rv$kinship <- 0.5*(1 - rv$k0 - rv$k1) + 0.25*rv$k1
        rv$afreq[rv$afreq < 0] <- NaN
        class(rv) <- "snpgdsIBDClass"

    } else {
        # call C function
        rv <- .Call(gnrIBD_MLE_Jacquard, ws$allele.freq,
            as.integer(max.niter), as.double(reltol),
            as.logical(coeff.correct), method, out.num.iter, ws$num.thread,
            verbose)

        # return
        rv <- list(sample.id=ws$sample.id, snp.id=ws$snp.id, afreq=rv[[9L]],
            D1=rv[[1L]], D2=rv[[2L]], D3=rv[[3L]], D4=rv[[4L]],
            D5=rv[[5L]], D6=rv[[6L]], D7=rv[[7L]], D8=rv[[8L]],
            niter=rv[[10L]])
        if (kinship)
            rv$kinship <- rv$D1 + 0.5*(rv$D3 + rv$D5 + rv$D7) + 0.25*rv$D8
        rv$afreq[rv$afreq < 0] <- NaN
        class(rv) <- "snpgdsIBDClass"
    }

    rv
}



#######################################################################
# Calculate the identity-by-descent (IBD) matrix (MLE)
#

snpgdsIBDMLELogLik <- function(gdsobj, ibdobj, k0=NaN, k1=NaN,
    relatedness=c("", "self", "fullsib", "offspring", "halfsib", "cousin",
    "unrelated"))
{
    # check
    stopifnot(inherits(ibdobj, "snpgdsIBDClass"))
    .InitFile(gdsobj, ibdobj$sample.id, ibdobj$snp.id)

    stopifnot(is.numeric(k0), is.vector(k0), length(k0)==1L)
    stopifnot(is.numeric(k1), is.vector(k1), length(k1)==1L)

    relatedness <- match.arg(relatedness)
    if (relatedness == "self")
    {
        k0 <- 0; k1 <- 0
    } else if (relatedness == "fullsib")
    {
        k0 <- 0.25; k1 <- 0.5
    } else if (relatedness == "offspring")
    {
        k0 <- 0; k1 <- 1
    } else if (relatedness == "halfsib")
    {
        k0 <- 0.5; k1 <- 0.5
    } else if (relatedness == "cousin")
    {
        k0 <- 0.75; k1 <- 0.25
    } else if (relatedness == "unrelated")
    {
        k0 <- 1; k1 <- 0
    }

    # call C function
    if (is.finite(k0) & is.finite(k1))
    {
        .Call(gnrIBD_LogLik_k01, ibdobj$afreq, as.double(k0), as.double(k1))
    } else {
        .Call(gnrIBD_LogLik, ibdobj$afreq, ibdobj$k0, ibdobj$k1)
    }
}



#######################################################################
# To calculate the identity-by-descent (IBD) for a pair of SNP
#   genotypes using MLE
#

snpgdsPairIBD <- function(geno1, geno2, allele.freq,
    method=c("EM", "downhill.simplex", "MoM", "Jacquard"),
    kinship.constraint=FALSE, max.niter=1000L, reltol=sqrt(.Machine$double.eps),
    coeff.correct=TRUE, out.num.iter=TRUE, verbose=TRUE)
{
    # check
    stopifnot(is.vector(geno1) & is.numeric(geno1))
    stopifnot(is.vector(geno2) & is.numeric(geno2))
    stopifnot(is.vector(allele.freq) & is.numeric(allele.freq))
    stopifnot(length(geno1) == length(geno2))
    stopifnot(length(geno1) == length(allele.freq))
    stopifnot(is.logical(kinship.constraint))
    stopifnot(is.logical(coeff.correct))

    # method
    method <- match.arg(method)
    method <- match(method, c("EM", "downhill.simplex", "MoM", "Jacquard"))

    allele.freq[!is.finite(allele.freq)] <- -1
    flag <- (0 <= allele.freq) & (allele.freq <= 1)
    if (sum(flag) < length(geno1))
    {
        if (verbose)
        {
            cat("IBD MLE for", sum(flag), 
                "SNPs in total, after removing loci with",
                "invalid allele frequencies.\n",
            )
        }
        geno1 <- geno1[flag]; geno2 <- geno2[flag]
        allele.freq <- allele.freq[flag]
    }

    # call C code
    rv <- .Call(gnrPairIBD, as.integer(geno1), as.integer(geno2),
        as.double(allele.freq), kinship.constraint, max.niter, reltol,
        coeff.correct, method)

    # return
    if (method != 4L)
    {
        ans <- data.frame(k0=rv[1L], k1=rv[2L], loglik=rv[3L])
        if (out.num.iter) ans$niter <- as.integer(rv[4L])
    } else {
        ans <- data.frame(D1=rv[1L], D2=rv[2L], D3=rv[3L], D4=rv[4L],
            D5=rv[5L], D6=rv[6L], D7=rv[7L], D8=rv[8L], loglik=rv[9L])
        if (out.num.iter) ans$niter <- as.integer(rv[10L])
    }
    ans
}



#######################################################################
# Calculate the identity-by-descent (IBD) matrix (MLE)
#

snpgdsPairIBDMLELogLik <- function(geno1, geno2, allele.freq, k0=NaN, k1=NaN,
    relatedness=c("", "self", "fullsib", "offspring", "halfsib", "cousin",
    "unrelated"), verbose=TRUE)
{
    # check
    stopifnot(is.vector(geno1) & is.numeric(geno1))
    stopifnot(is.vector(geno2) & is.numeric(geno2))
    stopifnot(is.vector(allele.freq) & is.numeric(allele.freq))
    stopifnot(length(geno1) == length(geno2))
    stopifnot(length(geno1) == length(allele.freq))
    stopifnot(is.numeric(k0))
    stopifnot(is.numeric(k1))
    stopifnot(is.character(relatedness))

    allele.freq[!is.finite(allele.freq)] <- -1
    flag <- (0 <= allele.freq) & (allele.freq <= 1)
    if (sum(flag) < length(geno1))
    {
        if (verbose)
        {
            cat("IBD MLE for", sum(flag),
                "SNPs in total, after removing loci with",
                "invalid allele frequencies.\n",
            )
        }
        geno1 <- geno1[flag]; geno2 <- geno2[flag]
        allele.freq <- allele.freq[flag]
    }

    # relatedness
    relatedness <- relatedness[1]
    if (relatedness == "self")
    {
        k0 <- 0; k1 <- 0
    } else if (relatedness == "fullsib")
    {
        k0 <- 0.25; k1 <- 0.5
    } else if (relatedness == "offspring")
    {
        k0 <- 0; k1 <- 1
    } else if (relatedness == "halfsib")
    {
        k0 <- 0.5; k1 <- 0.5
    } else if (relatedness == "cousin")
    {
        k0 <- 0.75; k1 <- 0.25
    } else if (relatedness == "unrelated")
    {
        k0 <- 1; k1 <- 0
    }

    # call C code
    .Call(gnrPairIBDLogLik, as.integer(geno1), as.integer(geno2),
        as.double(allele.freq), as.double(k0), as.double(k1))
}



#######################################################################
# Identity-by-Descent (IBD) analysis using KING robust estimat
#######################################################################

#######################################################################
# Calculate the identity-by-descent (IBD) matrix (KING)
#

snpgdsIBDKING <- function(gdsobj, sample.id=NULL, snp.id=NULL,
    autosome.only=TRUE, remove.monosnp=TRUE, maf=NaN, missing.rate=NaN,
    type=c("KING-robust", "KING-homo"), family.id=NULL,
    num.thread=1L, useMatrix=FALSE, verbose=TRUE)
{
    # check
    ws <- .InitFile2(
        cmd="IBD analysis (KING method of moment) on genotypes:",
        gdsobj=gdsobj, sample.id=sample.id, snp.id=snp.id,
        autosome.only=autosome.only, remove.monosnp=remove.monosnp,
        maf=maf, missing.rate=missing.rate, num.thread=num.thread,
        verbose=verbose)
    stopifnot(is.logical(useMatrix), length(useMatrix)==1L)

    type <- match.arg(type)

    # family
    stopifnot(is.null(family.id) | is.vector(family.id))
    if (!is.null(family.id))
    {
        if (ws$n.samp != length(family.id))
            stop("'length(family.id)' should be the number of samples.")
    }
    if (!is.null(sample.id))
        family.id <- family.id[match(sample.id, ws$sample.id)]

    # family id
    if (is.vector(family.id))
    {
        if (is.character(family.id))
            family.id[family.id == ""] <- NA
        family.id <- as.factor(family.id)
        if (verbose & (type=="KING-robust"))
        {
            .cat("# of families: ", nlevels(family.id),
                ", and within- and between-family relationship ",
                "are estimated differently.")
        }
    } else {
        if (verbose & (type=="KING-robust"))
            cat("No family is specified, and all individuals are treated as singletons.\n")
        family.id <- rep(NA, ws$n.samp)
    }

    if (type == "KING-homo")
    {
        if (verbose)
            cat("Relationship inference in a homogeneous population.\n")

        # call the C function
        v <- .Call(gnrIBD_KING_Homo, ws$num.thread, useMatrix, verbose)
        # output
        rv <- list(sample.id=ws$sample.id, snp.id=ws$snp.id, afreq=NULL)
        if (isTRUE(useMatrix))
        {
            rv$k0 <- .newmat(ws$n.samp, v[[1L]])
            rv$k1 <- .newmat(ws$n.samp, v[[2L]])
        } else {
            rv$k0 <- v[[1L]]
            rv$k1 <- v[[2L]]
        }
    } else if (type == "KING-robust")
    {
        if (verbose)
            cat("Relationship inference in the presence of population stratification.\n")
        # call the C function
        v <- .Call(gnrIBD_KING_Robust, as.integer(family.id),
            ws$num.thread, useMatrix, verbose)
        # output
        rv <- list(sample.id=ws$sample.id, snp.id=ws$snp.id, afreq=NULL)
        if (isTRUE(useMatrix))
        {
            rv$IBS0 <- .newmat(ws$n.samp, v[[1L]])
            rv$kinship <- .newmat(ws$n.samp, v[[2L]])
        } else {
            rv$IBS0 <- v[[1L]]
            rv$kinship <- v[[2L]]
        }
    } else
        stop("Invalid 'type'.")

    # return
    if (!is.null(rv$afreq))
        rv$afreq[rv$afreq < 0] <- NaN
    class(rv) <- "snpgdsIBDClass"
    return(rv)
}




#######################################################################
# Genetic dissimilarity analysis
#######################################################################

#######################################################################
# Calculate the genetic dissimilarity matrix
#

snpgdsDiss <- function(gdsobj, sample.id=NULL, snp.id=NULL, autosome.only=TRUE,
    remove.monosnp=TRUE, maf=NaN, missing.rate=NaN, num.thread=1, verbose=TRUE)
{
    # check
    ws <- .InitFile2(
        cmd="Individual dissimilarity analysis on genotypes:",
        gdsobj=gdsobj, sample.id=sample.id, snp.id=snp.id,
        autosome.only=autosome.only, remove.monosnp=remove.monosnp,
        maf=maf, missing.rate=missing.rate, num.thread=num.thread,
        verbose=verbose)

    # call C function
    d <- .Call(gnrDiss, ws$num.thread, verbose)

    # return
    ans <- list(sample.id=ws$sample.id, snp.id=ws$snp.id, diss=d)
    class(ans) <- "snpgdsDissClass"
    return(ans)
}

print.snpgdsDissClass <- function(x, ...) str(x)


#######################################################################
#
#######################################################################

#######################################################################
# Return a data.frame of pairs of individuals with IBD coefficients
#

snpgdsIBDSelection <- function(ibdobj, kinship.cutoff=NaN, samp.sel=NULL)
{
    # check
    stopifnot(inherits(ibdobj, "snpgdsIBDClass"))
    stopifnot(is.numeric(kinship.cutoff))
    stopifnot(is.null(samp.sel) | is.logical(samp.sel) | is.numeric(samp.sel))
    if (is.logical(samp.sel))
        stopifnot(length(samp.sel) == length(ibdobj$sample.id))

    # the variables in the output
    ns <- setdiff(names(ibdobj), c("sample.id", "snp.id", "afreq"))

    # subset
    if (!is.null(samp.sel))
    {
        ibdobj$sample.id <- ibdobj$sample.id[samp.sel]
        for (i in ns)
            ibdobj[[i]] <- ibdobj[[i]][samp.sel, samp.sel]
    }

    if (is.null(ibdobj$kinship))
    {
        if (!is.null(ibdobj$k0) && !is.null(ibdobj$k1))
        {
            ibdobj$kinship <- (1 - ibdobj$k0 - ibdobj$k1)*0.5 + ibdobj$k1*0.25
            ns <- c(ns, "kinship")
        } else if (!is.null(ibdobj$D1))
        {
            ibdobj$kinship <- ibdobj$D1 +
                0.5*(ibdobj$D3 + ibdobj$D5 + ibdobj$D7) + 0.25*ibdobj$D8
            ns <- c(ns, "kinship")
        } else {
            if (is.finite(kinship.cutoff))
                stop("There is no kinship coefficient.")
        }
    }

    if (is.finite(kinship.cutoff))
    {
        flag <- lower.tri(ibdobj$kinship) & (ibdobj$kinship >= kinship.cutoff)
        flag[is.na(flag)] <- FALSE
    } else {
        flag <- lower.tri(ibdobj$kinship)
    }

    xx <- flag
    if (inherits(flag, "Matrix")) xx <- as.matrix(xx)

    # get indexes
    if (length(xx) > 2147483647)
    {
        # work around long vector
        v <- apply(xx, 2L, function(x) which(x))
        n <- lengths(v)
        i <- which(n > 0L)
        ii <- data.frame(i1=unlist(v[i]), i2=rep(i, times=n[i]))
    } else {
        ii <- which(xx, TRUE)
    }

    # output
    ans <- data.frame(
        ID1 = ibdobj$sample.id[ii[,2L]], ID2 = ibdobj$sample.id[ii[,1L]],
        stringsAsFactors=FALSE)
    for (i in ns)
        ans[[i]] <- ibdobj[[i]][flag]

    ans
}



#######################################################################
# Genetic Relatedness
#######################################################################

#######################################################################
# Genetic relationship matrix (GRM)
#

snpgdsGRM <- function(gdsobj, sample.id=NULL, snp.id=NULL,
    autosome.only=TRUE, remove.monosnp=TRUE, maf=NaN, missing.rate=NaN,
    method=c("GCTA", "Eigenstrat", "EIGMIX", "Weighted", "Corr", "IndivBeta"),
    num.thread=1L, useMatrix=FALSE, out.fn=NULL, out.prec=c("double", "single"),
    out.compress="LZMA_RA", with.id=TRUE, verbose=TRUE)
{
    # check and initialize ...
    method <- match.arg(method)
    mtxt <- method
    if (method == "Weighted")
    {
        method <- "EIGMIX"
        mtxt <- "Weighted GCTA"
    } else if (method == "Corr")
    {
        mtxt <- "Scaled GCTA (correlation)"
    }

    stopifnot(is.logical(useMatrix), length(useMatrix)==1L)
    stopifnot(is.logical(with.id), length(with.id)==1L)
    ws <- .InitFile2(
        cmd=paste("Genetic Relationship Matrix (GRM, ", mtxt, "):", sep=""),
        gdsobj=gdsobj, sample.id=sample.id, snp.id=snp.id,
        autosome.only=autosome.only, remove.monosnp=remove.monosnp,
        maf=maf, missing.rate=missing.rate, num.thread=num.thread,
        verbose=verbose)

    if (!is.null(out.fn))
    {
        # gds output
        stopifnot(is.character(out.fn), length(out.fn)==1L)
        out.prec <- match.arg(out.prec)
        if (out.prec=="single") out.prec <- "float32"
        # create a gds file
        out.gds <- createfn.gds(out.fn)
        on.exit(closefn.gds(out.gds))
        put.attr.gdsn(out.gds$root, "FileFormat", "SNPRELATE_OUTPUT")
        put.attr.gdsn(out.gds$root, "version",
            paste0("SNPRelate_", packageVersion("SNPRelate")))
        add.gdsn(out.gds, "command", c("snpgdsGRM", paste(":method =", method)))
        add.gdsn(out.gds, "sample.id", ws$sample.id, compress=out.compress,
            closezip=TRUE)
        add.gdsn(out.gds, "snp.id", ws$snp.id, compress=out.compress,
            closezip=TRUE)
        sync.gds(out.gds)
        add.gdsn(out.gds, "grm", storage=out.prec, valdim=c(ws$n.samp, 0L),
            compress=out.compress)
    } else
        out.gds <- NULL

    # call GRM C function
    rv <- .Call(gnrGRM, ws$num.thread, method, out.gds, useMatrix, verbose)

    # return
    if (is.null(out.gds))
    {
        if (isTRUE(useMatrix))
            rv <- .newmat(ws$n.samp, rv)
		if (with.id)
		{
			rv <- list(sample.id=ws$sample.id, snp.id=ws$snp.id,
				method=method, grm=rv)
            if (method %in% c("IndivBeta"))
                rv$avg_val <- .Call(gnrGRM_avg_val)
            class(rv) <- "snpgdsGRMClass"
		}
        rv
    } else {
        if (method %in% c("IndivBeta"))
            add.gdsn(out.gds, "avg_val", .Call(gnrGRM_avg_val))
        invisible()
    }
}

print.snpgdsGRMClass <- function(x, ...) str(x)


#######################################################################
# Merge GRMs in the GDS files
#

snpgdsMergeGRM <- function(filelist, out.fn=NULL, out.prec=c("double", "single"),
    out.compress="LZMA_RA", weight=NULL, verbose=TRUE)
{
    # check
    stopifnot(is.character(filelist), length(filelist)>0L)
    stopifnot(is.logical(verbose), length(verbose)==1L)
    stopifnot(is.null(out.fn) || is.character(out.fn))
    stopifnot(is.character(out.compress), length(out.compress)==1L)
    out.prec <- match.arg(out.prec)
    if (out.prec=="single") out.prec <- "float32"
    if (!is.null(weight))
    {
        stopifnot(is.numeric(weight) || is.logical(weight),
            length(weight)==length(filelist))
    }

    # open the existing GDS files
    gdslist <- vector("list", length(filelist))
    on.exit({
        for (i in seq_along(filelist))
        {
            if (!is.null(gdslist[[i]]))
                closefn.gds(gdslist[[i]])
        }
    })
    if (verbose)
        cat("GRM merging:\n")

    for (i in seq_along(filelist))
    {
        gdslist[[i]] <- f <- openfn.gds(filelist[i])
        if (!identical(get.attr.gdsn(f$root)$FileFormat, "SNPRELATE_OUTPUT"))
            stop("'", filelist[i], "' is not valid.")
        if (verbose)
        {
            n <- prod(objdesp.gdsn(index.gdsn(f, "snp.id"))$dim)
            .cat("    open '", filelist[i], "' (", prettyNum(n, ","), " variants)")
        }
    }

    # check the existing GDS files
    sampid <- read.gdsn(index.gdsn(gdslist[[1L]], "sample.id"))
    dm <- objdesp.gdsn(index.gdsn(gdslist[[1L]], "grm"))$dim
    if (length(dm)!=2L || dm[1L]!=dm[2L])
        stop("'", filelist[i], "' has an invalid GRM matrix.")
    cmd <- read.gdsn(index.gdsn(gdslist[[1L]], "command"))
    if (cmd[1L] != "snpgdsGRM")
        stop("The GDS files should be created by snpgdsGRM()")
    for (i in seq_along(filelist))
    {
        f <- gdslist[[i]]
        if (!identical(read.gdsn(index.gdsn(f, "command")), cmd))
            stop("'", filelist[i], "' has a different command.")
        if (!identical(objdesp.gdsn(index.gdsn(f, "grm"))$dim, dm))
            stop("'", filelist[i], "' has a different GRM matrix.")
    }

    # weights
    if (is.null(weight) | is.logical(weight))
    {
        num <- sapply(gdslist, function(f)
            prod(objdesp.gdsn(index.gdsn(f, "snp.id"))$dim))
        if (is.logical(weight))
            num[!weight] <- -num[!weight]
        weight <- num / sum(num)
    }
    if (verbose)
        .cat("Weight: ", paste(sprintf("%g", weight), collapse=", "))

    if (!is.null(out.fn))
    {
        # create an output GDS file
        out.gds <- createfn.gds(out.fn)
        on.exit(closefn.gds(out.gds), add=TRUE)
        if (verbose)
            cat("Output: ", out.fn, "\n", sep="")
        put.attr.gdsn(out.gds$root, "FileFormat", "SNPRELATE_OUTPUT")
        put.attr.gdsn(out.gds$root, "version",
            paste0("SNPRelate_", packageVersion("SNPRelate")))
        add.gdsn(out.gds, "command", cmd)
        add.gdsn(out.gds, "sample.id", sampid, compress=out.compress,
            closezip=TRUE)
    } else {
        out.gds <- NULL
    }

    # snp.id
    sid <- NULL
    for (i in seq_along(filelist))
    {
        s <- read.gdsn(index.gdsn(gdslist[[i]], "snp.id"))
        if (weight[i] >= 0)
            sid <- c(sid, s)
        else
            sid <- setdiff(sid, s)
    }
    if (!is.null(out.gds))
    {
        add.gdsn(out.gds, "snp.id", sid, compress=out.compress, closezip=TRUE)
        sync.gds(out.gds)
        rm(sid, s)
    }

    # GRM matrix
    if (!is.null(out.gds))
    {
        add.gdsn(out.gds, "grm", storage=out.prec, valdim=c(length(sampid), 0L),
            compress=out.compress)
    }

    # call C
    rv <- .Call(gnrGRMMerge, out.gds, gdslist, cmd[-1L], weight, verbose)

    if (is.null(out.gds))
    {
        rv <- list(sample.id=sampid, snp.id=sid, grm=rv)
        if (cmd[2L] %in% c(":method = IndivBeta"))
            rv$avg_val <- .Call(gnrGRM_avg_val)
        rv
    } else {
        if (cmd[2L] %in% c(":method = IndivBeta"))
            add.gdsn(out.gds, "avg_val", .Call(gnrGRM_avg_val))
        invisible()
    }
}



#######################################################################
# F_st estimation
#

.paramFst <- function(sample.id, population, method=c("W&C84", "W&H02"), ws)
{
    method <- match.arg(method)
    stopifnot(is.factor(population))

    if (is.null(sample.id))
    {
        if (length(population) != ws$n.samp)
        {
            stop("The length of 'population' should be the number of samples ",
                "in the GDS file.")
        }
    } else {
        if (length(population) != length(sample.id))
        {
            stop("The length of 'population' should be the same as ",
                "the length of 'sample.id'.")
        }
        population <- population[match(ws$sample.id, sample.id)]
    }
    if (anyNA(population))
        stop("'population' should not have missing values!")
    if (nlevels(population) <= 1L)
        stop("There should be at least two populations!")
    if (any(table(population) < 1L))
        stop("Each population should have at least one individual.")

    if (ws$verbose)
    {
        if (method == "W&C84")
            cat("Method: Weir & Cockerham, 1984\n")
        else
            cat("Method: Weir & Hill, 2002\n")
        x <- table(population)
        .cat("# of Populations: ", nlevels(population), "\n    ",
            paste(sprintf("%s (%d)", names(x), x), collapse=", "))
    }

    list(population=population, npop=nlevels(population), method=method)
}

snpgdsFst <- function(gdsobj, population, method=c("W&C84", "W&H02"),
    sample.id=NULL, snp.id=NULL, autosome.only=TRUE, remove.monosnp=TRUE,
    maf=NaN, missing.rate=NaN, with.id=FALSE, verbose=TRUE)
{
    # check
    ws <- .InitFile2(
        cmd="Fst estimation on genotypes:",
        gdsobj=gdsobj, sample.id=sample.id, snp.id=snp.id,
        autosome.only=autosome.only, remove.monosnp=remove.monosnp,
        maf=maf, missing.rate=missing.rate, num.thread=1L,
        verbose=verbose, verbose.numthread=FALSE)

    # check
    v <- .paramFst(sample.id, population, method, ws)

    # call C function
    d <- .Call(gnrFst, v$population, v$npop, v$method)

    # return
    if (with.id)
        rv <- list(sample.id=ws$sample.id, snp.id=ws$snp.id)
    else
        rv <- list()
    rv$Fst <- d[[1L]]
    rv$MeanFst <- mean(d[[2L]], na.rm=TRUE)
    rv$FstSNP <- d[[2L]]
    if (method == "W&H02")
    {
        rv$Beta <- d[[3L]]
        colnames(rv$Beta) <- rownames(rv$Beta) <- levels(population)
    }

    rv
}



#######################################################################
# Individual inbreeding and relatedness (beta)
#

snpgdsIndivBeta <- function(gdsobj, sample.id=NULL, snp.id=NULL,
    autosome.only=TRUE, remove.monosnp=TRUE, maf=NaN, missing.rate=NaN,
    method=c("weighted"), inbreeding=TRUE, num.thread=1L, with.id=TRUE,
    useMatrix=FALSE, verbose=TRUE)
{
    # check and initialize ...
    method <- match.arg(method)
    ws <- .InitFile2(
        cmd="Individual Inbreeding and Relatedness (beta estimator):",
        gdsobj=gdsobj, sample.id=sample.id, snp.id=snp.id,
        autosome.only=autosome.only, remove.monosnp=remove.monosnp,
        maf=maf, missing.rate=missing.rate, num.thread=num.thread,
        verbose=verbose)
    stopifnot(is.logical(with.id), length(with.id)==1L)
    stopifnot(is.logical(useMatrix), length(useMatrix)==1L)

    # call GRM C function
    rv <- .Call(gnrIBD_Beta, inbreeding, ws$num.thread, useMatrix, verbose)
    if (isTRUE(useMatrix))
        rv <- .newmat(ws$n.samp, rv)

    # return
    if (isTRUE(with.id))
    {
        rv <- list(sample.id=ws$sample.id, snp.id=ws$snp.id,
            inbreeding=inbreeding, beta=rv, avg_val=.Call(gnrGRM_avg_val))
    }
    return(rv)
}


snpgdsIndivBetaRel <- function(beta, beta_rel, verbose=TRUE)
{
    # check
    stopifnot(is.numeric(beta_rel), length(beta_rel)==1L)
    stopifnot(is.logical(verbose), length(verbose)==1L)
    if (is.list(beta))
    {
        if (!all(c("sample.id", "snp.id", "beta", "inbreeding") %in% names(beta)))
            stop("'beta' should be the object returned from snpgdsIndivBeta() or snpgdsGRM()")
        mat <- beta$beta
        if (!beta$inbreeding)
            diag(mat) <- (diag(mat) - 0.5) * 2
    }

    mat <- (mat - beta_rel) / (1 - beta_rel)
    diag(mat) <- 0.5*diag(mat) + 0.5

    # return
    rv <- list(sample.id=beta$sample.id, snp.id=beta$snp.id, inbreeding=FALSE)
    rv$beta <- mat
    return(rv)
}
