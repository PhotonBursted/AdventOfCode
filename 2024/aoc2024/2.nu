def get_data [] {
    if ($in | is-empty) {
        error make --unspanned {
            msg: "Pipeline empty",
            help: "Please call this module after importing the input file."
        }
    }

    $in | lines | each { split words | into int }
}

def "math sign" [] {
    if $in == 0 { 0 } else {
        ($in / ($in | math abs)) | into int      # Divide by the absolute value of itself.
                                                 # This returns 1 for positive numbers,
                                                 # and -1 for negative ones.
    }
}

def is-valid [] -> bool {
    let difference = window 2 | each { $in.1 - $in.0 }

    # The "sign" of the difference shows the "direction" in which the sequence travels.
    # That is to say, a positive sign signals an increasing sequence.
    let signs =      $difference | each { math sign }

    # The magnitude of the difference refers to the size of the difference.
    let magnitudes = $difference | math abs


    # Signs are valid if they all equal each other, and don't equal zero
    let valid_sign      = $signs
                          | window 2
                          | all { ($in.0 != 0) and ($in.0 == $in.1) }

    # Magnitudes are valid if they all lie in the range 1 - 3 (inclusive)
    let valid_magnitude = $magnitudes
                          | all { $in in 1..3 }


    $valid_sign and $valid_magnitude
}

export def a [] {
    let reports = $in | get_data

    $reports | where { is-valid } | length
}

export def b [] {
    let reports = $in | get_data

    $reports | where {|report|
        if ($report | is-valid) {
            # The original report is valid, so there is nothing else to do here.
            true
        } else {
            # Build a set of adjusted reports.
            # All of these reports have a single level removed, to simulate the dampener
            let adjusted_reports = 0..
            | take ($report | length)
            | each {|$index| $report | drop nth $index }

            # Check whether any of these new reports are valid
            $adjusted_reports | any { is-valid }
        }
    } | length
}
