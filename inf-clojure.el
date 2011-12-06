;;; inf-clojure.el --- inferior mode for Clojure

;; Copyright (C) 2011  Syohei YOSHIDA

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

(eval-when-compile
  (require 'cl))

(require 'clojure-mode)
(require 'comint)

(defvar clojure-buffer nil "*The current clojure process buffer.*")

;;; INFERIOR CLOJURE MODE STUFF
;;;============================================================================

(defcustom inferior-clojure-mode-hook nil
  "Hook for customizing inferior-clojure mode."
  :type 'hook
  :group 'inf-clojure)

(defcustom clojure-source-modes '(clojure-mode)
  "source mode"
  :type '(repeat function)
  :group 'inf-clojure)

(when (require 'ansi-color nil t)
 (autoload 'ansi-color-for-comint-mode-on "ansi-color" nil t)
 (add-hook 'inferior-clojure-mode-hook 'ansi-color-for-comint-mode-on))

(defvar inferior-clojure-mode-map
  (let ((m (make-sparse-keymap)))
    (define-key m (kbd "M-C-x") 'clojure-send-definition) ;gnu convention
    (define-key m (kbd "C-x C-e") 'clojure-send-last-sexp)
    (define-key m (kbd "C-c C-l") 'clojure-load-file)
    m))

;; Install the process communication commands in the clojure-mode keymap.
(define-key clojure-mode-map (kbd "M-C-x")  'clojure-send-definition) ;gnu convention
(define-key clojure-mode-map (kbd "C-x C-e") 'clojure-send-last-sexp) ;gnu convention
(define-key clojure-mode-map (kbd "C-c C-d") 'clojure-document)
(define-key clojure-mode-map (kbd "C-c C-e") 'clojure-send-definition)
(define-key clojure-mode-map (kbd "C-c C-c") 'clojure-send-definition)
(define-key clojure-mode-map (kbd "C-c M-e") 'clojure-send-definition-and-go)
(define-key clojure-mode-map (kbd "C-c C-r") 'clojure-send-region)
(define-key clojure-mode-map (kbd "C-c M-r") 'clojure-send-region-and-go)
(define-key clojure-mode-map (kbd "C-c C-x") 'clojure-expand-current-form)
(define-key clojure-mode-map (kbd "C-c C-z") 'switch-to-clojure)
(define-key clojure-mode-map (kbd "C-c C-l") 'clojure-load-file)

(define-derived-mode inferior-clojure-mode comint-mode "Inferior Clojure"
  ;; Customize in inferior-clojure-mode-hook
  (setq comint-prompt-regexp "^[^>\n]*>+ *") ; OK clj-env-dir
  (setq mode-line-process '(":%s"))
  (setq comint-input-filter (function clojure-input-filter))
  (setq comint-get-old-input (function clojure-get-old-input)))

(defcustom inferior-clojure-filter-regexp "\\`\\s *\\S ?\\S ?\\s *\\'"
  "Input matching this regexp are not saved on the history list.
Defaults to a regexp ignoring all inputs of 0, 1, or 2 letters."
  :type 'regexp
  :group 'inf-clojure)

(defun clojure-input-filter (str)
  "Don't save anything matching `inferior-clojure-filter-regexp'."
  (not (string-match inferior-clojure-filter-regexp str)))

(defun clojure-get-old-input ()
  "Snarf the sexp ending at point."
  (save-excursion
    (let ((end (point)))
      (backward-sexp)
      (buffer-substring (point) end))))

(defun clojure-send-region (start end)
  "Send the current region to the inferior Clojure process."
  (interactive "r")
  (let* ((str (buffer-substring-no-properties start end))
         (ignore-newline (replace-regexp-in-string "[\r\n]" "" str)))
   (comint-send-string (clojure-proc) ignore-newline)
   (comint-send-string (clojure-proc) "\n")))

(defun switch-to-clojure (eob-p)
  (interactive "P")
  (if (or (and clojure-buffer (get-buffer clojure-buffer))
          (clojure-interactively-start-process))
      (pop-to-buffer clojure-buffer)
    (error "No current process buffer.  See variable `clojure-buffer'"))
  (when eob-p
    (push-mark)
    (goto-char (point-max))))

(defun clojure-send-definition ()
  "Send the current definition to the inferior Clojure process."
  (interactive)
  (save-excursion
    (end-of-defun)
    (let ((end (point)))
      (beginning-of-defun)
      (clojure-send-region (point) end))))

(defun clojure-send-definition-and-go ()
  (interactive)
  (clojure-send-definition)
  (switch-to-clojure t))

(defun clojure-document (symbol)
  (interactive
   (list (read-string "Document: " (thing-at-point 'symbol))))
  (let ((doc-command (format "(doc %s)\n" symbol)))
    (comint-send-string (clojure-proc) doc-command)))

(defun clojure-send-last-sexp ()
  "Send the previous sexp to the inferior Clojure process."
  (interactive)
  (clojure-send-region (save-excursion (backward-sexp) (point)) (point)))

(defun clojure-load-file (file-name)
  "Load a Clojure file FILE-NAME into the inferior Clojure process."
  (interactive (comint-get-source "Load Clojure file: " clojure-prev-l/c-dir/file
				  clojure-source-modes t)) ; t because `load'
                                                          ; needs an exact name
  (comint-check-source file-name) ; Check to see if buffer needs saved.
  (setq clojure-prev-l/c-dir/file (cons (file-name-directory    file-name)
                                        (file-name-nondirectory file-name)))
  (let ((load-command (format "(load-file \"%s\")\n" file-name)))
    (comint-send-string (clojure-proc) load-command)))

(defun clojure-form-at-point ()
  (let ((next-sexp (thing-at-point 'sexp)))
    (if (and next-sexp (string-equal (substring next-sexp 0 1) "("))
        (replace-regexp-in-string "[\r\n]" "" next-sexp)
      (save-excursion
        (backward-up-list)
        (clojure-form-at-point)))))

(defcustom clojure-macro-expand-command "(pprint (macroexpand '%s))"
  "macro expand function name"
  :type 'string
  :group 'inf-clojure)

(defun clojure-expand-current-form ()
  (interactive)
  (let ((current-form (clojure-form-at-point)))
    (if current-form
        (progn
          (comint-send-string (clojure-proc)
                              (format
                               clojure-macro-expand-command
                               current-form))
          (comint-send-string (clojure-proc) "\n"))
      (error "Not at a form"))))

(defun clojure-proc ()
  (unless (and clojure-buffer
               (get-buffer clojure-buffer)
               (comint-check-proc clojure-buffer))
    (clojure-interactively-start-process))
  (or (clojure-get-process)
      (error "No current process.  See variable `clojure-buffer'")))

(defun clojure-get-process ()
  "Return the current Clojure process or nil if none is running."
  (get-buffer-process (if (eq major-mode 'inferior-clojure-mode)
                          (current-buffer)
                        clojure-buffer)))

(defun clojure-interactively-start-process (&optional cmd)
  "Start an inferior clojure process.  Return the process started.
Since this command is run implicitly, always ask the user for the
command to run."
  (save-window-excursion
    (run-clojure (read-string "Run Clojure: " clojure-program-name))))

(defvar clojure-program-name "jark repl")
(defvar clojure-repl-name "*clojure*")

(defun run-clojure (cmd)
  (interactive (list (if current-prefix-arg
                         (read-string "Run clojure: " clojure-program-name)
                       clojure-program-name)))
  (if (not (comint-check-proc "*clojure*"))
      (let ((cmdlist (split-string-and-unquote cmd)))
        (set-buffer (apply 'make-comint "clojure" (car cmdlist)
                           (clojure-start-file (car cmdlist)) (cdr cmdlist)))
        (inferior-clojure-mode)))
  (setq clojure-program-name cmd)
  (setq clojure-buffer "*clojure*")
  (pop-to-buffer "*clojure*"))

(defun clojure-start-file (prog)
  (let* ((progname (file-name-nondirectory prog))
         (start-file (concat "~/.emacs_" progname))
         (alt-start-file (concat user-emacs-directory "init_" progname ".clj")))
    (if (file-exists-p start-file)
        start-file
      (and (file-exists-p alt-start-file) alt-start-file))))

(provide 'inf-clojure)
;;; inf-clojure.el ends here
