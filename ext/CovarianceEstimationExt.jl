module CovarianceEstimationExt

using AxisKeys: KeyedArray, KeyedMatrix, NamedDims, NamedDimsArray, axiskeys, dimnames, keyless_unname, hasnames
using CovarianceEstimation
using CovarianceEstimation: AbstractWeights
using CovarianceEstimation.Statistics

# Since we get ambiguity errors with specific implementations we need to wrap each supported method
# A better approach might be to add `NamedDims` support to CovarianceEstimators.jl in the future.

estimators = [
    :SimpleCovariance,
    :LinearShrinkage,
    :DiagonalUnitVariance,
    :DiagonalCommonVariance,
    :DiagonalUnequalVariance,
    :CommonCovariance,
    :PerfectPositiveCorrelation,
    :ConstantCorrelation,
    :AnalyticalNonlinearShrinkage,
]
for estimator in estimators
    @eval function Statistics.cov(ce::$estimator, A::KeyedMatrix, wv::Vararg{AbstractWeights}; dims=1, kwargs...)
        d = NamedDims.dim(A, dims)
        data = cov(ce, keyless_unname(A), wv...; dims=d, kwargs...)
        L1 = dimnames(A, 3 - d)
        data2 = hasnames(A) ? NamedDimsArray(data, (L1, L1)) : data
        K1 = axiskeys(A, 3 - d)
        KeyedArray(data2, (copy(K1), copy(K1)))
    end
end

end
