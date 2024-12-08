def "math mod" [modulus: int] {
    let factor = ($in / $modulus) | math floor
    $in - $factor * $modulus
}

def get_data [] {
    if ($in | is-empty) {
        error make --unspanned {
            msg: "Pipeline empty",
            help: "Please call this module after importing the input file."
        }
    }

    let rows = $in | lines
    let grid_size = {y: ($rows | length), x: ($rows | first | str length)}

    let cells = $in | lines | str join | split chars

    let antennas = $cells
    | enumerate
    | group-by item
    | reject '.'
    | update cells { get index }
    | into record
    | values

    {
        antennas: $antennas,    # Antennas, grouped by the type of signal
        grid_size: $grid_size   # The size of the grid, used for bounds checking
    }
}

def "create antinodes" [grid_size, generate_nodes] {
    let index_into_point = {|index|
        let x = $index | math mod $grid_size.x
        let y = ($index / $grid_size.x) | math floor

        {x: $x, y: $y}
    }
    let bounds_check = {|coords|
        ($coords.x in 0..<$grid_size.x) and ($coords.y in 0..<$grid_size.y)
    }

    $in | each {|locations|
        # Pairings consists of a list of coordinate pairs, pointing to two antennas.
        let pairings = $locations
        | enumerate
        | update item {|location|
            $locations
            | skip (($location.index | into int) + 1)
            | each { [$location.item $in] }
        }
        | get item
        | flatten

        # Locations of antinodes depend on the implementation $generate_nodes closure.
        # The difference between the two nodes is calculated here, since it is reused in every calculation.
        let antinode_locations = $pairings
        | each {|pair|
            let node_1 = do $index_into_point $pair.0
            let node_2 = do $index_into_point $pair.1
            let diff = {x: ($node_2.x - $node_1.x), y: ($node_2.y - $node_1.y)}

            do $generate_nodes $node_1 $node_2 $diff $bounds_check
        }
        | flatten

        $antinode_locations
    }
}

export def a [] {
    let data = get_data

    $data.antennas
    | create antinodes $data.grid_size {|node_1, node_2, diff, bounds_check|
        [
            ($node_1 | {x: ($in.x - $diff.x), y: ($in.y - $diff.y) })
            ($node_2 | {x: ($in.x + $diff.x), y: ($in.y + $diff.y) })
        ]
        | where {|candidate| do $bounds_check $candidate }
    }
    | flatten
    | uniq
    | length
}

export def b [] {
    let data = get_data

    $data.antennas
    | create antinodes $data.grid_size {|node_1, node_2, diff, bounds_check|
        # Generate generates new entries as long as "next" is present.
        # In order to get the interference patterns implemented, a bounds check is done for every iteration.
        # If the bounds check fails, nothing is returned, ending the stream.
        # Otherwise, the next iteration is called with a location that is shifted over by one "antenna gap".
        (generate {|node|
            if (do $bounds_check $node) {
                {
                    out: $node,
                    next: ($node | {x: ($in.x - $diff.x), y: ($in.y - $diff.y)})
                }
            }
        # Note we call the generate step with $node_1 itself!
        # This guarantees that the node itself also becomes an antinode.
        } $node_1) ++ (generate {|node|
            if (do $bounds_check $node) {
                {
                    out: $node,
                    next: ($node | {x: ($in.x + $diff.x), y: ($in.y + $diff.y)})
                }
            }
        } $node_2)
    }
    | flatten
    | uniq
    | length
}
