def get_data [] {
    if ($in | is-empty) {
        error make --unspanned {
            msg: "Pipeline empty",
            help: "Please call this module after importing the input file."
        }
    }

    let lines = $in | lines | each {|line| $line + "#"}

    let line_length = $lines | first | str length
    let content = $lines | str join

    { line_length: $line_length, content: $content }
}

def "occurences in" [content: string] {
    par-each {|pattern|
        $content
        | split chars
        | window $pattern.length
        | par-each { str join | parse --regex $pattern.matcher }
        | flatten
    }
    | flatten
    | length
}

export def a [] {
    let data = $in | get_data
    let query = "XMAS"

    let gaps = [
        0,                                  # Horizontal match
        (($data.line_length) - 2),          # "Southwest" match
        (($data.line_length) - 1),          # Vertical match
         ($data.line_length),               # "Southeast" match
    ]

    let patterns = $gaps | par-each {|gap|
        [$query, ($query | str reverse)] | each {|word|
            let matcher = "(?<match>" + ($word | split chars | str join (".{" + ($gap | into string) + "}")) + ")"

            {
                length: ($gap * 3 + 4),
                matcher: $matcher
            }
        }
    }
    | flatten

    $patterns | occurences in $data.content
}

export def b [] {
    let data = $in | get_data

    let queries = [
        "MMASS",
        "MSAMS",
        "SSAMM",
        "SMASM"
    ]
    let gaps = [
        1,
        ($data.line_length - 2),
        ($data.line_length - 2),
        1,
        0
    ] | into string

    let patterns = $queries | par-each {|query|
        let characters = $query | split chars

        let matcher = $characters
                      | zip ($gaps | each {|gap| ".{" + $gap + "}" })
                      | flatten
                      | str join

        {
            length: ($data.line_length * 2 + 3),
            matcher: $matcher
        }
    }

    $patterns | occurences in $data.content
}
