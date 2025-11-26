{
  # UI & Theme
  theme = "One Dark";
  ui_font_size = 16;
  buffer_font_size = 14;
  buffer_font_family = "JetBrains Mono";

  # Editor Settings
  tab_size = 2;
  hard_tabs = false;
  soft_wrap = "none";
  show_whitespaces = "selection";
  line_indicator_format = "long";

  # Line numbers
  relative_line_numbers = true;

  # Cursor
  cursor_blink = false;

  # Editor behavior
  auto_save = "on_focus_change";
  format_on_save = "on";
  ensure_final_newline_on_save = true;
  remove_trailing_whitespace_on_save = true;

  # Git
  git = {
    git_gutter = "tracked_files";
    inline_blame = {
      enabled = true;
    };
  };

  # Terminal
  terminal = {
    shell = {
      program = "bash";
    };
    working_directory = "current_project_directory";
  };

  # Language-specific settings
  languages = {
    Nix = {
      language_servers = ["nil" "!nixd"];
      formatter = {
        external = {
          command = "alejandra";
          arguments = ["-"];
        };
      };
      format_on_save = "on";
    };

    Python = {
      format_on_save = "on";
      formatter = "language_server";
    };

    Rust = {
      format_on_save = "on";
    };
  };

  # LSP
  lsp = {
    nil = {
      binary = {
        path_lookup = true;
      };
    };
  };

  # Telemetry
  telemetry = {
    diagnostics = false;
    metrics = false;
  };

  # Features
  assistant = {
    enabled = false;
  };

  collaboration_panel = {
    button = false;
  };

  # UI Elements
  scrollbar = {
    show = "auto";
  };

  tabs = {
    git_status = true;
  };
}
