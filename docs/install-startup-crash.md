# Install crash: stripped bundled Debian archive — 1.5.1 (43)

The supplied 1.5.0 (40) report captures `EXC_BREAKPOINT` / `SIGTRAP` on a
cooperative worker, with Foundation `Data._Representation.subscript.getter`
and `Data.subdata(in:)` at the top. This is a checked data-range trap, not the
audio exception proposed before the report arrived. The audio candidate has
been removed from this PR.

The executable in manual test release `test-42727952469-1` has UUID
`130b5ef6-54aa-3372-b46e-6ae3f3bfd9d1`, exactly matching the report. Its stripped
Swift symbols cannot provide ordinary function-name symbolication. Disassembly
of the matching first app caller at return address `0x41840` shows a range
constructed from member offset + 60 and declared size, then a call to
`Data.subdata(in:)`. The enclosing function's header-field offsets, numeric
conversions, error-string constants and result layout match `AR._getFileInfo`.
The next app frame at `0x40838` calls it from the archive's member loop.

The saved registers retain member offset 552 and size 113820: after removing
the eight-byte magic, the parser requests `612..<114432` from 114428 bytes.
The bundled `ellekit.deb` from that exact IPA has precisely that final member
offset, declared length and four-byte shortfall. The official main 1.5.0 IPA
also contains the malformed archive. This establishes the captured failure;
it does not prove every tester has the same failure or that device behavior is
already repaired.

The source package is a valid 114288-byte common-ar Debian archive, SHA256
`588ad56c5de5585ca2d66e385cc8f25b4c1d77d5e8fc52baec6d69cb3fa3343d`.
Both built packages are 114436 bytes and have been rewritten into BSD-style
`#1/20` members, with the final member declaring four unavailable bytes.
The retained build log explicitly shows Xcode's resource copy invoking:

```text
strip -D -S -no_atom_info Feather/Resources/ellekit.deb -o .../Feather.app/ellekit.deb
```

Release `COPY_PHASE_STRIP` was enabled. Apple's
[build-settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference)
documents that it strips binary files during resource-copy phases. Debian's
[format specification](https://manpages.debian.org/bookworm/dpkg-dev/deb.5.en.html)
requires common ar names, optionally ending in a slash, without long-name
extensions. The reader runs during tweak injection when saved injection options
need ElleKit, which the one-tap Install path also executes.
The user subsequently confirmed that ElleKit was enabled.

The repair disables stripping during copied-resource phases while retaining
the existing executable stripping settings. The Makefile checks the copied
ElleKit against source before packaging. Before any manual draft or public
release delivery, the workflow checks the final IPA's archive bytes against
source and runs the actual Swift reader on both source and packaged copies.
An absent, altered or duplicate bundled archive blocks delivery.

The reader now throws for unreadable files, short magic/headers/content,
invalid numeric fields or header trailers, unsupported names and missing odd
padding. It checks the remaining length before adding sizes or creating data
ranges, removes forced reads/conversions, accepts valid zero-length members
and normalizes the common-ar optional name slash. Malformed imported tweaks
return a readable error through the existing Install failure path. Injection
options and the original imported apps are preserved.

`Tools/test-ar-decompression.py` compiles the production parser and model with
the real Swift Foundation runtime in both `-Onone` and `-O`. Eight regression
groups cover the real bundled archive, valid metadata/odd/empty members,
short headers, the exact captured four-byte overread, malformed numbers,
invalid names/trailers/padding, exhaustive fixture truncation and unreadable
files. Existing signing, import, certificate, one-tap progress and IPA checks
remain mandatory, as do the 45-minute limit and draft/manual versus public/main
publication conditions.

Manual test build 43065067736 at 4341fc8 passed all native checks, the physical
Release build and final-IPA verification. Both optimized and unoptimized reader
regressions passed against the source and actual packaged ElleKit. The user
tested with ElleKit enabled, reported everything working and approved merging
and distribution. This confirms their tested route, not every device or input.

At the user's request, 1.5.1 (43) enables ElleKit in the default signing options
for fresh settings and Reset to Defaults. Existing saved options still decode
and retain the user's choice. The release build must pass the same mandatory
checks before its IPA is distributed.
