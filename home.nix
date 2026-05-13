{ pkgs, ... }:
{
  home.stateVersion = "25.11";

  targets.genericLinux.enable = true;

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
  ];

  programs.git = {
    enable = true;
    settings = {
      user.name = "akira";
      user.email = "4346607+AkiraMisawa@users.noreply.github.com";
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

      # Home / End keys (cover application, CSI, and legacy sequences)
      bindkey "^[OH"  beginning-of-line
      bindkey "^[OF"  end-of-line
      bindkey "^[[H"  beginning-of-line
      bindkey "^[[F"  end-of-line
      bindkey "^[[1~" beginning-of-line
      bindkey "^[[4~" end-of-line

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
