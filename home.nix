{ pkgs, lib, gitName, gitEmail, ... }:
{
  home.stateVersion = "25.11";

  targets.genericLinux.enable = pkgs.stdenv.isLinux;

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  home.sessionVariables = {
    EDITOR = "hx";
    VISUAL = "hx";
    PAGER = "moor";
  };

  xdg.configFile."micro/colorschemes/tokyonight.micro".source =
    ./files/micro-tokyonight.micro;
  xdg.configFile."micro/syntax/markdown.yaml".source =
    ./files/micro-markdown.yaml;
  xdg.configFile."micro/settings.json".text = builtins.toJSON {
    colorscheme = "tokyonight";
  };

  # --- Claude Code (statusline + settings.json merge only) ---
  # The binary itself is installed via the official installer so its
  # in-place auto-update keeps working. We only manage the statusline
  # script and weave the `statusLine` entry into ~/.claude/settings.json.
  home.file.".claude/statusline.sh" = {
    source = ./files/claude-statusline.sh;
    executable = true;
  };

  home.activation.claudeStatusLineConfig =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "$HOME/.claude"
      settings="$HOME/.claude/settings.json"
      [ -s "$settings" ] || echo '{}' > "$settings"
      tmp=$(mktemp)
      ${pkgs.jq}/bin/jq '. + {
        statusLine: {
          type: "command",
          command: "~/.claude/statusline.sh",
          padding: 1
        }
      }' "$settings" > "$tmp" && mv "$tmp" "$settings"
    '';

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    ripgrep
    fd
    fzf
    jq
    bat
    just
    micro
    moar
    rsync
    yq-go
    zellij
    emacs
    starship

    # System monitoring / inspection — all Rust.
    bottom                  # btm: htop alternative, graphs + mouse
    procs                   # ps alternative, colored process listing
    dust                    # du alternative, tree view of disk usage
    bandwhich               # per-process network bandwidth monitor
    hyperfine               # command-line benchmarking

    # yazi preview/extraction helpers
    ffmpegthumbnailer
    poppler-utils
    imagemagick
    p7zip
    chafa
    unar

    # Runtime-independent LSPs picked up by helix automatically when on
    # PATH. Language-runtime LSPs (rust-analyzer, gopls, pyright, ...)
    # live in per-project flake devShells instead.
    marksman                # markdown
    nil                     # nix
    yaml-language-server    # yaml

    # Claude Code token usage — wrapper keeps `bun` off PATH while
    # letting `bun x` fetch the latest ccusage on demand.
    (writeShellApplication {
      name = "ccusage";
      runtimeInputs = [ bun ];
      text = ''
        exec bun x ccusage "$@"
      '';
    })
  ];

  programs.git = {
    enable = true;
    settings = {
      user.name = gitName;
      user.email = gitEmail;
      init.defaultBranch = "main";
      core.autocrlf = "input";
      pull.rebase = false;
      fetch.prune = true;
      rerere.enabled = true;
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };

  programs.gh.enable = true;
  programs.lazygit.enable = true;

  programs.gitui = {
    enable = true;
    # Tokyo Night (Gogh) palette — same family as the micro/helix themes.
    # bg #1a1b26 / fg #a9b1d6 / blue #7aa2f7 / red #f7768e / green #9ece6a.
    theme = ''
      (
          selected_tab: Some("#7aa2f7"),
          command_fg: Some("#a9b1d6"),
          selection_bg: Some("#283457"),
          selection_fg: Some("#c0caf5"),
          cmdbar_bg: Some("#1f2335"),
          cmdbar_extra_lines_bg: Some("#1f2335"),
          disabled_fg: Some("#565f89"),
          diff_line_add: Some("#9ece6a"),
          diff_line_delete: Some("#f7768e"),
          diff_file_added: Some("#9ece6a"),
          diff_file_removed: Some("#db4b4b"),
          diff_file_moved: Some("#bb9af7"),
          diff_file_modified: Some("#ff9e64"),
          commit_hash: Some("#bb9af7"),
          commit_time: Some("#a9b1d6"),
          commit_author: Some("#7dcfff"),
          danger_fg: Some("#f7768e"),
          push_gauge_bg: Some("#7aa2f7"),
          push_gauge_fg: Some("#1a1b26"),
          tag_fg: Some("#73daca"),
          branch_fg: Some("#9ece6a"),
      )
    '';
  };

  programs.helix = {
    enable = true;
    settings = {
      theme = "tokyonight";
      editor = {
        line-number = "relative";
        cursorline = true;
        mouse = true;
        bufferline = "multiple";
        color-modes = true;
        indent-guides.render = true;
        lsp.display-messages = true;
        soft-wrap.enable = true;
      };
      # Open gitui in a zellij floating pane (requires running inside a
      # zellij session). `zellij run` returns immediately, so :sh doesn't
      # block the editor. Rebind if C-g clashes with your muscle memory.
      keys.normal."C-g" =
        ":sh zellij run --floating --close-on-exit --name gitui -- gitui";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [ "--cmd cd" ];
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    shellWrapperName = "y";
    plugins = {
      copy-across-tabs = ./files/yazi-plugins/copy-across-tabs;
    };
    keymap = {
      mgr.append_keymap = [
        {
          on = [ "c" "C" ];
          run = "plugin copy-across-tabs";
          desc = "Copy paths across all tabs";
        }
        {
          on = [ "c" "D" ];
          run = "plugin copy-across-tabs -- dirname";
          desc = "Copy dirnames across all tabs";
        }
        {
          on = [ "c" "F" ];
          run = "plugin copy-across-tabs -- filename";
          desc = "Copy filenames across all tabs";
        }
        {
          on = [ "c" "N" ];
          run = "plugin copy-across-tabs -- noext";
          desc = "Copy filenames (no ext) across all tabs";
        }
      ];
    };
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    git = true;
    icons = "auto";
    extraOptions = [
      "--group-directories-first"
      "--header"
      "--time-style=long-iso"
    ];
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    historySubstringSearch.enable = true;
    history.expireDuplicatesFirst = true;
    shellAliases = {
      z = "cd";
      zi = "cdi";
    };
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      {
        name = "powerlevel10k-config";
        src = ./files;
        file = "p10k.zsh";
      }
    ];
    initContent = ''
      # Enable Powerlevel10k instant prompt.
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
        source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi

      setopt HIST_VERIFY

      # Home / End / Delete (cover application, CSI, and legacy sequences)
      bindkey "^[OH"  beginning-of-line
      bindkey "^[OF"  end-of-line
      bindkey "^[[H"  beginning-of-line
      bindkey "^[[F"  end-of-line
      bindkey "^[[1~" beginning-of-line
      bindkey "^[[4~" end-of-line
      bindkey "^[[3~" delete-char

      # Ctrl-P / Ctrl-N also do substring history search
      bindkey "^P" history-substring-search-up
      bindkey "^N" history-substring-search-down

      # rg + fzf + $EDITOR: grep file contents, pick a match (live bat
      # preview), then open the file at the matched line.
      rgo() {
        [[ -z "$1" ]] && { echo "usage: rgo <pattern>"; return 1 }
        local selection
        selection=$(rg --line-number --no-heading --smart-case "$1" \
          | fzf --delimiter : \
                --preview 'bat --color=always --highlight-line {2} {1}' \
                --preview-window 'right:60%:+{2}/3') || return
        [[ -z "$selection" ]] && return
        local file=$(echo "$selection" | cut -d: -f1)
        local line=$(echo "$selection" | cut -d: -f2)
        case "$EDITOR" in
          *micro*)      "$EDITOR" +"$line" "$file" ;;
          *hx*|*helix*) "$EDITOR" "$file:$line" ;;
          *)            "$EDITOR" "$file" ;;
        esac
      }
    '';
  };
}
