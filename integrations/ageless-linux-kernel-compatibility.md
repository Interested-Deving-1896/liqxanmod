# Ageless Linux compatibility profile

**Status: inventory-only; compatibility unknown.**

Ageless Linux currently supplies an OS identity/policy conversion tool, not an independently established kernel source line. Its upstream entrypoint is `become-ageless.sh` (version 0.1.1 at the inspected revision); `build.sh` assembles it from `lib/*.sh`. Conversion rewrites OS identity and creates policy files; persistent mode may install a systemd timer/service. Documentation says Debian-based systems are the design/test target but notes it can technically run on other systems with `/etc/os-release`.

## Provider boundary

- Do not add an Ageless kernel branch, patch series, or independent ABI.
- Resolve the underlying base OS from the original pre-conversion identity or trusted image metadata.
- Use LiqXanMod's existing source/kernel/package adapter for that actual base and selected kernel lane.
- Record Ageless conversion-tool provenance separately from kernel source, patch, config, and package provenance.
- Do not infer Debian version, architecture, package manager, or kernel compatibility from `ID=ageless`.

## Required inventory

Record immutable Ageless source commit/tree identity, script version, build inputs, base OS ID/release, architecture, init system, package manager, kernel package/source revision, patch hashes, and configuration hashes. Integrity remains unverified until independently checked.

## Safety

Never execute the privileged conversion script on CI hosts or production systems. Behavioral tests, if added, must use disposable isolated images with no host mounts/secrets and explicit cleanup. Keep this provider in read-only inventory mode; no patch application, build, package publication, or installation.

## References

- https://github.com/agelesslinux/agelesslinux
- https://github.com/agelesslinux/agelesslinux.org
- https://agelesslinux.github.io/
- https://github.com/agelesslinux/store.agelesslinux.org

## Consuming the BDFS compatibility report

BDFS can generate a provider-keyed report from its read-only inventory and this repository's `integrations/ageless-linux-compatibility.json` contract. Consume the generated report with:

```sh
python3 integrations/ageless-linux-report.py --report ageless-provider-compatibility.json --output liqxanmod-ageless-decision.json
```

The adapter verifies the BDFS report schema, provider identity, unknown compatibility status, and disabled conversion/build/install/publish actions. It emits a provider-specific decision artifact only; it does not select a kernel, apply patches, build, install, or certify support. Keep compatibility unknown until isolated tests and independently verified source/package provenance are available.
