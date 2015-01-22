;;; emacspeak-xslt.el --- Implements Emacspeak  xslt transform engine
;;; $Id: emacspeak-xslt.el 8574 2013-11-24 02:01:07Z tv.raman.tv $
;;; $Author: tv.raman.tv $
;;; Description:  xslt transformation routines
;;; Keywords: Emacspeak,  Audio Desktop XSLT
;;{{{  LCD Archive entry:

;;; LCD Archive Entry:
;;; emacspeak| T. V. Raman |raman@cs.cornell.edu
;;; A speech interface to Emacs |
;;; $Date: 2008-08-12 10:48:54 -0700 (Tue, 12 Aug 2008) $ |
;;;  $Revision: 4562 $ |
;;; Location undetermined
;;;

;;}}}
;;{{{  Copyright:
;;;Copyright (C) 1995 -- 2011, T. V. Raman
;;; Copyright (c) 1994, 1995 by Digital Equipment Corporation.
;;; All Rights Reserved.
;;;
;;; This file is not part of GNU Emacs, but the same permissions apply.
;;;
;;; GNU Emacs is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 2, or (at your option)
;;; any later version.
;;;
;;; GNU Emacs is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Emacs; see the file COPYING.  If not, write to
;;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;;}}}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;{{{  introduction

;;; libxml and libxsl are XML libraries for GNOME.
;;; xsltproc is a  xslt processor using libxsl
;;; this module defines routines for applying xsl transformations
;;; using xsltproc

;;}}}
;;{{{  Required modules

(require 'emacspeak-preamble)
(require 'emacspeak-webutils)

;;}}}
;;{{{  xslt Environment:

(defgroup emacspeak-xslt nil
  "XSL transformation group."
  :group 'emacspeak)

(defsubst emacspeak-xslt-params-from-xpath (path base)
  "Return params suitable for passing to  emacspeak-xslt-region"
  (list
   (cons "path"
         (format "\"'%s'\""
                 (shell-quote-argument path)))
   (cons "locator"
         (format "'%s'"
                 path))
   (cons "base"
         (format "\"'%s'\""
                 base))))
(declaim (special emacspeak-xslt-directory))
;;;###autoload
(defsubst emacspeak-xslt-get (style)
  "Return fully qualified stylesheet path."
  (declare (special emacspeak-xslt-directory))
  (expand-file-name style emacspeak-xslt-directory))

(defsubst emacspeak-xslt-read ()
  "Read XSLT transformation name from minibuffer."
  (declare (special emacspeak-xslt-directory))
  (expand-file-name
   (read-file-name "XSL Transformation: "
                   emacspeak-xslt-directory
                   emacspeak-we-xsl-transform)))

(defcustom emacspeak-xslt-program "xsltproc"
  "Name of XSLT transformation engine."
  :type 'string
  :group 'emacspeak-xslt)

;;;###autoload
(defcustom emacspeak-xslt-options
  "--html --nonet --novalid --encoding utf-8"
  "Options passed to xsltproc."
  :type 'string
  :group 'emacspeak-xslt)

(defcustom emacspeak-xslt-keep-errors  nil
  "If non-nil, xslt errors will be preserved in an errors buffer."
  :type 'boolean
  :group 'emacspeak-xslt)

(defcustom emacspeak-xslt-nuke-null-char t
  "If T null chars in the region will be nuked.
This is useful when handling bad HTML."
  :type 'boolean
  :group 'emacspeak-xslt)

;;}}}
;;{{{ Functions:

;;;###autoload
(defun emacspeak-xslt-region (xsl start end &optional params no-comment)
  "Apply XSLT transformation to region and replace it with
the result.  This uses XSLT processor xsltproc available as
part of the libxslt package."
  (declare (special emacspeak-xslt-program emacspeak-xslt-options
                    emacspeak-xslt-keep-errors modification-flag ))
  (let ((command nil)
        (parameters (when params
                      (mapconcat
                       #'(lambda (pair)
                           (format "--param %s %s "
                                   (car pair)
                                   (cdr pair)))
                       params
                       " ")))
        (coding-system-for-write 'utf-8)
        (coding-system-for-read 'utf-8)
        (buffer-file-coding-system 'utf-8))
    (setq command
          (format
           "%s %s  %s  %s - %s"
           emacspeak-xslt-program
           (or emacspeak-xslt-options "")
           (or parameters "")
           xsl
           (unless  emacspeak-xslt-keep-errors " 2>/dev/null ")))
    (shell-command-on-region
     start end
     command
     (current-buffer)
     'replace
     (when emacspeak-xslt-keep-errors "*xslt errors*"))
    (when (get-buffer  "*xslt errors*")
      (bury-buffer "*xslt errors*"))
    (unless no-comment
      (goto-char (point-max))
      (insert
       (format "<!--\n %s \n-->\n"
               command)))
    (setq modification-flag nil)
    (set-buffer-multibyte t)
    (current-buffer)))

;;;###autoload
(defsubst emacspeak-xslt-run (xsl &optional start end)
  "Run xslt on region, and return output filtered by sort -u.
Region defaults to entire buffer."
  (declare (special emacspeak-xslt-program emacspeak-xslt-options))
  (or start (setq start (point-min)))
  (or end (setq end (point-max)))
  (let ((coding-system-for-read 'utf-8)
        (coding-system-for-write 'utf-8)
        (buffer-file-coding-system 'utf-8))
    (shell-command-on-region
     start end
     (format "%s %s %s - 2>/dev/null | sort -u"
             emacspeak-xslt-program emacspeak-xslt-options xsl)
     (current-buffer) 'replace)
    (set-buffer-multibyte t)
    (current-buffer)))

;;; uses wget in a pipeline to avoid libxml2 bug:
;;;###autoload
(defcustom  emacspeak-xslt-use-wget-to-download nil
  "Set to T if you want to avoid URL downloader bugs in libxml2.
There is a bug that bites when using Yahoo Maps that wget can
work around."
  :group 'emacspeak-xslt
  :type 'boolean)

;;;###autoload
(defun emacspeak-xslt-url (xsl url &optional params no-comment)
  "Apply XSLT transformation to url
and return the results in a newly created buffer.
  This uses XSLT processor xsltproc available as
part of the libxslt package."
  (declare (special emacspeak-xslt-program
                    emacspeak-xslt-use-wget-to-download
                    modification-flag
                    emacspeak-xslt-keep-errors))
  (let ((result (get-buffer-create " *xslt result*"))
        (command nil)
        (parameters (when params
                      (mapconcat
                       #'(lambda (pair)
                           (format "--param %s %s "
                                   (car pair)
                                   (cdr pair)))
                       params
                       " "))))
    (if emacspeak-xslt-use-wget-to-download
        (setq command (format
                       "wget -U mozilla -q -O - '%s' | %s %s    --html --novalid %s '%s' %s"
                       url
                       emacspeak-xslt-program
                       (or parameters "")
                       xsl "-"
                       (unless emacspeak-xslt-keep-errors " 2>/dev/null ")))
      (setq command
            (format
             "%s %s    --html --novalid %s '%s' %s"
             emacspeak-xslt-program
             (or parameters "")
             xsl url
             (unless emacspeak-xslt-keep-errors " 2>/dev/null "))))
    (save-current-buffer
      (set-buffer result)
      (kill-all-local-variables)
      (erase-buffer)
      (setq buffer-undo-list t)
      (let ((coding-system-for-write 'utf-8)
            (coding-system-for-read 'utf-8)
            (buffer-file-coding-system 'utf-8))
        (shell-command
         command (current-buffer)
         (when emacspeak-xslt-keep-errors "*xslt errors*"))
        (when emacspeak-xslt-nuke-null-char
          (goto-char (point-min))
          (while (search-forward
                  ( format "%c" 0)
                  nil  t)
            (replace-match " "))))
      (when (get-buffer  "*xslt errors*")
        (bury-buffer "*xslt errors*"))
      (goto-char (point-max))
      (unless no-comment
        (insert
         (format "<!--\n %s \n-->\n"
                 command)))
      (setq modification-flag nil)
      (set-buffer-multibyte t)
      (goto-char (point-min))
      result)))

;;;###autoload
(defun emacspeak-xslt-xml-url (xsl url &optional params)
  "Apply XSLT transformation to XML url
and return the results in a newly created buffer.
  This uses XSLT processor xsltproc available as
part of the libxslt package."
  (declare (special emacspeak-xslt-program
                    modification-flag emacspeak-xslt-use-wget-to-download
                    emacspeak-xslt-keep-errors))
  (let ((result (get-buffer-create " *xslt result*"))
        (command nil)
        (parameters (when params
                      (mapconcat
                       #'(lambda (pair)
                           (format "--param %s %s "
                                   (car pair)
                                   (cdr pair)))
                       params
                       " "))))
    (if emacspeak-xslt-use-wget-to-download
        (setq command
              (format
               "wget -q -O - '%s' | %s %s --novalid %s %s %s"
               url
               emacspeak-xslt-program
               (or parameters "")
               xsl "-"
               (unless emacspeak-xslt-keep-errors " 2>/dev/null ")))
      (setq command
            (format
             "%s %s --novalid %s '%s' %s"
             emacspeak-xslt-program
             (or parameters "")
             xsl url
             (unless emacspeak-xslt-keep-errors " 2>/dev/null "))))
    (save-current-buffer
      (set-buffer result)
      (kill-all-local-variables)
      (erase-buffer)
      (let ((coding-system-for-write 'utf-8)
            (coding-system-for-read 'utf-8)
            (buffer-file-coding-system 'utf-8))
        (shell-command
         command (current-buffer)
         (when emacspeak-xslt-keep-errors
           "*xslt errors*")))
      (when (get-buffer  "*xslt errors*")
        (bury-buffer "*xslt errors*"))
      (goto-char (point-max))
      (insert
       (format "<!--\n %s \n-->\n"
               command))
      (setq modification-flag nil)
      (goto-char (point-min))
      (set-buffer-multibyte t)
      result)))

;;}}}
;;{{{ interactive commands:

;;;###autoload
(defun emacspeak-xslt-view-file(style file)
  "Transform `file' using `style' and preview via browse-url."
  (interactive
   (list
    (read-file-name "Style File: "
                    emacspeak-xslt-directory)
    (read-file-name "File:" default-directory)))
  (declare (special emacspeak-xslt-directory))
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8)
          (coding-system-for-write 'utf-8)
          (buffer-file-coding-system 'utf-8))
      (insert-file file)
      (shell-command
       (format "%s   --novalid --nonet --param base %s  %s  %s  2>/dev/null"
               emacspeak-xslt-program 
               (format "\"'file://%s'\"" (expand-file-name file))
               (expand-file-name style)
               (expand-file-name file))
       (current-buffer) 'replace)
      (set-buffer-multibyte t)
      (browse-url-of-buffer))))

;;;###autoload
(defun emacspeak-xslt-view (style url)
  "Browse URL with specified XSL style."
  (interactive
   (list
    (expand-file-name
     (read-file-name "XSL Transformation: "
                     emacspeak-xslt-directory))
    (read-string "URL: " (browse-url-url-at-point))))
  (declare (special emacspeak-xslt-options
                    emacspeak-xslt-directory))
  (emacspeak-webutils-with-xsl-environment
   style
   nil
   emacspeak-xslt-options
   (browse-url url)))

;;;###autoload
(defun emacspeak-xslt-view-xml (style url &optional unescape-charent)
  "Browse XML URL with specified XSL style."
  (interactive
   (list
    (emacspeak-xslt-read)
    (emacspeak-webutils-read-this-url)
    current-prefix-arg))
  (let ((src-buffer
         (emacspeak-xslt-xml-url
          style
          url
          (list
           (cons "base"
                 (format "\"'%s'\""
                         url))))))
    (when (ems-interactive-p ) (emacspeak-webutils-autospeak))
    (save-current-buffer
      (set-buffer src-buffer)
      (when unescape-charent
        (emacspeak-webutils-unescape-charent (point-min) (point-max)))
      (emacspeak-webutils-without-xsl
       (browse-url-of-buffer)))
    (kill-buffer src-buffer)))

;;;###autoload
(defun emacspeak-xslt-view-region (style start end &optional unescape-charent)
  "Browse XML region with specified XSL style."
  (interactive
   (list
    (emacspeak-xslt-read)
    (point)
    (mark)
    current-prefix-arg))
  (let ((src-buffer
         (with-silent-modifications
           (emacspeak-xslt-region style start end))))
    (save-current-buffer
      (set-buffer src-buffer)
      (when unescape-charent
        (emacspeak-webutils-unescape-charent (point-min) (point-max)))
      (emacspeak-webutils-without-xsl
       (browse-url-of-buffer)))
    (kill-buffer src-buffer)))

;;}}}
(provide 'emacspeak-xslt)
;;{{{ end of file

;;; local variables:
;;; folded-file: t
;;; byte-compile-dynamic: nil
;;; end:

;;}}}
