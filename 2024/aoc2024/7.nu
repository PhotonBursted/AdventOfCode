def get_data [] {
    if ($in | is-empty) {
        error make --unspanned {
            msg: "Pipeline empty",
            help: "Please call this module after importing the input file."
        }
    }

    $in | lines | par-each { parse "{expected}: {terms}" | update terms { split words } } | flatten | into value
}

def "determine possible equations using" [operator_pattern] {
    $in | where {|formula|
        let terms = $formula.terms | into int
        let expected_value = $formula.expected | into int

        let operator_sets = seq 1 (($terms | length) - 1)
        | par-each { $"{($operator_pattern | str join ',')}#" }
        | str join
        | str expand
        | par-each { split row '#' }

        let results = $operator_sets | par-each {|set|
            let actions = $terms | skip 1 | zip $set

            $actions | reduce --fold $terms.0 {|it, acc|
                let value = $it.0 | into int
                let operator = $it.1

                match $operator {
                    '+' => ($acc + $value),
                    '*' => ($acc * $value),
                    '||' => ($acc * (10 ** ($value | into string | str length)) + $value)
                }
            }
        }

        $results | any { $in == $expected_value }
    }
    | get expected
}

export def a [] {
    let data = get_data

    $data | determine possible equations using ['+' '*'] | math sum
}


export def b [] {
    let data = get_data

    $data | determine possible equations using ['+' '*' '||'] | math sum
}
