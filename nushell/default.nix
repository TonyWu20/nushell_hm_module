{ pkgs, ... }:
{
  programs.nushell = {
    enable = true;
    plugins = with pkgs; [
      nushellPlugins.skim
      nushellPlugins.polars
      nushellPlugins.polars
      nushellPlugins.highlight
      nushellPlugins.gstat
      nushellPlugins.query
    ];
    shellAliases = {
      vim = "nvim";
      fg = "job unfreeze";
    };
    envFile.source = ./env.nu;
    extraConfig = builtins.concatStringsSep "\n" [
      (builtins.readFile ./bib_management.nu)
      (builtins.readFile ./crossref.nu)
      (builtins.readFile ./keybindings.nu)
      (builtins.readFile ./hubbard.nu)
      (builtins.readFile ./query_castep_doc.nu)
      ''
        $env.PATH = ($env.PATH | split row (char esep) | prepend "/home/tony/.config/carapace/bin")

        def --env get-env [name] { $env | get $name }
        def --env set-env [name, value] { load-env { $name: $value } }
        def --env unset-env [name] { hide-env $name }

        let carapace_completer = {|spans|
          # if the current command is an alias, get it's expansion
          let expanded_alias = (scope aliases | where name == $spans.0 | get -i 0 | get -i expansion)

          # overwrite
          let spans = (if $expanded_alias != null  {
            # put the first word of the expanded alias first in the span
            $spans | skip 1 | prepend ($expanded_alias | split row " " | take 1)
          } else {
            $spans | skip 1 | prepend ($spans.0)
          })

          carapace $spans.0 nushell ...$spans
          | from json
        }

        mut current = (($env | default {} config).config | default {} completions)
        $current.completions = ($current.completions | default {} external)
        $current.completions.external = ($current.completions.external
        | default true enable
        | default { $carapace_completer } completer)

        $env.config = $current
        source ~/.zoxide.nu
      ''
    ];
    settings = {
      table = {
        header_on_separator = false;
        abbreviated_row_count = null;
        footer_inheritance = true;
        trim = {
          methodology = "wrapping";
          wrapping_try_keep_words = true;
        };
      };
      datetime_format = {
        table = null;
        normal = "%m/%d/%y %I:%M:%S%p";
      };
      filesize.unit = "metric";
      render_right_prompt_on_last_line = false;
      float_precision = 16;
      ls.use_ls_colors = true;
      cursor_shape.emacs = "inherit"; # Cursor shape in emacs mode
      cursor_shape.vi_insert = "block"; # Cursor shape in vi-insert mode
      cursor_shape.vi_normal = "underscore"; # Cursor shape in normal vi mode
      edit_mode = "vi";
      buffer_editor = "nvim";
      history = {
        file_format = "sqlite";
        max_size = 5000000;
        sync_on_enter = false;
      };
      shell_integration = {
        osc2 = true;
        osc7 = true;
        osc9_9 = false;
        osc8 = true;
      };
      error_style = "fancy";
      display_errors.termination_signal = true;
      completions = {
        algorithm = "fuzzy";
      };
    };
  };
  home.shell.enableNushellIntegration = true;
  programs = {
    zoxide.enableNushellIntegration = true;
    starship.enableNushellIntegration = true;
    eza.enableNushellIntegration = true;
    carapace = {
      enable = true;
      enableNushellIntegration = true;
    };
  };
}
