# The forms vendor/grado-factorio-tools/scripts/pin-measure.ps1 runs at the old pin and the new
# when the tools pin moves (#784). Its shape, and what each placeholder becomes, is in that
# script's header (grado-factorio-tools#247). It reads this file from its clones of GitHub's main,
# so a change here measures nothing until it is merged.
#
# One form for each way .githooks/ and .github/workflows/gates.yml run a tools script, the
# -SelfTest of every tools script this repository runs or loads (grado-factorio-tools#318, ruling
# 3), and each script of this repository's own that a gate runs and that reaches into vendor/.
# The pull request body rule in docs/agents/issue-tracker.md runs pr-body-check.ps1 on a file, and
# no placeholder gives a form a file holding a body, so that way is not measured: the -Body form
# below is gates.yml's. Four forms start the game and need Factorio where the harness finds it.
# On 2026-11-14 each took 14 to 73 s at a pin, and a run of the 16 forms then listed took 22
# minutes.
@{
    Forms = @(
        # .githooks/commit-msg hands it the message file; gates.yml runs it over the event's range.
        @{ Name = 'commit-check-selftest'; From = 'tools'; Script = 'commit-check.ps1'; Args = @('-SelfTest') }
        @{ Name = 'commit-check-hook'; From = 'tools'; Script = 'commit-check.ps1'; Args = @('{headmsg}') }
        @{ Name = 'commit-check-range'; From = 'tools'; Script = 'commit-check.ps1'; Args = @('-Range', 'HEAD~20..HEAD') }
        # .githooks/pre-commit runs it bare on the staged files: the clone's index matches HEAD, so
        # it reads none. scripts/ship-check.ps1 runs it with -All.
        @{ Name = 'markdown-check-selftest'; From = 'tools'; Script = 'markdown-check.ps1'; Args = @('-SelfTest') }
        @{ Name = 'markdown-check-hook'; From = 'tools'; Script = 'markdown-check.ps1'; Args = @() }
        # A clone's vendor/grado-factorio-tools holds scripts/ alone, so the two links this
        # repository has into the submodule's docs/ fail at both pins, here and in
        # ship-check-selftest below.
        @{ Name = 'markdown-check-all'; From = 'tools'; Script = 'markdown-check.ps1'; Args = @('-All') }
        # gates.yml runs both; the body form once for each of the last two merged pull requests.
        @{ Name = 'pr-body-check-selftest'; From = 'tools'; Script = 'pr-body-check.ps1'; Args = @('-SelfTest') }
        @{ Name = 'pr-body-check-body'; From = 'tools'; Script = 'pr-body-check.ps1'; Args = @('-Body', '{prbody:last-merged:2}') }
        # load-check.ps1 -FromZips builds the zips with it (docs/agents/shipping.md).
        @{ Name = 'pack-mods-selftest'; From = 'tools'; Script = 'pack-mods.ps1'; Args = @('-SelfTest') }
        # Every check that needs a third-party set is fed by it, from scripts/mod-sets.psd1, whose
        # lanes -PinFile certifies. Loopback only.
        @{ Name = 'fetch-mods-selftest'; From = 'tools'; Script = 'fetch-mods.ps1'; Args = @('-SelfTest', '-PinFile', 'scripts/mod-sets.psd1') }
        # Run by hand before anything ships (docs/agents/shipping.md). Starts the game.
        @{ Name = 'locale-check-selftest'; From = 'tools'; Script = 'locale-check.ps1'; Args = @('-SelfTest') }
        # The tech-tree viewer .gitignore and docs/research/tree-layout-levers.md name. Starts the
        # game.
        @{ Name = 'tree-viewer-selftest'; From = 'tools'; Script = 'tree-viewer.ps1'; Args = @('-SelfTest') }
        # load-harness-lib.ps1 has no -SelfTest. Run as a file it only defines its functions, so
        # this form proves no more than that it parses; load-check-fromzips below is what runs it.
        @{ Name = 'load-harness-lib'; From = 'tools'; Script = 'load-harness-lib.ps1'; Args = @() }
        # load-harness-lib.ps1 dot-sources both, and pack-mods.ps1 mod-info.ps1.
        @{ Name = 'mod-info-selftest'; From = 'tools'; Script = 'mod-info.ps1'; Args = @('-SelfTest') }
        @{ Name = 'self-test-halves-selftest'; From = 'tools'; Script = 'self-test-halves.ps1'; Args = @('-SelfTest') }
        # The script that reads this file.
        @{ Name = 'pin-measure-selftest'; From = 'tools'; Script = 'pin-measure.ps1'; Args = @('-SelfTest') }
        # This repository's scripts that reach into vendor/. ship-check.ps1 runs markdown-check.ps1
        # and the shared -SelfTest runner. Its -SelfTest runs every check first and exits before its
        # halves when any fails, and in a clone the markdown check fails, as above, so this form
        # measures the checks and none of the halves.
        @{ Name = 'ship-check-selftest'; From = 'sibling'; Script = 'scripts/ship-check.ps1'; Args = @('-SelfTest') }
        # load-check.ps1 loads through scripts/factorio-lib.ps1, which dot-sources
        # load-harness-lib.ps1, and with -FromZips packs with pack-mods.ps1. Starts the game.
        @{ Name = 'load-check-fromzips'; From = 'sibling'; Script = 'scripts/load-check.ps1'; Args = @('-FromZips') }
        # Every scripts/check-*.ps1 sources factorio-lib.ps1 as load-check.ps1 does; one stands for
        # them. Starts the game.
        @{ Name = 'check-pooling'; From = 'sibling'; Script = 'scripts/check-pooling.ps1'; Args = @() }
    )
}
