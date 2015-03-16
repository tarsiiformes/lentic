;;; lentic-doc.el --- Generate and View Documentation -*- lexical-binding: t -*-

;;; Header:

;; This file is not part of Emacs

;; The contents of this file are subject to the GPL License, Version 3.0.

;; Copyright (C) 2015, Phillip Lord, Newcastle University

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Lentic's self-hosting documentation system.

;;; Code:

;; #+begin_src emacs-lisp
(require 'eww)
(require 'ox-html)
(require 'browse-url)
(require 'lentic)
(require 'lentic-org)
(require 'f)
;; #+end_src

;; ** Orgify Package

;; #+begin_src emacs-lisp
(defun lentic-doc-stringify (str-or-sym)
  (if (symbolp str-or-sym)
      (symbol-name str-or-sym)
    str-or-sym))

(defun lentic-doc-all-files-of-package (package)
  "Fetch all the files that are part of package.
This function assumes that all the files are in one place and
follow the standard naming convention of using the package name
as a prefix. "
  (let* ((main-file
          (locate-library package))
         (dir
          (f-parent main-file))
         (others
          (f-glob
           (concat dir "/" package "*.el"))))
    others))

(defun lentic-doc-orgify-if-necessary (file)
  (let* ((target
          (concat
           (file-name-sans-extension file)
           ".org"))
         (locked
          (or (file-locked-p file)
              (file-locked-p target)))
         (open
          (or
           (get-file-buffer file)
           (get-file-buffer target))))
    (unless (or locked open)
      (when (file-newer-than-file-p file target)
        (let ((lentic-kill-retain t))
          (lentic-batch-clone-and-save-with-config
           file 'lentic-orgel-org-init))))))

(defun lentic-doc-orgify-all-if-necessary (files)
  (-map 'lentic-doc-orgify-if-necessary files))

(defun lentic-doc-orgify-package (package)
  (lentic-doc-orgify-all-if-necessary
   (lentic-doc-all-files-of-package
    (lentic-doc-stringify package))))
;; #+end_src

;; ** htmlify package

;; #+begin_src: emacs-lisp
(defun lentic-doc-htmlify-package (package)
  (let ((package
         (lentic-doc-stringify package)))
    (lentic-doc-orgify-package package)
    (with-current-buffer
        (find-file-noselect
         (lentic-doc-package-start-source package))
      (let ((org-export-htmlize-generate-css 'css))
        (org-html-export-to-html)))))
;; #+end_src

;; #+begin_src
;; remove when it gets into f.el
(defun lentic-f-swap-ext (path ext)
  "Return PATH but with EXT as the new extension.
EXT must not be nil or empty."
  (if (s-blank? ext)
      (error "extension cannot be empty or nil.")
    (concat (f-no-ext path) "." ext)))

(defun lentic-doc-package-explicit-start-source (package)
  (let ((doc-var
         (intern
          (concat package "-doc"))))
    (if (boundp doc-var)
        ;; if it is set to a boolean return the implicit start
        (if (booleanp
             (symbol-value doc-var))
            (lentic-doc-package-implicit-start-source package)
          (symbol-value doc-var))
      ;; get the default
      (let*
          ((main-file
            (locate-library package))
           (doc-file
            (when main-file
              (concat
               (f-no-ext
                main-file)
               "-doc.org"))))
        (when
            (and doc-file
                 (f-exists? doc-file))
            doc-file)))))

(defun lentic-doc-package-implicit-start-source (package)
  (lentic-f-swap-ext
   (locate-library package)
   "org"))

(defun lentic-doc-package-start-source (package)
  (or (lentic-doc-package-explicit-start-source package)
      (lentic-doc-package-implicit-start-source package)))

(defun lentic-doc-package-doc-file (package)
  (lentic-f-swap-ext
   (lentic-doc-package-start-source package)
   "html"))

(defun lentic-doc-ensure-doc (package)
  (unless (f-exists?
           (lentic-doc-package-doc-file package))
    (lentic-doc-htmlify-package package)))

(defvar lentic-doc-lentic-features nil)
(defun lentic-doc-all-lentic-features-capture()
  (setq lentic-doc-lentic-features
        (cons
         (length features)
         (-map
          (lambda (feat)
            (symbol-name feat))
          (-filter
           (lambda (feat)
             (lentic-doc-package-explicit-start-source feat))
           features)))))

(defun lentic-doc-all-lentic-features ()
  (unless
      (and lentic-doc-lentic-features
           (equal
            (car lentic-doc-lentic-features)
            (length features)))
    (lentic-doc-all-lentic-features-capture))
  (cdr lentic-doc-lentic-features))

(defun lentic-doc-external-view-package (package)
  (interactive
   (list
    (completing-read
     "Package Name: "
     (lentic-doc-all-lentic-features))))
  (lentic-doc-ensure-doc package)
  (browse-url-default-browser
   (lentic-doc-package-doc-file package)))

(defun lentic-doc-eww-view-package (package)
  (interactive
   (list
    (completing-read
     "Package Name: "
     (lentic-doc-all-lentic-features))))
  (lentic-doc-ensure-doc package)
  (eww-open-file
   (lentic-doc-package-doc-file package)))
;; #+end_src

;; ** lentic self-doc

;; #+begin_src: emacs-lisp
;;;###autoload
(defun lentic-doc-eww-view ()
  (interactive)
  (lentic-doc-eww-view-package 'lentic))

;;;###autoload
(defun lentic-doc-external-view ()
  (interactive)
  (lentic-doc-external-view-package 'lentic))

(provide 'lentic-doc)
;; #+end_src
