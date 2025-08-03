export def read-occ-energy [ u:string ]: string -> table {
    let occ = $in | find -r '\s+1\s+[1-2] Total:' |ansi strip |split column -c ' ' channel spin total occ|into value |do {
        let non_scf = $in | first 2 |get occ |math sum
        let first_scf = $in | select 2 3 |get occ |math sum
        let last_scf = $in | last 2 |get occ |math sum
        [["u" "non_scf" "first_scf" "last_scf"];[$u $non_scf $first_scf $last_scf]]
    }
    let energy = $in | find -r 'Total free energy' |ansi strip|split column -c ' '|get column6 |into value|do {
        let initial_e = $in | get 0
        let first_e = $in |get 1
        let last_e = $in |last 1|get 0
        [["u","initial_e", "first_e","last_e"];[$u $initial_e $first_e $last_e]]
    }
    $occ |merge $energy
}

export def read-u-result [castep_file:string, ] {
    ls 
    |where type == dir 
    |upsert u {|dir| $dir.name | parse '{_}_{u}_{_}'| get u | get 0}
    |reject type size modified
    |do {
    $in | where u != "0.0" 
        | par-each {|dir| cd $dir.name; open $castep_file |read-occ-energy $dir.u}
        |append (
            open $castep_file
            |read-occ-energy "0.0"
            |update first_scf {|row| $row.last_scf}
            |update initial_e {|row| $row.last_e }
            |update first_e {|row| $row.last_e}
        ) 
        |flatten
        |sort-by -c {|a,b| ($a.u |into float) < ($b.u |into float)}
    } 
}
 
export def read-hubbard-energies [castep_file:string,] {
    ls 
    |where type == dir 
    |upsert u {|dir| $dir.name | parse '{_}_{u}_{_}'| get u | get 0}
    |reject type size modified
    |par-each {|dir| cd $dir.name; open $castep_file |get-hubbard-energies $dir.u}
        |flatten
        |sort-by -c {|a,b| ($a.u |into float) < ($b.u |into float)}
}

export def get-hubbard-energies [u:string]: string -> table {
    let total_free_e = $in | find 'Total free energy' |ansi strip |split column -c ' ' |select column6 |rename "Total_free_energy"
    let pot_e = $in | find 'Potential energy (total)'|ansi strip |split column -c ' '|select column5| rename "Potential_energy"
    let hub_e = $in |find '+Hubbard energy'|ansi strip|split column -c ' '|select column4|rename "Hubbard_energy"
    let hub_corr = $in |find 'LDA+U correction'|ansi strip|split column -c ' '|select column6|rename "Hubbard_correction"
    let spin_1_occ = $in |find -r '\s+1\s+1 Total:'|ansi strip|split column -c ' '|select column4|rename spin_1
    let spin_2_occ = $in |find -r '\s+1\s+2 Total:'|ansi strip|split column -c ' '|select column4|rename spin_2
    let occ = $spin_1_occ |merge $spin_2_occ |into value |upsert "occ" {|row| $row.spin_1 + $row.spin_2}|select occ
    let table = [$occ $hub_corr $hub_e $pot_e $total_free_e] |reduce {|acc,e | $acc |merge $e}|into value
    [["u" "item"];[$u $table]]
}
