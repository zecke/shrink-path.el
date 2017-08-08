;;; shrink-path.el --- fish-style path -*- lexical-binding: t; -*-

;; Copyright (C) 2017 Benjamin Andresen

;; Author: Benjamin Andresen
;; Version: 0.2.1
;; Keywords: path
;; URL: http://github.com/shrink-path.el/shrink-path.el
;; Package-Requires: ((s "1.6.1") (dash "1.8.0") (f "0.10.0"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:
;;; No commentary

;;; Code:
(require 'dash)
(require 's)
(require 'f)
(require 'rx)

(defun shrink-path--truncate (str)
  "Return STR's first character or first two characters if hidden."
  (substring str 0 (if (s-starts-with? "." str) 2 1)))

(defun shrink-path--dirs-internal (full-path &optional truncate-all)
  "Return fish-style truncated string based on FULL-PATH.
Optional parameter TRUNCATE-ALL will cause the function to truncate the last
directory too."
  (let* ((home (getenv "HOME"))
         (path (replace-regexp-in-string
                (s-concat "^" home) "~" full-path))
         (split (s-split "/" path 'omit-nulls))
         (split-len (length split))
         shrunk)
    (->> split
         (--map-indexed (if (= it-index (1- split-len))
                            (if truncate-all (shrink-path--truncate it) it)
                          (shrink-path--truncate it)))
         (s-join "/")
         (setq shrunk))
    (s-concat (unless (s-matches? (rx bos (or "~" "/")) shrunk) "/")
              shrunk
              (unless (s-ends-with? "/" shrunk) "/"))))


;;;###autoload
(defun shrink-path-dirs (&optional path truncate-tail)
  "Given PATH return fish-styled shrunken down path.
TRUNCATE-TAIL will cause the function to truncate the last directory too."
  (let* ((path (or path default-directory))
         (path (f-full path)))
    (cond
     ((s-equals? (f-short path) "/") "/")
     ((s-matches? (rx bos (or "~" "/") eos) "~/"))
     (t (shrink-path--dirs-internal path truncate-tail)))))

;;;###autoload
(defun shrink-path-expand (str &optional absolute-p)
  "Return expanded path from STR if found or list of matches on multiple.
The path referred to by STR has to exist for this to work.
If ABSOLUTE-P is t the returned path will be absolute."
  (let* ((str-split (s-split "/" str 'omit-nulls))
         (head (car str-split)))
    (if (= (length str-split) 1)
        (s-concat "/" str-split)
      (-as-> (-drop 1 str-split) it
             (s-join "*/" it)
             (s-concat (if (s-equals? head "~") "~/" head) it)
             (f-glob it)
             (if absolute-p (-map #'f-full it) (-map #'f-abbrev it))
             (if (= (length it) 1) (car it) it)))))

;;;###autoload
(defun shrink-path-prompt (&optional pwd)
  "Return cons of BASE and DIR for PWD.
If PWD isn't provided will default to `default-directory'."
  (let* ((pwd (or pwd default-directory))
         (shrunk (shrink-path-dirs pwd))
         (split (-as-> shrunk it (s-split "/" it 'omit-nulls)))
         base dir)
    (setq dir (or (-last-item split) "/"))
    (setq base (if (s-equals? dir "/") ""
                 (s-chop-suffix (s-concat dir "/") shrunk)))
    (cons base dir)))

;;;###autoload
(defun shrink-path-file (file &optional truncate-tail)
  "Return FILE's shrunk down path and filename.
TRUNCATE-TAIL controls if the last directory should also be shortened."
  (let ((filename (f-filename file))
        (dirname (f-dirname file)))
    (s-concat (shrink-path-dirs dirname truncate-tail) filename)))

;;;###autoload
(defun shrink-path-file-expand (str &optional exists-p absolute-p)
  "Return STR's expanded filename.
The path referred to by STR has to exist for this to work.
If EXISTS-P is t the filename also has to exist.
If ABSOLUTE-P is t the returned path will be absolute."
  (let ((expanded (shrink-path-expand str absolute-p)))
    (if exists-p
        (if (f-exists? expanded) expanded)
      expanded)))

(provide 'shrink-path)
;;; shrink-path.el ends here
