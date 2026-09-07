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
    # rf-heat-exchanger is not here: it has worn rendered art since #252, and its manifest is held
    # against the prototype by the rendered-art gate instead.
    Machines = @(
        @{
            # Both long sides, so one butts the reactor and the other passes fluid to the next converter
            # in the row -- the chaining rf-hc-turbine and vanilla's steam turbine also do.
            Mod = 'realistic-fusion-refreshed-assets'; Name = 'direct-energy-converter'; Label = "DIRECT`nENERGY`nCONVERTER"
            Prototype = 'generator'
            Width = 5; Height = 15; Core = $false
            Connections = @(
                @{ X = -2; Y = 0; Kind = 'energy'; Text = 'energy' },
                @{ X =  2; Y = 0; Kind = 'energy'; Text = 'energy' }
            )
        },
        @{
            Mod = 'realistic-fusion-refreshed-assets'; Name = 'aneutronic-reactor'; Label = "ANEUTRONIC`nREACTOR"
            Prototype = 'boiler'
            Width = 15; Height = 15; Core = $true
            Connections = @(
                @{ X = -7; Y =  0; Kind = 'input';  Text = 'plasma' },
                @{ X =  7; Y =  0; Kind = 'input';  Text = 'plasma' },
                @{ X =  0; Y = -7; Kind = 'output'; Text = 'energy' }
            )
        },
        @{
            Mod = 'realistic-fusion-refreshed-assets'; Name = 'isotope-collector'; Label = "ISOTOPE`nCOLLECTOR"
            Prototype = 'boiler'
            Width = 5; Height = 5; Core = $false
            Connections = @(
                @{ X = -2; Y =  0; Kind = 'output'; Text = 'tritium' },
                @{ X =  2; Y =  0; Kind = 'output'; Text = 'tritium' },
                @{ X =  0; Y = -2; Kind = 'output'; Text = 'He3' }
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
