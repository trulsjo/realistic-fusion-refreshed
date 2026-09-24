# The pinned third-party mod sets the coexistence lanes load (ADR 0007, ADR 0026).
#
# Read by the shared fetcher, vendor/grado-factorio-tools/scripts/fetch-mods.ps1, as its -PinFile
# (#456). The pins lived inside this repository's own copy of that script until it moved to the
# tooling repo; they are this repository's version decisions, not the fetcher's machinery, so they
# stayed here. Run from the repository root, so the cache lands in .mod-cache/<set>:
#
#     pwsh -File vendor/grado-factorio-tools/scripts/fetch-mods.ps1 -PinFile scripts/mod-sets.psd1 -Set krastorio2
#
# THESE ARE VERSION DECISIONS, NOT MACHINERY, and #60 said so in as many words: "build the pin as a
# parameter and the answer fills it in later". #59 filled it in (ADR 0026): every family is pinned
# to its last factorio_version 2.0 release, because 2.1 is still the experimental branch and this
# repo still declares 2.0. Editing a number here is meant to be the whole job.
#
# DERIVED, NOT TRANSCRIBED. Each closure was computed from the portal API at the last fv 2.0
# release of every member, following no-prefix and `~` dependencies and ignoring `?`, `(?)`, `!`
# and `+`. Refreshing these means re-deriving them, which is also what happens when ADR 0008's
# trigger fires and the whole manifest re-points at the 2.1 releases.
#
# A PASSING LANE PROVES COEXISTENCE WITH THAT FAMILY'S 2.0 LINE AND NOTHING ELSE. ADR 0026 forbids
# an unqualified "works with Angel's" reaching a listing or a README on the strength of one.
#
# The Krastorio 2 set is FIVE mods and not the four #60's acceptance criteria list. At 2.0.19 --
# the last factorio_version 2.0 release, and the only K2 that loads beside this repo on 2.0.77 --
# Krastorio2's info.json declares `ChangeInserterDropLane >= 1.1.0` with NO PREFIX, which in
# Factorio's dependency syntax is a hard requirement (`?` optional, `(?)` hidden optional, `!`
# incompatible, `~` required but not load-order-affecting, bare = required). Fetching four would
# fail at load on a missing dependency. docs/research/mod-set-coexistence-targets.md records the
# same five, loaded rather than merely computed, and notes it is untrue of the 2.1 line.
#
# Tag defaults to 'v' + Version, which is what all five publish. Give an explicit Tag when it isn't.
@{
    Default = 'krastorio2'

    Sets = @{
        krastorio2 = @(
            @{ Name = 'ChangeInserterDropLane';    Version = '1.2.0';  Git = 'https://codeberg.org/raiguard/ChangeInserterDropLane.git' }
            @{ Name = 'flib';                      Version = '0.16.2'; Git = 'https://github.com/factoriolib/flib.git' }
            @{ Name = 'Krastorio2';                Version = '2.0.19'; Git = 'https://codeberg.org/raiguard/Krastorio2.git' }
            @{ Name = 'Krastorio2Assets';          Version = '2.0.5';  Git = 'https://codeberg.org/raiguard/Krastorio2Assets.git' }
            @{ Name = 'Krastorio2MenuSimulations'; Version = '2.0.2';  Git = 'https://codeberg.org/raiguard/Krastorio2MenuSimulations.git' }
        )


        # Angel's -- the four content mods and the four graphics mods they declare `~`, which is a
        # HARD requirement that only waives load order. Missing them looks optional and is not.
        angels = @(
            @{ Name = 'angelsbioprocessing';        Version = '2.0.3' }
            @{ Name = 'angelsbioprocessinggraphics'; Version = '2.0.0' }
            @{ Name = 'angelspetrochem';            Version = '2.0.3' }
            @{ Name = 'angelspetrochemgraphics';    Version = '2.0.1' }
            @{ Name = 'angelsrefining';             Version = '2.0.4' }
            @{ Name = 'angelsrefininggraphics';     Version = '2.0.0' }
            @{ Name = 'angelssmelting';             Version = '2.0.5' }
            @{ Name = 'angelssmeltinggraphics';     Version = '2.0.0' }
        )

        # Bob's. THE VERSION NUMBERS LIE HERE: Bob's 2.1.x is a factorio_version 2.0 mod and Bob's
        # 3.0.x is the 2.1 one. The mod's own numbering and the game's major version move
        # independently and happen to collide.
        bobs = @(
            @{ Name = 'bobassembly';   Version = '2.1.0' }
            @{ Name = 'bobelectronics'; Version = '2.1.1' }
            @{ Name = 'bobinserters';  Version = '2.0.3' }
            @{ Name = 'boblibrary';    Version = '2.1.0' }
            @{ Name = 'boblogistics';  Version = '2.1.1' }
            @{ Name = 'bobmodules';    Version = '2.1.0' }
            @{ Name = 'bobores';       Version = '2.1.2' }
            @{ Name = 'bobplates';     Version = '2.1.1' }
            @{ Name = 'bobpower';      Version = '2.1.0' }
            @{ Name = 'bobrevamp';     Version = '2.1.1' }
            @{ Name = 'bobtech';       Version = '2.1.0' }
            @{ Name = 'bobwarfare';    Version = '2.1.0' }
        )

        # MadClown's. Four of five Clowns mods are alive and `Clowns-Science` is factorio_version
        # 1.1 ONLY, so this lane is incomplete at any version -- not a pinning artefact. The six
        # Angel's mods are Clowns-Processing's own hard requirements.
        madclowns = @(
            @{ Name = 'angelspetrochem';        Version = '2.0.3' }
            @{ Name = 'angelspetrochemgraphics'; Version = '2.0.1' }
            @{ Name = 'angelsrefining';         Version = '2.0.4' }
            @{ Name = 'angelsrefininggraphics'; Version = '2.0.0' }
            @{ Name = 'angelssmelting';         Version = '2.0.5' }
            @{ Name = 'angelssmeltinggraphics'; Version = '2.0.0' }
            @{ Name = 'Clowns-Processing';      Version = '2.0.14' }
        )

        # Space Exploration. Five deliberately large graphics mods, which is most of the download.
        # SE declares `!` against Space Age and against fourteen Angel's and Bob's mods, so this
        # lane can never be combined with those.
        spaceex = @(
            @{ Name = 'aai-containers';                    Version = '0.3.2' }
            @{ Name = 'aai-industry';                      Version = '0.6.16' }
            @{ Name = 'aai-signal-transmission';           Version = '0.5.3' }
            @{ Name = 'alien-biomes';                      Version = '0.7.4' }
            @{ Name = 'alien-biomes-graphics';             Version = '0.7.1' }
            @{ Name = 'informatron';                       Version = '0.4.0' }
            @{ Name = 'jetpack';                           Version = '0.4.17' }
            @{ Name = 'robot_attrition';                   Version = '0.6.6' }
            @{ Name = 'shield-projector';                  Version = '0.2.2' }
            @{ Name = 'space-exploration';                 Version = '0.7.57' }
            @{ Name = 'space-exploration-graphics';        Version = '0.7.5' }
            @{ Name = 'space-exploration-graphics-2';      Version = '0.7.2' }
            @{ Name = 'space-exploration-graphics-3';      Version = '0.7.2' }
            @{ Name = 'space-exploration-graphics-4';      Version = '0.7.2' }
            @{ Name = 'space-exploration-graphics-5';      Version = '0.7.3' }
            @{ Name = 'space-exploration-menu-simulations'; Version = '0.7.4' }
            @{ Name = 'space-exploration-postprocess';     Version = '0.7.5' }
        )

        # SeaBlock NG, AS INTENDED RATHER THAN AS ENFORCED -- Truls's call, 2026-08-26 (ADR 0026).
        #
        # CORRECTED 2026-08-26: this comment used to say SeaBlockWanne declares SeaBlockPack with `+`.
        # It does not, at the version pinned here. SeaBlockWanne 1.0.5 names no SeaBlockPack at all --
        # its hard requirements are the four Angel's content mods and nothing else, a closure of nine.
        # The `+ SeaBlockPack` line appears first in 1.1.4, which is factorio_version 2.1 and therefore
        # a release this project does not target. At 2.0 the dependency runs the other way: SeaBlockPack
        # requires SeaBlockWanne.
        #
        # So the pack is pinned as a DELIBERATE CHOICE and not because a dependency asks for it: the
        # lane is worth more answering "does our mod load beside what a SeaBlock player installs" than
        # "beside the nine mods that strictly must load". The choice stands; the reason it was first
        # given was a 2.1 fact read onto a 2.0 pin.
        #
        # TWO THINGS THIS LANE NEEDS THAT NO OTHER DOES. It requires `quality`, which ships with
        # the game rather than the portal, so run load-check with -With quality; quality does not
        # pull in space-age, which matters because SeaBlockWanne declares `! space-age`. And it
        # overlaps the angels and bobs lanes -- twenty of their mods are hard requirements here,
        # so the three sets are not independent samples.
        seablock = @(
            @{ Name = 'angelsaddons-storage';             Version = '2.0.1' }
            @{ Name = 'angelsbioprocessing';              Version = '2.0.3' }
            @{ Name = 'angelsbioprocessinggraphics';      Version = '2.0.0' }
            @{ Name = 'angelspetrochem';                  Version = '2.0.3' }
            @{ Name = 'angelspetrochemgraphics';          Version = '2.0.1' }
            @{ Name = 'angelsrefining';                   Version = '2.0.4' }
            @{ Name = 'angelsrefininggraphics';           Version = '2.0.0' }
            @{ Name = 'angelssmelting';                   Version = '2.0.5' }
            @{ Name = 'angelssmeltinggraphics';           Version = '2.0.0' }
            @{ Name = 'bobassembly';                      Version = '2.1.0' }
            @{ Name = 'bobelectronics';                   Version = '2.1.1' }
            @{ Name = 'bobequipment';                     Version = '2.1.0' }
            @{ Name = 'bobinserters';                     Version = '2.0.3' }
            @{ Name = 'boblibrary';                       Version = '2.1.0' }
            @{ Name = 'boblogistics';                     Version = '2.1.1' }
            @{ Name = 'bobmodules';                       Version = '2.1.0' }
            @{ Name = 'bobores';                          Version = '2.1.2' }
            @{ Name = 'bobplates';                        Version = '2.1.1' }
            @{ Name = 'bobpower';                         Version = '2.1.0' }
            @{ Name = 'bobrevamp';                        Version = '2.1.1' }
            @{ Name = 'bobtech';                          Version = '2.1.0' }
            @{ Name = 'bobvehicleequipment';              Version = '2.1.1' }
            @{ Name = 'cargo-ships';                      Version = '1.0.33' }
            @{ Name = 'cargo-ships-graphics';             Version = '1.0.5' }
            @{ Name = 'configurable-pollution-absorption'; Version = '1.0.1' }
            @{ Name = 'even-distribution';                Version = '2.0.2' }
            @{ Name = 'FactorySearch';                    Version = '1.14.3' }
            @{ Name = 'flib';                             Version = '0.16.5' }
            @{ Name = 'helmod';                           Version = '2.2.14' }
            @{ Name = 'inventory-repair';                 Version = '20.0.3' }
            @{ Name = 'KS_Power';                         Version = '2.0.0' }
            @{ Name = 'loaders-modernized';               Version = '2.0.13' }
            @{ Name = 'nicefill-scriptfix';               Version = '1.1.2' }
            @{ Name = 'no_placement_restriction';         Version = '1.0.0' }
            @{ Name = 'no-pipe-touching';                 Version = '1.1.28' }
            @{ Name = 'QueueToFrontLimited';              Version = '2.0.3' }
            @{ Name = 'RecursiveResourceCalculator';      Version = '1.1.9' }
            @{ Name = 'saplib';                           Version = '0.0.3' }
            @{ Name = 'ScienceCostTweakerM';              Version = '2.0.4' }
            @{ Name = 'SeaBlockPack';                     Version = '1.0.1' }
            @{ Name = 'SeaBlockWanne';                    Version = '1.0.5' }
            @{ Name = 'shortwave_fix';                    Version = '0.5.2' }
            @{ Name = 'squeak-through-2';                 Version = '0.1.5' }
            @{ Name = 'stack-inserters';                  Version = '1.0.1' }
            @{ Name = 'TurboBelt';                        Version = '1.1.0' }
            @{ Name = 'wood-to-landfill-spaceage';        Version = '1.0.2' }
        )

        # RITEG. factorio_version 2.0 only -- it never got a 2.1 release, so this is the one lane
        # that a move to 2.1 would drop rather than re-pin.
        riteg = @(
            @{ Name = 'RITEG'; Version = '1.3.11' }
        )

        # Advanced Fluid Handling. The portal slug is not the display name.
        fluid = @(
            @{ Name = 'underground-pipe-pack'; Version = '2.0.6' }
        )

        # Durikkan's Realistic Fusion Power Port (#450) -- the one published 2.0 port of the mod this
        # project descends from. 1.9.2 declares `base >= 2.0` and nothing else, so it is one mod. No
        # source repository, so it takes the portal route.
        'rfp-port' = @(
            @{ Name = 'RealisticFusionPowerPort'; Version = '1.9.2' }
        )

        # Starlark's SE add-on for the port (#451). It requires both the port and SE, so it is never
        # loaded alone; it is a family only so the lane below composes it instead of restating it.
        'rfp-se-compat' = @(
            @{ Name = 'RealisticFusionPowerPort-SE-Compat'; Version = '1.0.0' }
        )

        # solar138's SE fork of the port (#452). It declares `! RealisticFusionPowerPort`, so it and
        # 'rfp-port' can never share a lane -- ADR 0007 records that combination as closed.
        'rfp-port-se' = @(
            @{ Name = 'RealisticFusionPowerPortSE'; Version = '1.0.1' }
        )
    }

    # The combination lanes -- COMPOSED, NOT TRANSCRIBED.
    #
    # #61's table asks for three sets that are not families but unions of them, and #451 and #452 add two
    # more. They are built from the
    # family sets above rather than written out again, so a pin lives in exactly one place: refreshing
    # a family refreshes every lane it appears in, and there is no second copy to forget.
    #
    # WHY EACH ONE IS A LANE AT ALL.
    #   k2-spaceex             SE declares `(?) Krastorio2 >= 2.0.10` -- a hidden optional dependency,
    #                          so SE ships K2-aware code and loads after K2 when it is present. The
    #                          pair therefore exercises interop paths NEITHER mod runs alone, which is
    #                          why #61 calls it the lane with the most to say. Space Age is out by
    #                          construction here: SE declares `! space-age`.
    #   angels-bobs            No declared conflict in either direction. Its members are all inside
    #                          `seablock` too, so it is the isolation lane for that pair: a seablock
    #                          failure among these 20 mods lands here with 26 fewer suspects.
    #   angels-bobs-madclowns  The same plus `Clowns-Processing`, which no other lane pairs with Bob's.
    #   spaceex-rfp-port       SE, the port and Starlark's add-on: the route a player takes to run the
    #                          port under SE (#451). The add-on requires both, so it has no smaller lane.
    #   spaceex-rfp-port-se    SE and solar138's fork, the other route (#452). The fork requires SE.
    #
    # THE COUNTS DIFFER FROM #61's TABLE, and the pins are why. That table was computed from the
    # CURRENT releases, which are factorio_version 2.1; ADR 0026 pins the 2.0 line, whose closures are
    # smaller -- Bob's is 12 mods at 2.0 and 18 at 2.1. So 22 / 20 / 21 here against the table's
    # 20 / 26 / 30. Neither number is wrong; they are different major versions of the same families.
    # The two port lanes are 19 and 18, which no table predated.
    Lanes = @{
        'k2-spaceex'            = @('krastorio2', 'spaceex')
        'angels-bobs'           = @('angels', 'bobs')
        'angels-bobs-madclowns' = @('angels', 'bobs', 'madclowns')
        'spaceex-rfp-port'      = @('spaceex', 'rfp-port', 'rfp-se-compat')
        'spaceex-rfp-port-se'   = @('spaceex', 'rfp-port-se')
    }
}
