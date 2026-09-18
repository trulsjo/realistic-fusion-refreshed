@{
    # THE MACHINES THAT WEAR A MOCKUP, AND WHERE THEIR PIPES GO. Read by two scripts: make-mockup-art.ps1
    # draws these into graphics/mockup/, and load-check.ps1 holds every row against the live prototype
    # (#275). One file so the two cannot disagree about what is being checked -- the mockup script's
    # own header used to say "nothing enforces agreement with entities.lua", and this is what does.
    #
    # Positions are TILE CENTRES relative to the entity centre, exactly as pipe_connections declares
    # them. Widths and heights are the selection box in tiles. Kind picks the colour a connection is
    # drawn in and Text its label; neither is checked against the game, only X, Y, Width and Height.
    #
    # rf-heat-exchanger and rf-isotope-collector are not here: they have worn rendered art since
    # #252 and #333, and their manifests are held against their prototypes by the rendered-art gate
    # instead. A machine leaves this table when it moves over, or make-mockup-art.ps1 would go on
    # drawing sheets nothing loads and load-check would hold a hand-copied table against a machine
    # the render already describes.
    Machines = @(
        @{
            # Both long sides, so one butts the reactor and the other passes fluid to the next converter
            # in the stack -- the chaining rf-hc-turbine and vanilla's steam turbine also do.
            #
            # FIFTEEN WIDE BY FIVE TALL since ADR 0031 item 4 (#87), where it was five by fifteen with
            # the sockets on west and east. Same machine, turned, so that a converter placed unrotated
            # under a reactor bolts on.
            Mod = 'realistic-fusion-refreshed-assets'; Name = 'direct-energy-converter'; Label = "DIRECT`nENERGY`nCONVERTER"
            Prototype = 'generator'
            Width = 15; Height = 5; Core = $false
            Connections = @(
                @{ X = 0; Y = -2; Kind = 'energy'; Text = 'energy' },
                @{ X = 0; Y =  2; Kind = 'energy'; Text = 'energy' }
            )
        },
        @{
            # Energy sells NORTH AND SOUTH since ADR 0031 item 1 (#87), so a converter hangs off
            # either face. Plasma keeps both west and east -- ADR 0011's shared pool uses them.
            Mod = 'realistic-fusion-refreshed-assets'; Name = 'aneutronic-reactor'; Label = "ANEUTRONIC`nREACTOR"
            Prototype = 'boiler'
            Width = 15; Height = 15; Core = $true
            Connections = @(
                @{ X = -7; Y =  0; Kind = 'input';  Text = 'plasma' },
                @{ X =  7; Y =  0; Kind = 'input';  Text = 'plasma' },
                @{ X =  0; Y = -7; Kind = 'output'; Text = 'energy' },
                @{ X =  0; Y =  7; Kind = 'output'; Text = 'energy' }
            )
        },
        @{
            # rf-heat-exchanger's own footprint and its own six connections since #276: the long north
            # face bolts to a reactor, the long south face vents steam, and each short end reads
            # `_ e _ w _` from north to south so a row chains through them (ADR 0031).
            #
            # IT IS HERE BECAUSE IT HAS NO ART AT THIS SHAPE. Krastorio 2's matter plant sheets were
            # drawn for a seven-tile square and ADR 0022 records that nothing in that set sits at
            # fifteen by five, so the machine drops to a mockup rather than wearing a stretched sprite.
            # The label is also what tells it apart from rf-heat-exchanger, which is the same size on
            # rendered art -- see entities.lua at this machine's footprint.
            Mod = 'realistic-fusion-refreshed-assets'; Name = 'hc-exchanger'; Label = "HIGH-CAPACITY`nHEAT EXCHANGER"
            Prototype = 'boiler'
            Width = 15; Height = 5; Core = $false
            Connections = @(
                @{ X =  0; Y = -2; Kind = 'energy'; Text = 'energy' },
                @{ X = -7; Y = -1; Kind = 'energy'; Text = 'energy' },
                @{ X =  7; Y = -1; Kind = 'energy'; Text = 'energy' },
                @{ X = -7; Y =  1; Kind = 'input';  Text = 'water'  },
                @{ X =  7; Y =  1; Kind = 'input';  Text = 'water'  },
                @{ X =  0; Y =  2; Kind = 'output'; Text = 'steam'  }
            )
        },
        @{
            # A container: lithium arrives by inserter and the tritium it breeds leaves through the
            # reactor's own pipe, so it has no connections of its own to mark. See entities.lua.
            Mod = 'realistic-fusion-refreshed-assets'; Name = 'lithium-blanket'; Label = "LITHIUM`nBLANKET"
            Prototype = 'still'
            Width = 5; Height = 5; Core = $false
            Connections = @()
        }
    )
}
