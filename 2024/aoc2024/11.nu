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

    $in | split words | into int
}

def blink [count] {
    generate {|state|
        let stones = $state.stones
        let iterations_left = $state.iterations

        if $iterations_left == 0 {
            return {out: $stones}
        }

        let new_stones = $stones | par-each {|stone|
            if $stone == 0 {
                return [1]
            }

            let stone_as_string = $stone | into string
            let stone_number_length = $stone_as_string | str length
            if ($stone_number_length | math mod 2) == 0 {
                let halfway_point = ($stone_number_length / 2) | into int

                let left_half = $stone_as_string | str substring ..<$halfway_point | into int
                let right_half = $stone_as_string | str substring $halfway_point.. | into int

                return [$left_half $right_half]
            }

            return [($stone * 2024)]
        } | flatten

        { next: {stones: $new_stones, iterations: ($iterations_left - 1)} }
    } {stones: $data, iterations: $count}
}

export def a [] {
    let data = get_data

    let stones = blink 25

    $stones | flatten | length
}
