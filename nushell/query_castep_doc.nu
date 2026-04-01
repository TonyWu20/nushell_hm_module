# Select the `text_content` from the returned castep keyword
# documentation html page
# - Dependency:
#   - `nu_plugin_query`
export def grab-castep-doc []: string -> string {
    $in 
    | query webpage-info 
    | get text_content
    | lines --skip-empty 
    | str trim
    | split list 'See Also:'
    | get 0
    | prepend ["```"]
    | append ["```"]
    | str join "\n"
}

# Retrieve the castep's parameter's keyword documentation link
export def castep-param-keywords-links [
    slice_range?: range # optional, select a range of links from the retrieved list
]: nothing -> table {
    http get https://www.tcm.phy.cam.ac.uk/castep/documentation/WebHelp/content/modules/castep/keywords/k_main_parameters.htm
    | query webpage-info 
    | get links
    | slice ($slice_range|default 0..)
    | enumerate
    | flatten
}

# Get the urls and extract the documentation
export def castep-param-doc-collect []: table -> table {
    $in
    | update url {|row| 
        [
            "https://www.tcm.phy.cam.ac.uk/castep/documentation/WebHelp/content/modules/castep/keywords/"
            $row.url 
        ]
        | str join
    } 
    | get url
    | par-each {|it| http get $it| grab-castep-doc }
}

# Retrieve pages of `CASTEP` keyword documentations into text
export def castep-concat-docs [module_name: string]: string -> string {
    [
        $"These are submodules of module `($module_name)`" $in
    ]
    | str join "\n"
}

# Wrap the generated code as a rust module
export def to-rust-mod [module_name:string, input?: string]: [
nothing -> string # the code is passed from argument
string -> string # the code is passed from pipeline
] {
    let pipe_in = $in
    ($input | default $pipe_in)
    | lines
    | prepend $"mod ($module_name) {"
    | append "}"
    | to text
}

# collect generated code snippets from `qwen3-coder`
export def 'castep collect-codes' []: string -> table {
    $in
    | split row "```"
    | find -n 'rust'
    | str replace --all -m 'rust\n// File:.*\n' ''
    | each { [[mod_code];[$in]]}
    | flatten
}

# collect module name from result of `castep-param-keywords-links`
export def 'castep collect-mod-names' []: table -> table {
    $in
    | select text
    | update text {$in |str downcase}
    | rename mod_name
}

# Merge two tables, and wrap the code snippets to a real working rust module
# | mod_name | mod_code |
# | -------- | -------- |
# | ...      | ...      |
export def 'castep to-mod' [mod_name: table, mod_code: table]: nothing -> string {
    $mod_name
    | merge $mod_code
    | do {
        let table = $in
        let modules = $table | each {|row| $row.mod_code | to-rust-mod $row.mod_name}
        let exports = $mod_name | each {|row| $"pub use ($row.mod_name)::($row.mod_name|str pascal-case);"}
        $modules 
        | append $exports
    }
    | to text
}
