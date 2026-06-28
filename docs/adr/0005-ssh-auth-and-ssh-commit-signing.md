# SSH for gh auth and for commit signing; keys stay out of the repo

git/gh authenticate over **SSH**, and commits are signed with the **SSH key**
(`gpg.format = ssh`, `commit.gpgsign = true`) rather than GPG. SSH signing reuses
the key we already have for auth, so GitHub shows "Verified" with near-zero extra
setup and no separate GPG keyring to manage per machine.

## The replication consequence (the reason this is an ADR)
The signing/auth **private key is secret** and must NOT be committed. The repo
therefore stores only the *configuration that references* the key
(`user.signingkey`, an `allowed_signers` file path), not the key itself.
`bootstrap.sh` cannot fully finish git setup unattended: on a new machine the user
must generate/copy the SSH key, add the public key to GitHub (as both an auth key
and a *signing* key), and run `gh auth login`. bootstrap should detect a missing
key and print these steps rather than failing silently.

## Consequences
- A `.gitignore` / repo hygiene rule must guarantee no private keys ever land here.
- `allowed_signers` (public, maps email → public key) can live in the repo; the
  private key cannot.
- Choosing SSH over GPG trades GPG's broader tooling for far simpler per-machine setup.
