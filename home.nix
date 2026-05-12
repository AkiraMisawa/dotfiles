{ pkgs, ... }:
{
  home.stateVersion = "25.11";

  targets.genericLinux.enable = true;

  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  home.sessionVariables = {
    EDITOR = "micro";
    VISUAL = "micro";
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
  ];

  programs.git = {
    enable = true;
    settings = {
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
  programs.helix.enable = true;

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
    '';
  };
}
