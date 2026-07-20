;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
(setq user-full-name "Sung Kang"
      user-mail-address "skang124@proton.me")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.


;;; Local LLM
;;
;; gptel talks to the ollama the packages module installs, on its default
;; 127.0.0.1:11434. Nothing leaves the machine and no API key is involved, so
;; it is the default backend rather than one to switch to.

(defvar +ollama-host "127.0.0.1:11434")

;; ollama picks the model from the GPU's VRAM and writes the choice here, so
;; the tag differs per machine and is read rather than named. open-webui's
;; installer reads the same file.
(defvar +ollama-roles-file "~/.local/share/ollama/roles.env")

;; Only used when neither the roles file nor the server can answer.
(defvar +ollama-fallback-model 'qwen3.5:latest)

(defun +ollama-role (key)
  "Value of KEY in ollama's roles file, or nil."
  (let ((f (expand-file-name +ollama-roles-file)))
    (when (file-readable-p f)
      (with-temp-buffer
        (insert-file-contents f)
        (goto-char (point-min))
        (when (re-search-forward (format "^%s=\\(.+\\)$" (regexp-quote key)) nil t)
          (intern (string-trim (match-string 1))))))))

(defun +ollama-models ()
  "Model tags the local ollama server reports, or nil if it is not running."
  (ignore-errors
    (with-current-buffer
        ;; Two seconds: this runs when gptel first loads, so a server that is
        ;; down has to fail fast rather than hang the editor.
        (url-retrieve-synchronously
         (format "http://%s/api/tags" +ollama-host) t t 2)
      (unwind-protect
          (progn
            (goto-char (point-min))
            (when (re-search-forward "^$" nil t)
              (mapcar (lambda (m) (intern (alist-get 'name m)))
                      (alist-get 'models
                                 (json-parse-buffer :object-type 'alist)))))
        (kill-buffer)))))

(after! gptel
  (let* ((available (+ollama-models))
         (chosen (+ollama-role "OLLAMA_MODEL"))
         ;; The roles file names the intent; the server says what is actually
         ;; pulled. Trust the first only when the second agrees with it, since
         ;; a bare tag like qwen3.5 is reported as qwen3.5:latest.
         (default (or (and chosen
                           (or (car (memq chosen available))
                               (car (memq (intern (format "%s:latest" chosen))
                                          available))))
                      (car available)
                      +ollama-fallback-model)))
    (setq gptel-model default
          gptel-backend (gptel-make-ollama "Ollama"
                          :host +ollama-host
                          :stream t
                          :models (or available (list default))))))

;; Extends the `<leader> o l' prefix the :tools llm module already defines in
;; config/default rather than starting a prefix of its own, so every gptel
;; command lives in one place. Only the keys Doom leaves free there are used --
;; it takes a, e, f, l, s, m, r, o and O.
;;
;; `:prefix "o l"', not `:prefix ("l" . "llm")': the cons form defines a new
;; prefix command and binds it over the existing one, which silently drops
;; every binding Doom put there.
;;
;; `L' is bound because Doom only ships it in +evil-bindings.el, and this
;; config runs without :editor evil, so the command is otherwise unreachable.
(map! :leader
      :prefix "o l"
      :desc "Open gptel in same window" "L" #'+llm/open-in-same-window
      :desc "Clear context"             "c" #'gptel-context-remove-all
      :desc "Remove from context"       "d" #'gptel-context-remove
      :desc "Add kill to context"       "y" #'gptel-context-add-current-kill
      :desc "Tools"                     "t" #'gptel-tools
      :desc "System prompt"             "p" #'gptel-system-prompt
      :desc "Preset"                    "P" #'gptel-preset)
