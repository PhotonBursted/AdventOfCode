def get_data [] {
    if ($in | is-empty) {
        error make --unspanned {
            msg: "Pipeline empty",
            help: "Please call this module after importing the input file."
        }
    }

    let lines = $in | lines

    let ordering_rules = $lines
    | take until { is-empty }
    | parse "{preceding}|{following}"

    let updates = $lines
    | skip (($ordering_rules| length) + 1)
    | par-each { split row "," }

    { ordering_rules: $ordering_rules, updates: $updates }
}

export def a [] {
    let data = get_data

    let valid_updates = $data.updates | where {|update|
        # Rules are only applicable if all terms exist in the update
        let applicable_rules = $data.ordering_rules | where {|rule| ($rule.preceding in $update) and ($rule.following in $update) }

        # Calculate the positions of each page in the update.
        # This takes the shape of a record, with keys which consist of the page numbers, which speeds up lookup.
        let positions_in_update = $update | enumerate | move index --after item | transpose --header-row --as-record


        # Ensure every rule is adhered to!
        $applicable_rules | all {|rule| ($positions_in_update | get $rule.preceding) < ($positions_in_update | get $rule.following) }
    }

    $valid_updates
    | each {|update|
        let length = $update | length
        let middle_index = ($length / 2) | math floor

        $update | get $middle_index | into int
    }
    | math sum
}

export def b [] {
    let data = get_data

    let corrected_updates = $data.updates | par-each {|update|
        # The subject will be mutated as long as it is invalid according to the applicable rules.
        mut subject = $update
        # If this is the first run through the loop, and the rule is seen as valid, it means it was valid from the get go.
        # The assignment says to ignore these.
        mut first_run = true

        # A loop is required for this algorithm to work, since a single fixing pass may introduce new rule violations.
        # Mutations should happen as long as violations are found.
        loop {
            # Rules are only applicable if all terms exist in the update
            let applicable_rules = $data.ordering_rules | where {|rule| ($rule.preceding in $subject) and ($rule.following in $subject) }

            # Calculate the positions of each page in the update.
            # This takes the shape of a record, with keys which consist of the page numbers, which speeds up lookup.
            let positions_in_update = $subject | enumerate | move index --after item | transpose --header-row --as-record


            # Find all rules which are not met in the update sequence.
            let violated_rules = $applicable_rules | where {|rule| ($positions_in_update | get $rule.preceding) >= ($positions_in_update | get $rule.following) }

            # If no violated rules are found, the update sequence is actually okay, and the loop should end.
            if ($violated_rules | is-empty) {
                # As described earlier, updates found valid on first pass should be ignored!
                if ($first_run) {
                    $subject = null
                }

                break
            }


            # Here, the violated rules are corrected.
            # This is done by manipulating the subject, swapping columns so they are placed according to what the violated ordering rules specify.
            # This will eventually settle into the right solution.
            $subject = $violated_rules
            | reduce --fold $positions_in_update {|rule, update| $update | move $rule.preceding --before $rule.following }
            | columns

            $first_run = false
        }

        $subject
    }

    $corrected_updates
    | each {|update|
        let length = $update | length
        let middle_index = ($length / 2) | math floor

        $update | get $middle_index | into int
    }
    | math sum
}
