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
      :desc "Abort"                     "k" #'gptel-abort
      :desc "Tools"                     "t" #'gptel-tools
      :desc "System prompt"             "p" #'gptel-system-prompt
      :desc "Preset"                    "P" #'gptel-preset)


;;; Local LLM tools
;;
;; The same two capabilities open-webui has, on the Emacs side. Search goes to
;; the searxng the packages module runs on loopback, so it needs no API key and
;; the queries stay on this machine.

(defvar +searxng-url "http://127.0.0.1:8888/search")

;; Bounded because a tool result is spent from the model's context window, and
;; a whole file or a long search page would crowd out the conversation.
(defvar +gptel-tool-max-chars 20000)

(defun +gptel--truncate (s)
  (if (> (length s) +gptel-tool-max-chars)
      (concat (substring s 0 +gptel-tool-max-chars) "\n[truncated]")
    s))

(defun +gptel-web-search (query)
  "Return titles, URLs and snippets searxng has for QUERY."
  (condition-case err
      (with-current-buffer
          (url-retrieve-synchronously
           (format "%s?q=%s&format=json" +searxng-url (url-hexify-string query))
           t t 15)
        (unwind-protect
            (progn
              (goto-char (point-min))
              (if (not (re-search-forward "^$" nil t))
                  "searxng returned no parseable response"
                (let ((results (alist-get 'results (json-parse-buffer :object-type 'alist))))
                  (if (zerop (length results))
                      (format "No results for %s" query)
                    (+gptel--truncate
                     (mapconcat
                      (lambda (r)
                        (format "%s\n%s\n%s"
                                (alist-get 'title r "")
                                (alist-get 'url r "")
                                (alist-get 'content r "")))
                      (seq-take (append results nil) 8)
                      "\n\n"))))))
          (kill-buffer)))
    (error (format "searxng is not answering on %s: %s"
                   +searxng-url (error-message-string err)))))

(defun +gptel-read-file (path)
  "Return the contents of PATH."
  (let ((f (expand-file-name path)))
    (cond ((not (file-readable-p f)) (format "Cannot read %s" f))
          ((file-directory-p f) (format "%s is a directory" f))
          (t (with-temp-buffer
               (insert-file-contents f)
               (+gptel--truncate (buffer-string)))))))

(defun +gptel-list-directory (path)
  "Return the names in directory PATH."
  (let ((d (expand-file-name path)))
    (if (not (file-directory-p d))
        (format "%s is not a directory" d)
      (+gptel--truncate
       (mapconcat (lambda (f) (if (file-directory-p (expand-file-name f d))
                                  (concat f "/") f))
                  (directory-files d nil directory-files-no-dot-files-regexp)
                  "\n")))))

;; This one runs on the host as the user, with the user's files and the user's
;; credentials. :confirm below is the whole of the safety story -- there is no
;; sandbox here, and the prompt showing the exact command is what stands
;; between the model and the machine. Do not remove it to save keystrokes.
(defun +gptel-run-command (command)
  "Run COMMAND with the shell and return its combined output."
  (+gptel--truncate
   (with-temp-buffer
     (let ((status (call-process shell-file-name nil t nil
                                 shell-command-switch command)))
       (format "exit %s\n%s" status (buffer-string))))))

(after! gptel
  (gptel-make-tool
   :name "web_search"
   :function #'+gptel-web-search
   :description "Search the web and return the top results with URLs and \
snippets. Use for anything current, or any fact that needs a source."
   :args '((:name "query" :type string :description "The search query."))
   :category "research")

  (gptel-make-tool
   :name "read_file"
   :function #'+gptel-read-file
   :description "Read a file from disk and return its contents."
   :args '((:name "path" :type string :description "Path to the file."))
   :category "filesystem")

  (gptel-make-tool
   :name "list_directory"
   :function #'+gptel-list-directory
   :description "List the files and directories in a directory."
   :args '((:name "path" :type string :description "Path to the directory."))
   :category "filesystem")

  (gptel-make-tool
   :name "run_command"
   :function #'+gptel-run-command
   :description "Run a shell command on this machine and return its output \
and exit status. The user is asked to approve each command before it runs."
   :args '((:name "command" :type string :description "The shell command."))
   :category "system"
   :confirm t)

  ;; Registering a tool only puts it in gptel's registry. `gptel-tools' is the
  ;; list actually sent with a request and is empty by default, so without this
  ;; the model is never told the tools exist and answers that it cannot search
  ;; the web. It holds tool objects, not names or categories -- `gptel-get-tool'
  ;; is what turns one into the other. Picking a subset per buffer is the
  ;; `<leader> o l t' menu.
  (setq gptel-tools
        (mapcar #'gptel-get-tool
                '("web_search" "read_file" "list_directory" "run_command"))))
