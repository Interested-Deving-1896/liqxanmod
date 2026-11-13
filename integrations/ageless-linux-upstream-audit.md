# Ageless Linux upstream provenance and safety note

Audited Ageless upstream revision: `1e1b00f45d494a41412403e9e909b0cc737bc2ae` (tree `71591363ccff54a7a0cfbeffbdc7fd36b087f523`). GitHub reports the commit as unsigned/unverified. Blob identifiers are recorded in the BDFS source audit; an immutable SHA is not a cryptographic trust assertion.

The upstream conversion tool requires root for conversion and mutates `/etc/os-release`, may modify `/etc/lsb-release`, writes policy/compliance files and installation metadata, may alter `/etc/userdb/`, and can install/enable a systemd service/timer in persistent mode. It is not a kernel source provider.

The upstream container test harness runs as root and performs real writes/removals in the container's `/etc`. Its documented Docker invocation does not itself enforce a read-only source mount, disabled networking, dropped capabilities, no-new-privileges, or disposable root filesystem. Do not run it on a CI host or shared container. Any future test integration must enforce those protections externally and guarantee teardown.

Provider-specific rules:
Use the actual detected base OS and selected LiqXanMod lane. Do not infer kernel compatibility from the converted OS ID.

Keep compatibility unknown until the underlying base OS/release/architecture is independently identified and tested. Preserve Ageless converter provenance separately from kernel source, patch, config, signing, and package provenance. No conversion, patch application, kernel build, install, or publication is enabled by this document.
