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
    | update url {|row| 
        [
            "https://www.tcm.phy.cam.ac.uk/castep/documentation/WebHelp/content/modules/castep/keywords/"
            $row.url 
        ]
        | str join
    } 
}

# Get the urls and extract the documentation
export def castep-param-doc-collect []: table -> table {
    $in|get url|par-each {|it| http get $it| grab-castep-doc }
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
    | append $"\npub use ($module_name)::($module_name|str pascal-case);"
    | to text
}
