;;; org-analyzer.el --- Visualizes org-mode time tracking data.  -*- lexical-binding: t; -*-

;; Copyright (C) 2019  Robert Krahn

;; Author: Robert Krahn <robert@kra.hn>
;; URL: https://github.com/rksm/clj-org-analyzer
;; Keywords: calendar
;; Version: 0.3.5
;; Package-Requires: ((emacs "24"))

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to
;; deal in the Software without restriction, including without limitation the
;; rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
;; sell copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in
;; all copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
;; FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
;; IN THE SOFTWARE.

;;; Commentary:

;; org-analyzer is a tool that extracts time tracking data from org files (time
;; data recording with `org-clock-in', those lines that start with "CLOCK:"). It
;; then creates an interactive visualization of that data — outside of Emacs(!).
;;
;; In order to run the visualizer / parser you need to have java installed.
;;
;; This Emacs package provides a simple way to start the visualizer via
;; `org-analyzer-start' and feed it the default org files.
;;
;; See https://github.com/rksm/clj-org-analyzer for more information.

;;; Code:

(defvar org-analyzer-process-buffer nil
  "The buffer for running the jar.")

(defvar org-analyzer-version "0.3.5"
  "Version to sync with jar.")

(defvar org-analyzer-jar-file-name "org-analyzer.jar"
  "The name of the jar of the org-analyzer server.")

(defcustom org-analyzer-http-port
  8090
  "The org-analyzer HTTP port."
  :type 'int
  :group 'org-analyzer)

(defcustom org-analyzer-org-directory nil
  "The `org-directory' to use.
When nil, defaults to `org-directory'. When that is nil defaults to ~/org."
  :type 'string
  :group 'org-analyzer)

(defcustom org-analyzer-java-program "java"
  "What is java called on this system? Can be a full path."
  :type 'string
  :group 'org-analyzer)

(defun org-analyzer-effective-org-dir ()
  "Get the directory where org files are located."
  (or org-analyzer-org-directory
      (and (boundp 'org-directory) org-directory)
      (expand-file-name "~/org")))

(defun org-analyzer-locate-jar ()
  "Will try to find `org-analyzer-jar-file-name' on `load-path'."
  (locate-file org-analyzer-jar-file-name load-path))

(defun org-analyzer-cleanup-process-state ()
  "Kill the org-analyzer process + buffer."
  (when (buffer-live-p org-analyzer-process-buffer)
    (kill-buffer org-analyzer-process-buffer))
  (setq org-analyzer-process-buffer nil))

(defun org-analyzer-start-process (org-dir)
  "Start the org analyzer process .
Argument ORG-DIR is where the org-files are located."
  (org-analyzer-cleanup-process-state)
  (let ((jar-file (org-analyzer-locate-jar))
        (full-java-command (executable-find org-analyzer-java-program)))
    (unless jar-file
      (error "Can't find %s. Is the package correctly installed?"
             org-analyzer-jar-file-name))
    (unless full-java-command
      (error "Can't find java — please install it!"))
    (let* ((name (format " *org-analyzer [org-dir:%s]*" org-dir))
           (proc-buffer (generate-new-buffer name))
           (proc nil))
      (setq org-analyzer-process-buffer proc-buffer)
      (with-current-buffer proc-buffer
        (setq default-directory org-dir
              proc (condition-case err
                       (let ((process-connection-type nil)
                             (process-environment process-environment))
                         (start-process name
                                        (current-buffer)
                                        full-java-command
                                        "-jar"
                                        jar-file
                                        "--port"
                                        (format "%d" org-analyzer-http-port)
				        org-dir))
                     (error
                      (concat "Can't start org-analyzer (%s: %s)"
			      (car err) (cadr err)))))
        (set-process-query-on-exit-flag proc nil)
        (set-process-filter proc #'org-analyzer-process-filter))
      proc-buffer)))

(defun org-analyzer-process-filter (process output)
  "Filter to detect port collisons.
If org-analyzer can't start we put up the PROCESS buffer so the user knows.
Argument OUTPUT is the process output received."
  (let ((buffer (process-buffer process)))
    (when (and buffer
               (buffer-live-p buffer))
      (with-current-buffer buffer
        (goto-char (point-max))
        (insert output)
        (when (search-backward "Address already in use" nil t)
          (pop-to-buffer buffer))))))

;;;###autoload
(defun org-analyzer-start ()
  "Start org-analyzer."
  (interactive)
  (org-analyzer-start-process (org-analyzer-effective-org-dir)))

;; (pop-to-buffer org-analyzer-process-buffer)

(defun org-analyzer-stop ()
  "Stops the org analyzer process."
  (interactive)
  (org-analyzer-cleanup-process-state))


(provide 'org-analyzer)
;;; org-analyzer.el ends here
