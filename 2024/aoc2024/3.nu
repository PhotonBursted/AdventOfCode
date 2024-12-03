def get_data [] {
    if ($in | is-empty) {
        error make --unspanned {
            msg: "Pipeline empty",
            help: "Please call this module after importing the input file."
        }
    }

    $in | split chars | window 25 --remainder | each { str join }
}

export def a [] {
    let data = $in | get_data


    # Parse the data, extracting the commands that are being given.
    # This results in a table with columns one and two, both being operands to the multiplication function.
    let instructions = $data
    | par-each { parse -r r#'^mul\((?<one>\d+),(?<two>\d+)\)[\s\S]*$'# | into record }
    | where { is-not-empty }


    $instructions
    | par-each { into int one two }
    | par-each { $in.one * $in.two }
    | math sum
}

export def b [] {
    let data = $in | get_data


    # Parse the data, extracting the commands that are being given.
    # This results in a table with columns one, two, enable and disable.
    # one and two are operands, enable and disable are metavalues which enable or disable commands.
    let instructions = $data
    | each { parse -r r#'^(?:mul\((?<one>\d+),(?<two>\d+)\)|(?<enable>do\(\))|(?<disable>don't\(\)))[\s\S]*$'# | into record }
    | where { is-not-empty }


    # Instructions are going to be siphoned into $enabled_mul_instructions as long as the parser is in enabled mode.
    # Any instructions already processed are to be removed from $remaining_instructions, and will serve as our loop exit condition.
    mut enabled_mul_instructions = []
    mut remaining_instructions = $instructions

    while ($remaining_instructions | is-not-empty) {
        let instructions_to_add = $remaining_instructions
        | take until { $in.disable | is-not-empty }
        | reject enable disable                             # These columns aren't needed; they're only used for enable/disable


        # Commit the instructions to the buffer
        # There may be additional enable commands while we're already in enabled state, these are to be filtered
        $enabled_mul_instructions = $enabled_mul_instructions ++ ($instructions_to_add | where { $in.one != "" })

        # Skip over any instructions already processed, or disabled after that.
        # This ensures the next loop starts on enabled instructions, if any are left.
        $remaining_instructions = $remaining_instructions
        | skip ($instructions_to_add | length)
        | skip until { $in.enable | is-not-empty }
    }


    $enabled_mul_instructions
    | par-each { into int one two }
    | par-each { $in.one * $in.two }
    | math sum
}
