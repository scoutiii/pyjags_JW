import pyjags, numpy as np, sys, time

print("pyjags:", pyjags.__version__, "| python:", sys.version.split()[0])

# Bigger model: hierarchical normal with 3 groups and 500 observations per group
model_code = """
model {
    for (i in 1:N) {
        y[i] ~ dnorm(mu[group[i]], tau)
    }
    for (j in 1:J) {
        mu[j] ~ dnorm(mu0, tau_mu)
    }
    mu0 ~ dnorm(0, 1.0E-6)
    tau_mu ~ dgamma(1, 1)
    tau ~ dgamma(1, 1)
}
"""

# Generate data
rng = np.random.default_rng(42)
J, n_per_group = 3, 500
group = np.repeat(np.arange(J) + 1, n_per_group)
mu_true = np.array([1.0, 2.0, 3.0])
y = rng.normal(mu_true[group - 1], 0.5)

data = dict(y=y, group=group, N=len(y), J=J)

# Build and sample
start = time.time()
m = pyjags.Model(code=model_code, data=data, chains=4, adapt=2000)
s = m.sample(5000, vars=["mu", "mu0", "tau"])
elapsed = time.time() - start

print(f"Elapsed: {elapsed:0.2f}s")
print("Posterior means:")
print("mu:", np.mean(s["mu"], axis=(1, 2)))
print("mu0:", np.mean(s["mu0"]))
