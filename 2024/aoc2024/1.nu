def get_data [] {
    if ($in | is-empty) {
        error make --unspanned {
            msg: "Pipeline empty",
            help: "Please call this module after importing the input file."
        }
    }

    $in | detect columns --no-headers | rename left right | into int left right
}

# Calculate the sum of differences between the pairs of a two sorted lists
export def a [] {
    let data = $in | get_data

    # Sort left and right lists
    let left_list = $data | get left | sort
    let right_list = $data | get right | sort


    $left_list | zip $right_list | par-each {       # Zip lists (reuniting left and right)
        reduce {|it, acc| $acc - $it } | math abs   # Calculate the absolute difference per pair
    } | math sum                                    # And add up to get the final answer!
}

# Determine the values which appear in a reference list, weighted by the
# amount of times they appear in that list
export def b [] {
    let data = $in | get_data

    let needles = $data | get left
    let haystack = $data | get right | uniq --count | transpose --ignore-titles -r -d

    # The needles are a list of things to look up.
    # The haystack is the list to search in, in the form of a record,
    # whose keys are values, and whose values are the amount of appearances
    # they have in the haystack.

    $needles | par-each {|needle|
        # Since Nushell also allows row index retrieval, we cast the needle to a string,
        # to make sure get is interpreted as a column-based retrieval.
        let appearances = $haystack | get --ignore-errors ($needle | into string) | default 0

        $appearances * $needle
    } | math sum
}
