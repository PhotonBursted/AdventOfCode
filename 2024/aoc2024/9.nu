def expand [] record<size: int, id: int> -> list<int> {
    $in | each {|block| seq 1 $block.size | par-each { $block.id } }
}

def get_data [] {
    if ($in | is-empty) {
        error make --unspanned {
            msg: "Pipeline empty",
            help: "Please call this module after importing the input file."
        }
    }

    let blocks = $in | str trim | split chars | into int

    let files = $blocks | every 2 | enumerate | rename id size
    let voids = $blocks | skip 1 | every 2

    { files: $files, voids: $voids }
}

export def a [] {
    let data = get_data

    let files = $data.files | expand
    let filler = $files | reverse | flatten

    # Generate filler sections which are ready to be zipped in place of the voids.
    # Every element in the resulting list should be of the same size as the void in that location.
    let partitioned_filler = generate {|state|
        if ($state.voids | is-not-empty) {
            let void_size = $state.voids | first
            let filler_section = $state.filler | take $void_size

            {
                out: $filler_section,
                next: {voids: ($state.voids | skip 1), filler: ($state.filler | skip $void_size)}
            }
        }
    } {voids: ($data.voids), filler: ($filler)}

    let compact_disk = $files
    | zip $partitioned_filler | flatten             # This is an "interleave", but then guaranteed to be in-order
    | flatten                                       # This combines all of the separate lists into one long list
    | take ($files | flatten | length)              # This cuts off the trailing elements of the disk.

    let checksum = $compact_disk | enumerate | reduce --fold 0 {|it, acc| $acc + ($it.index * $it.item)}

    $checksum
}

export def b [] {
    0
}
