;;; emacspeak-we.el --- Transform Web Pages Using XSLT
;;; $Id: emacspeak-we.el 8146 2013-02-09 20:05:08Z tv.raman.tv $
;;; $Author: tv.raman.tv $
;;; Description:  Edit/Transform Web Pages using XSLT
;;; Keywords: Emacspeak,  Audio Desktop Web, XSLT
;;{{{  LCD Archive entry:

;;; LCD Archive Entry:
;;; emacspeak| T. V. Raman |raman@cs.cornell.edu
;;; A speech interface to Emacs |
;;; $Date: 2008-08-04 09:12:03 -0700 (Mon, 04 Aug 2008) $ |
;;;  $Revision: 4532 $ |
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

;;; Commentary:
;;; we is for webedit
;;; Invoke XSLT to edit/transform Web pages before they get
;;; rendered.
;;; we makes emacspeak's webedit layer independent of a given
;;; Emacs web browser like W3 or W3M
;;; This module will use the abstraction provided by browse-url
;;; to handle Web pages.
;;; Module emacspeak-webutils provides the needed additional
;;; abstractions not already covered by browse-url

;;; Code:

;;}}}
;;{{{  Required modules

(require 'cl)
(declaim  (optimize  (safety 0) (speed 3)))
(require 'emacspeak-preamble)
(require 'emacspeak-xslt)
(require 'emacspeak-webutils)

;;}}}
;;{{{ URL Rewrite:

;;;###autoload
(defun emacspeak-we-url-rewrite-and-follow (&optional prompt)
  "Apply a url rewrite rule as specified in the current buffer
before following link under point.  If no rewrite rule is
defined, first prompt for one.  Rewrite rules are of the
form `(from to)' where from and to are strings.  Typically, the
rewrite rule is automatically set up by Emacspeak tools like
websearch where a rewrite rule is known.  Rewrite rules are
useful in jumping directly to the printer friendly version of an
article for example.  Optional interactive prefix arg prompts for
a rewrite rule even if one is already defined."
  (interactive "P")
  (declare (special emacspeak-we-url-rewrite-rule))
  (emacspeak-webutils-browser-check)
  (let ((url (funcall emacspeak-webutils-url-at-point))
        (redirect nil))
    (unless url (error "Not on a link."))
    (when (or prompt (null emacspeak-we-url-rewrite-rule))
      (setq emacspeak-we-url-rewrite-rule
            (read-minibuffer  "Specify rewrite rule: " "(")))
    (setq redirect
          (replace-regexp-in-string
           (first emacspeak-we-url-rewrite-rule)
           (second emacspeak-we-url-rewrite-rule)
           url))
    (emacspeak-auditory-icon 'select-object)
    (browse-url (or redirect url))))

;;}}}
;;{{{ url expand and execute

(defvar emacspeak-we-url-executor nil
  "URL expand/execute function  to use in current buffer.")

(make-variable-buffer-local 'emacspeak-we-url-executor)

(defun emacspeak-we-url-expand-and-execute ()
  "Applies buffer-specific URL expander/executor function."
  (interactive)
  (declare (special emacspeak-we-url-executor))
  (emacspeak-webutils-browser-check)
  (let ((url (funcall emacspeak-webutils-url-at-point)))
    (unless url (error "Not on a link."))
    (cond
     ((and (boundp 'emacspeak-we-url-executor)
           (fboundp emacspeak-we-url-executor))
      (funcall emacspeak-we-url-executor url))
     (t
      (setq emacspeak-we-url-executor
            (intern
             (completing-read
              "Executor function: "
              obarray 'fboundp t
              "emacspeak-" nil )))
      (if (and (boundp 'emacspeak-we-url-executor)
               (fboundp emacspeak-we-url-executor))
          (funcall emacspeak-we-url-executor url)
        (error "Invalid executor %s"
               emacspeak-we-url-executor))))))

;;}}}
;;{{{ applying XSL transforms before displaying

(define-prefix-command 'emacspeak-we-xsl-map )

(defvar emacspeak-we-xsl-filter
  (emacspeak-xslt-get "xpath-filter.xsl")
  "XSL to extract  elements matching a specified XPath locator.")

(defvar emacspeak-we-xsl-junk
  (emacspeak-xslt-get "xpath-junk.xsl")
  "XSL to junk  elements matching a specified XPath locator.")
(defgroup emacspeak-we nil
  "Emacspeak WebEdit"
  :group 'emacspeak)

;;;###autoload
(defcustom emacspeak-we-xsl-p nil
  "T means we apply XSL before displaying HTML."
  :type 'boolean
  :group 'emacspeak-we)

;;;###autoload
(defcustom emacspeak-we-xsl-transform nil
  "Specifies transform to use before displaying a page.
Nil means no transform is used. "
  :type  '(choice
           (file :tag "XSL")
           (const :tag "none" nil))
  :group 'emacspeak-we)

;;;###autoload
(defvar emacspeak-we-xsl-params nil
  "XSL params if any to pass to emacspeak-xslt-region.")

;;; Note that emacspeak-we-xsl-transform, emacspeak-we-xsl-params
;;; and emacspeak-we-xsl-p
;;; need to be set at top-level since the page-rendering code is
;;; called asynchronously.

;;;###autoload
(defcustom emacspeak-we-cleanup-bogus-quotes t
  "Clean up bogus Unicode chars for magic quotes."
  :type 'boolean
  :group 'emacspeak-we)

;;;###autoload
(defun emacspeak-we-xslt-apply (xsl)
  "Apply specified transformation to current Web page."
  (interactive (list (emacspeak-xslt-read)))
  (emacspeak-webutils-browser-check)
  (emacspeak-webutils-with-xsl-environment
   xsl
   nil
   emacspeak-xslt-options
   (browse-url (funcall emacspeak-webutils-current-url))))

;;;###autoload
(defun emacspeak-we-xslt-select (xsl)
  "Select XSL transformation applied to Web pages before they are displayed ."
  (interactive (list (emacspeak-xslt-read)))
  (declare (special emacspeak-we-xsl-transform))
  (setq emacspeak-we-xsl-transform xsl)
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'select-object)
    (message "Will apply %s before displaying HTML pages."
             (file-name-sans-extension
              (file-name-nondirectory xsl)))))

;;;###autoload
(defun emacspeak-we-xsl-toggle ()
  "Toggle  application of XSL transformations."
  (interactive)
  (declare (special emacspeak-we-xsl-p))
  (setq emacspeak-we-xsl-p (not emacspeak-we-xsl-p))
  (when (ems-interactive-p )
    (emacspeak-auditory-icon
     (if emacspeak-we-xsl-p 'on 'off))
    (message "Turned %s XSL"
             (if emacspeak-we-xsl-p 'on 'off))))

;;;###autoload
(defun emacspeak-we-count-matches (url locator)
  "Count matches for locator  in Web page."
  (interactive
   (list
    (emacspeak-webutils-read-url)
    (read-from-minibuffer "XPath locator: ")))
  (read
   (emacspeak-xslt-url
    (emacspeak-xslt-get "count-matches.xsl")
    url
    (emacspeak-xslt-params-from-xpath locator url)
    'no-comment)))

;;;###autoload
(defun emacspeak-we-count-nested-tables (url)
  "Count nested tables in Web page."
  (interactive (list (emacspeak-webutils-read-url)))
  (emacspeak-we-count-matches url "'//table//table'"))

;;;###autoload
(defun emacspeak-we-count-tables (url)
  "Count  tables in Web page."
  (interactive (list (emacspeak-webutils-read-url)))
  (emacspeak-we-count-matches url "//table"))

;;;###autoload
(defvar emacspeak-we-xsl-keep-result nil
  "Toggle via command \\[emacspeak-we-toggle-xsl-keep-result].")

;;;###autoload
(defun emacspeak-we-toggle-xsl-keep-result ()
  "Toggle xsl keep result flag."
  (interactive)
  (declare (special emacspeak-we-xsl-keep-result))
  (setq emacspeak-we-xsl-keep-result
        (not emacspeak-we-xsl-keep-result))
  (when (ems-interactive-p )
    (emacspeak-auditory-icon
     (if emacspeak-we-xsl-keep-result
         'on 'off))
    (message "Turned %s xslt keep results."
             (if emacspeak-we-xsl-keep-result
                 'on 'off))))
(defcustom emacspeak-we-filters-rename-buffer nil
  "Set to T  if you want the buffer name to contain the applied filter."
  :type  'boolean
  :group 'emacspeak-we)

;;;###autoload
(defun emacspeak-we-xslt-filter (path    url  &optional speak)
  "Extract elements matching specified XPath path locator
from Web page -- default is the current page being viewed."
  (interactive
   (list
    (read-from-minibuffer "XPath: ")
    (emacspeak-webutils-read-url)
    current-prefix-arg))
  (declare (special emacspeak-we-xsl-filter
                    emacspeak-we-filters-rename-buffer))
  (let ((params (emacspeak-xslt-params-from-xpath  path url)))
    (when emacspeak-we-filters-rename-buffer(emacspeak-webutils-rename-buffer (format "Filtered %s" path)))
    (when speak (emacspeak-webutils-autospeak))
    (emacspeak-webutils-with-xsl-environment
     emacspeak-we-xsl-filter
     params
     emacspeak-xslt-options             ;options
     (browse-url url))))

;;;###autoload
(defun emacspeak-we-xslt-junk (path    url &optional speak)
  "Junk elements matching specified locator."
  (interactive
   (list
    (read-from-minibuffer "XPath: ")
    (emacspeak-webutils-read-url)
    (ems-interactive-p )))
  (declare (special emacspeak-we-xsl-junk ))
  (let ((params (emacspeak-xslt-params-from-xpath  path url)))
    (emacspeak-webutils-rename-buffer
     (format "Filtered %s" path))
    (when speak (emacspeak-webutils-autospeak))
    (emacspeak-webutils-with-xsl-environment
     emacspeak-we-xsl-junk
     params
     emacspeak-xslt-options
     (browse-url url))))

(defcustom emacspeak-we-media-stream-suffixes
  (list
   ".ram"
   ".rm"
   ".ra"
   ".pls"
   ".asf"
   ".asx"
   ".mp3"
   ".m3u"
   ".m4v"
   ".wma"
   ".wmv"
   ".avi"
   ".mpg")
  "Suffixes that identify   URLs   to media streams."
  :type  '(repeat
           (string :tag "Extension Suffix"))
  :group 'emacspeak-we)

;;;###autoload
(defun emacspeak-we-extract-media-streams (url &optional speak)
  "Extract links to media streams.
operate on current web page when in a browser buffer; otherwise
 prompt for url.  Optional arg `speak' specifies if the result
 should be spoken automatically."
  (interactive
   (list
    (emacspeak-webutils-read-url)
    (ems-interactive-p )))
  (declare (special emacspeak-we-media-stream-suffixes))
  (let ((filter "//a[%s]")
        (predicate
         (mapconcat
          #'(lambda (suffix)
              (format "contains(@href,\"%s\")"
                      suffix))
          emacspeak-we-media-stream-suffixes
          " or ")))
    (emacspeak-we-xslt-filter
     (format filter predicate )
     url speak)))

;;;###autoload
(defun emacspeak-we-extract-print-streams (url &optional speak)
  "Extract links to printable  streams.
operate on current web page when in a browser buffer; otherwise
 prompt for url.  Optional arg `speak' specifies if the result
 should be spoken automatically."
  (interactive
   (list
    (emacspeak-webutils-read-url)
    (ems-interactive-p )))
  (let ((filter "//a[contains(@href,\"print\")]"))
    (emacspeak-we-xslt-filter filter url speak)))

;;;###autoload
(defun emacspeak-we-extract-media-streams-under-point ()
  "In browser buffers, extract media streams from url under point."
  (interactive)
  (emacspeak-webutils-browser-check)
  (emacspeak-we-extract-media-streams
   (funcall emacspeak-webutils-url-at-point)
   'speak))

;;;###autoload
(defun emacspeak-we-extract-matching-urls (pattern url &optional speak)
  "Extracts links whose URL matches pattern."
  (interactive
   (list
    (read-from-minibuffer "Pattern: ")
    (emacspeak-webutils-read-url)
    (ems-interactive-p )))
  (let ((filter
         (format
          "//a[contains(@href,\"%s\")]"
          pattern)))
    (emacspeak-we-xslt-filter filter url speak)))

;;;###autoload
(defun emacspeak-we-extract-nested-table (index   url &optional speak)
  "Extract nested table specified by `table-index'. Default is to
operate on current web page when in a browser buffer; otherwise
prompt for URL. Optional arg `speak' specifies if the result should be
spoken automatically."
  (interactive
   (list
    (read-from-minibuffer "Table Index: ")
    (emacspeak-webutils-read-url)
    (ems-interactive-p )))
  (emacspeak-we-xslt-filter
   (format "(//table//table)[%s]" index)
   url speak))

(defsubst  emacspeak-we-get-table-list (&optional bound)
  "Collect a list of numbers less than bound
 by prompting repeatedly in the
minibuffer.
Empty value finishes the list."
  (let ((result nil)
        (i nil)
        (done nil))
    (while (not done)
      (setq i
            (read-from-minibuffer
             (format "Index%s"
                     (if bound
                         (format " less than  %s" bound)
                       ":"))))
      (if (> (length i) 0)
          (push i result)
        (setq done t)))
    result))

(defsubst  emacspeak-we-get-table-match-list ()
  "Collect a list of matches by prompting repeatedly in the
minibuffer.
Empty value finishes the list."
  (let ((result nil)
        (i nil)
        (done nil))
    (while (not done)
      (setq i
            (read-from-minibuffer "Match: "))
      (if (> (length i) 0)
          (push i result)
        (setq done t)))
    result))

;;;###autoload
(defun emacspeak-we-extract-nested-table-list (tables url &optional speak)
  "Extract specified list of tables from a Web page."
  (interactive
   (list
    (emacspeak-we-get-table-list)
    (emacspeak-webutils-read-url)
    (ems-interactive-p )))
  (let ((filter
         (mapconcat
          #'(lambda  (i)
              (format "((//table//table)[%s])" i))
          tables
          " | ")))
    (emacspeak-we-xslt-filter filter url speak)))

;;;###autoload
(defun emacspeak-we-extract-table-by-position (position   url
                                                          &optional speak)
  "Extract table at specified position.
Default is to extract from current page."
  (interactive
   (list
    (read-from-minibuffer "Extract Table: ")
    (emacspeak-webutils-read-url)
    current-prefix-arg))
  (emacspeak-we-xslt-filter
   (format "/descendant::table[%s]"
           position)
   url
   speak))

;;;###autoload
(defun emacspeak-we-extract-tables-by-position-list (positions url &optional speak)
  "Extract specified list of nested tables from a WWW page.
Tables are specified by their position in the list
 of nested tables found in the page."
  (interactive
   (list
    (emacspeak-we-get-table-list)
    (emacspeak-webutils-read-url)
    current-prefix-arg))
  (let ((filter
         (mapconcat
          #'(lambda  (i)
              (format "(/descendant::table[%s])" i))
          positions
          " | ")))
    (emacspeak-we-xslt-filter
     filter
     url
     (or (ems-interactive-p )
         speak))))

;;;###autoload
(defun emacspeak-we-extract-table-by-match (match   url &optional speak)
  "Extract table containing  specified match.
 Optional arg url specifies the page to extract content from."
  (interactive
   (list
    (read-from-minibuffer "Tables Matching: ")
    (emacspeak-webutils-read-url)
    current-prefix-arg))
  (emacspeak-we-xslt-filter
   (format "(/descendant::table[contains(., \"%s\")])[last()]"
           match)
   url
   (or (ems-interactive-p )
       speak)))

;;;###autoload
(defun emacspeak-we-extract-tables-by-match-list (match-list
                                                  url &optional speak)
  "Extract specified  tables from a WWW page.
Tables are specified by containing  match pattern
 found in the match list."
  (interactive
   (list
    (emacspeak-we-get-table-match-list)
    (emacspeak-webutils-read-url)
    current-prefix-arg))
  (let ((filter
         (mapconcat
          #'(lambda  (i)
              (format "((/descendant::table[contains(.,\"%s\")])[last()])" i))
          match-list
          " | ")))
    (emacspeak-we-xslt-filter
     filter
     url
     (or (ems-interactive-p )
         speak))))

(defvar emacspeak-we-buffer-class-cache nil
  "Caches class attribute values for current buffer.")

(make-variable-buffer-local 'emacspeak-we-buffer-class-cache)

(defsubst emacspeak-we-build-class-cache ()
  "Build class cache and forward it to rendered page."
  (let ((values nil)
        (content (clone-buffer)))
    (save-excursion
      (set-buffer content)
      (setq buffer-undo-list t)
      (emacspeak-xslt-run
       (emacspeak-xslt-get "class-values.xsl")
       (point-min) (point-max))
      (goto-char (point-min))
      (skip-syntax-forward " ")
      (delete-region (point-min) (point))
      (setq values (split-string (buffer-string))))
    (add-hook
     'emacspeak-web-post-process-hook
     (eval
      `(function
        (lambda nil
          (declare (special  emacspeak-we-buffer-class-cache))
          (setq emacspeak-we-buffer-class-cache
                ',(copy-sequence values))))))
    (kill-buffer content)))

(defvar emacspeak-we-buffer-id-cache nil
  "Caches id attribute values for current buffer.")

(make-variable-buffer-local 'emacspeak-we-buffer-id-cache)

(defsubst emacspeak-we-build-id-cache ()
  "Build id cache and forward it to rendered page."
  (let ((values nil)
        (content (clone-buffer)))
    (save-excursion
      (set-buffer content)
      (setq buffer-undo-list t)
      (emacspeak-xslt-run
       (emacspeak-xslt-get "id-values.xsl")
       (point-min) (point-max))
      (setq values (split-string (buffer-string))))
    (add-hook
     'emacspeak-web-post-process-hook
     (eval
      `(function
        (lambda nil
          (declare (special  emacspeak-we-buffer-id-cache))
          (setq emacspeak-we-buffer-id-cache
                ',(copy-sequence values))))))
    (kill-buffer content)))

(defvar emacspeak-we-buffer-role-cache nil
  "Caches role attribute values for current buffer.")

(make-variable-buffer-local 'emacspeak-we-buffer-role-cache)

(defsubst emacspeak-we-build-role-cache ()
  "Build role cache and forward it to rendered page."
  (let ((values nil)
        (content (clone-buffer)))
    (save-excursion
      (set-buffer content)
      (setq buffer-undo-list t)
      (emacspeak-xslt-run
       (emacspeak-xslt-get "role-values.xsl")
       (point-min) (point-max))
      (setq values (split-string (buffer-string))))
    (add-hook
     'emacspeak-web-post-process-hook
     (eval
      `(function
        (lambda nil
          (declare (special  emacspeak-we-buffer-role-cache))
          (setq emacspeak-we-buffer-role-cache
                ',(copy-sequence values))))))
    (kill-buffer content)))

;;;###autoload
(defun emacspeak-we-extract-by-class (class    url &optional speak)
  "Extract elements having specified class attribute from HTML. Extracts
specified elements from current WWW page and displays it in a separate
buffer. Interactive use provides list of class values as completion."
  (interactive
   (list
    (completing-read "Class: "
                     emacspeak-we-buffer-class-cache)
    (emacspeak-webutils-read-url)
    current-prefix-arg))
  (let ((filter (format "//*[contains(@class,\"%s\")]" class)))
    (emacspeak-we-xslt-filter filter
                              url
                              (or (ems-interactive-p )
                                  speak))))
;;;###autoload
(defun emacspeak-we-junk-by-class (class    url &optional speak)
  "Extract elements not having specified class attribute from HTML. Extracts
specified elements from current WWW page and displays it in a separate
buffer. Interactive use provides list of class values as completion."
  (interactive
   (list
    (completing-read "Class: "
                     emacspeak-we-buffer-class-cache)
    (emacspeak-webutils-read-this-url)
    current-prefix-arg))
  (let ((filter (format "//*[contains(@class,\"%s\")]" class)))
    (emacspeak-we-xslt-junk filter
                            url
                            (or (ems-interactive-p )
                                speak))))

(defsubst  emacspeak-we-get-id-list ()
  "Collect a list of ids by prompting repeatedly in the
minibuffer.
Empty value finishes the list."
  (let ((ids emacspeak-we-buffer-id-cache)
        (result nil)
        (c nil)
        (done nil))
    (while (not done)
      (setq c
            (completing-read "Id: "
                             ids
                             nil 'must-match))
      (if (> (length c) 0)
          (push c result)
        (setq done t)))
    result))

(defsubst  emacspeak-we-css-get-class-list ()
  "Collect a list of classes by prompting repeatedly in the
minibuffer.
Empty value finishes the list."
  (let ((classes emacspeak-we-buffer-class-cache)
        (result nil)
        (c nil)
        (done nil))
    (while (not done)
      (setq c
            (completing-read "Class: "
                             classes
                             nil 'must-match))
      (if (> (length c) 0)
          (push c result)
        (setq done t)))
    result))

;;;###autoload
(defun emacspeak-we-extract-by-class-list(classes   url &optional
                                                    speak)
  "Extract elements having class specified in list `classes' from HTML.
Extracts specified elements from current WWW page and displays it
in a separate buffer.  Interactive use provides list of class
values as completion. "
  (interactive
   (list
    (let ((completion-ignore-case t))
      (emacspeak-we-css-get-class-list))
    (emacspeak-webutils-read-url)
    current-prefix-arg))
  (let ((filter
         (mapconcat
          #'(lambda  (c)
              (format "(@class=\"%s\")" c))
          classes
          " or ")))
    (emacspeak-we-xslt-filter
     (format "//*[%s]" filter)
     url
     (or (ems-interactive-p ) speak))))
;;;###autoload
(defun emacspeak-we-junk-by-class-list(classes   url &optional
                                                 speak)
  "Extract elements not having class specified in list `classes' from HTML.
Extracts specified elements from current WWW page and displays it
in a separate buffer.  Interactive use provides list of class
values as completion. "
  (interactive
   (list
    (let ((completion-ignore-case t))
      (emacspeak-we-css-get-class-list))
    (emacspeak-webutils-read-this-url)
    current-prefix-arg))
  (let ((filter
         (mapconcat
          #'(lambda  (c)
              (format "(@class=\"%s\")" c))
          classes
          " or ")))
    (emacspeak-we-xslt-junk
     (format "//*[%s]" filter)
     url
     (or (ems-interactive-p ) speak))))

;;;###autoload
(defun emacspeak-we-extract-by-id (id   url &optional speak)
  "Extract elements having specified id attribute from HTML. Extracts
specified elements from current WWW page and displays it in a separate
buffer.
Interactive use provides list of id values as completion."
  (interactive
   (list
    (let ((completion-ignore-case t))
      (completing-read "Id: "
                       emacspeak-we-buffer-id-cache))
    (emacspeak-webutils-read-url)
    current-prefix-arg))
  (emacspeak-we-xslt-filter
   (format "//*[@id=\"%s\"]"
           id)
   url
   speak))

;;;###autoload
(defun emacspeak-we-extract-by-id-list(ids   url &optional speak)
  "Extract elements having id specified in list `ids' from HTML.
Extracts specified elements from current WWW page and displays it in a
separate buffer. Interactive use provides list of id values as completion. "
  (interactive
   (list
    (emacspeak-we-get-id-list)
    (emacspeak-webutils-read-url)
    current-prefix-arg))
  (let ((filter
         (mapconcat
          #'(lambda  (c)
              (format "(@id=\"%s\")" c))
          ids
          " or ")))
    (emacspeak-we-xslt-filter
     (format "//*[%s]" filter)
     url
     (or (ems-interactive-p )
         speak))))

;;;###autoload
(defun emacspeak-we-extract-id-text (id   url &optional speak)
  "Extract text nodes from elements having specified id attribute from HTML. Extracts
specified elements from current WWW page and displays it in a separate
buffer.
Interactive use provides list of id values as completion."
  (interactive
   (list
    (let ((completion-ignore-case t))
      (completing-read "Id: "
                       emacspeak-we-buffer-id-cache))
    (emacspeak-webutils-read-url)
    current-prefix-arg))
  (emacspeak-we-xslt-filter
   (format "//*[@id=\"%s\"]//text()"
           id)
   url
   speak))

;;;###autoload
(defun emacspeak-we-extract-id-list-text(ids   url &optional speak)
  "Extract text nodes from elements having id specified in list `ids' from HTML.
Extracts specified elements from current WWW page and displays it in a
separate buffer. Interactive use provides list of id values as completion. "
  (interactive
   (list
    (emacspeak-we-get-id-list)
    (emacspeak-webutils-read-url)
    current-prefix-arg))
  (let ((filter
         (mapconcat
          #'(lambda  (c)
              (format "(@id=\"%s\")" c))
          ids
          " or ")))
    (emacspeak-we-xslt-filter
     (format "//*[%s]//text()" filter)
     url
     (or (ems-interactive-p )
         speak))))

;;;###autoload

(defvar emacspeak-we-url-rewrite-rule nil
  "URL rewrite rule to use in current buffer.")

(make-variable-buffer-local 'emacspeak-we-url-rewrite-rule)
(defvar emacspeak-we-class-filter nil
  "Buffer local class filter.")

(make-variable-buffer-local 'emacspeak-we-class-filter)

;;;###autoload
(defun emacspeak-we-class-filter-and-follow (class url)
  "Follow url and point, and filter the result by specified class.
Class can be set locally for a buffer, and overridden with an
interactive prefix arg. If there is a known rewrite url rule, that is
used as well."
  (interactive
   (list
    (or emacspeak-we-class-filter
        (setq emacspeak-we-class-filter
              (read-from-minibuffer "Class: ")))
    (emacspeak-webutils-read-this-url)))
  (declare (special emacspeak-we-class-filter
                    emacspeak-we-url-rewrite-rule))
  (let ((redirect nil))
    (when emacspeak-we-url-rewrite-rule
      (setq redirect
            (replace-regexp-in-string
             (first emacspeak-we-url-rewrite-rule)
             (second emacspeak-we-url-rewrite-rule)
             url)))
    (emacspeak-we-extract-by-class
     emacspeak-we-class-filter
     (or redirect url)
     'speak)
    (emacspeak-auditory-icon 'open-object)))

(defvar emacspeak-we-id-filter nil
  "Buffer local id filter.")

(make-variable-buffer-local 'emacspeak-we-id-filter)

;;;###autoload
(defun emacspeak-we-follow-and-filter-by-id (id)
  "Follow url and point, and filter the result by specified id.
Id can be set locally for a buffer, and overridden with an
interactive prefix arg. If there is a known rewrite url rule, that is
used as well."
  (interactive
   (list
    (or emacspeak-we-id-filter
        (setq emacspeak-we-id-filter
              (read-from-minibuffer "Id: ")))))
  (declare (special emacspeak-we-id-filter
                    emacspeak-we-url-rewrite-rule))
  (emacspeak-webutils-browser-check)
  (let ((url (funcall emacspeak-webutils-url-at-point))
        (redirect nil))
    (unless url
      (error "Not on a link."))
    (when emacspeak-we-url-rewrite-rule
      (setq redirect
            (replace-regexp-in-string
             (first emacspeak-we-url-rewrite-rule)
             (second emacspeak-we-url-rewrite-rule)
             url)))
    (emacspeak-we-extract-by-id
     emacspeak-we-id-filter
     (or redirect url)
     'speak)))

;;;###autoload
(defun emacspeak-we-style-filter (style   url &optional speak )
  "Extract elements matching specified style
from HTML.  Extracts specified elements from current WWW
page and displays it in a separate buffer.  Optional arg url
specifies the page to extract contents  from."
  (interactive
   (list
    (read-from-minibuffer "Style: ")
    (emacspeak-webutils-read-url)
    current-prefix-arg))
  (emacspeak-we-xslt-filter
   (format "//*[contains(@style,  \"%s\")]" style)
   url
   (or (ems-interactive-p ) speak)))

;;}}}
;;{{{ xpath  filter

(defvar emacspeak-we-xpath-filter-history 
  (list
   emacspeak-we-recent-xpath-filter
   "//p|//div"
   "//p|//ol|//ul|//dl|//h1|//h2|//h3|//h4|//h5|//h6|//blockquote")
  "History list recording XPath filters we've used.")

(put 'emacspeak-we-xpath-filter-history 'history-length 10)

(defvar emacspeak-we-xpath-filter nil
  "Buffer local variable specifying a XPath filter for following
urls.")

(make-variable-buffer-local 'emacspeak-we-xpath-filter)
;;;###autoload
(defcustom emacspeak-we-recent-xpath-filter
  "//p|//ol|//ul|//dl|//h1|//h2|//h3|//h4|//h5|//h6|//blockquote|//div"
  "Caches most recently used xpath filter.
Can be customized to set up initial default."
  :type 'string
  :group 'emacspeak-we)
;;;###autoload
(defcustom emacspeak-we-paragraphs-xpath-filter
  "//p"
  "Filter paragraphs."
  :type 'string
  :group 'emacspeak-we)

;;;###autoload
(defun emacspeak-we-xpath-filter-and-follow (&optional prompt)
  "Follow url and point, and filter the result by specified xpath.
XPath can be set locally for a buffer, and overridden with an
interactive prefix arg. If there is a known rewrite url rule, that is
used as well."
  (interactive "P")
  (declare (special emacspeak-we-xpath-filter
                    emacspeak-we-recent-xpath-filter emacspeak-we-xpath-filter-history
                    emacspeak-we-url-rewrite-rule))
  (emacspeak-webutils-browser-check)
  (let ((url (funcall emacspeak-webutils-url-at-point))
        (redirect nil))
    (unless url (error "Not on a link."))
    (when emacspeak-we-url-rewrite-rule
      (setq redirect
            (replace-regexp-in-string
             (first emacspeak-we-url-rewrite-rule)
             (second emacspeak-we-url-rewrite-rule)
             url)))
    (when (or prompt (null emacspeak-we-xpath-filter))
      (setq emacspeak-we-xpath-filter
            (read-from-minibuffer
             "Specify XPath: "
             nil nil nil
             'emacspeak-we-xpath-filter-history
             emacspeak-we-recent-xpath-filter))
      (pushnew emacspeak-we-xpath-filter emacspeak-we-xpath-filter-history)
      (setq emacspeak-we-recent-xpath-filter
            emacspeak-we-xpath-filter))
    (emacspeak-we-xslt-filter emacspeak-we-xpath-filter
                              (or redirect url)
                              'speak)))

(defvar emacspeak-we-class-filter-history 
  nil
  "History list recording Class filters we've used.")

(put 'emacspeak-we-class-filter-history 'history-length 10)

(defvar emacspeak-we-class-filter nil
  "Buffer local variable specifying a Class filter for following
urls.")

(make-variable-buffer-local 'emacspeak-we-class-filter)
(defcustom emacspeak-we-recent-class-filter
  nil
  "Caches most recently used class filter.
Can be customized to set up initial default."
  :type 'string
  :group 'emacspeak-we)
;;;###autoload
(defun emacspeak-we-class-filter-and-follow-link (&optional prompt)
  "Follow url and point, and filter the result by specified class.
Class can be set locally for a buffer, and overridden with an
interactive prefix arg. If there is a known rewrite url rule, that is
used as well."
  (interactive "P")
  (declare (special emacspeak-we-class-filter
                    emacspeak-we-recent-class-filter emacspeak-we-class-filter-history
                    emacspeak-we-url-rewrite-rule))
  (emacspeak-webutils-browser-check)
  (let ((url (funcall emacspeak-webutils-url-at-point))
        (redirect nil))
    (unless url (error "Not on a link."))
    (when emacspeak-we-url-rewrite-rule
      (setq redirect
            (replace-regexp-in-string
             (first emacspeak-we-url-rewrite-rule)
             (second emacspeak-we-url-rewrite-rule)
             url)))
    (when (or prompt (null emacspeak-we-class-filter))
      (setq emacspeak-we-class-filter
            (read-from-minibuffer
             "Specify Class: "
             nil nil nil
             'emacspeak-we-class-filter-history
             emacspeak-we-recent-class-filter))
      (pushnew emacspeak-we-class-filter emacspeak-we-class-filter-history)
      (setq emacspeak-we-recent-class-filter
            emacspeak-we-class-filter))
    (emacspeak-we-xslt-filter
     (format "//*[@class=\"%s\"]"emacspeak-we-class-filter)
     (or redirect url)
     'speak)))

(defvar emacspeak-we-xpath-junk nil
  "Records XPath pattern used to junk elements.")

(make-variable-buffer-local 'emacspeak-we-xpath-junk)

(defvar emacspeak-we-recent-xpath-junk
  nil
  "Caches last XPath used to junk elements.")
;;;###autoload
(defun emacspeak-we-xpath-junk-and-follow (&optional prompt)
  "Follow url and point, and filter the result by junking
elements specified by xpath.
XPath can be set locally for a buffer, and overridden with an
interactive prefix arg. If there is a known rewrite url rule, that is
used as well."
  (interactive "P")
  (declare (special emacspeak-we-xpath-junk
                    emacspeak-we-xsl-junk
                    emacspeak-we-recent-xpath-junk
                    emacspeak-we-url-rewrite-rule))
  (emacspeak-webutils-browser-check)
  (let ((url (funcall emacspeak-webutils-url-at-point))
        (redirect nil))
    (unless url
      (error "Not on a link."))
    (when emacspeak-we-url-rewrite-rule
      (setq redirect
            (replace-regexp-in-string
             (first emacspeak-we-url-rewrite-rule)
             (second emacspeak-we-url-rewrite-rule)
             url)))
    (when (or prompt
              (null emacspeak-we-xpath-junk))
      (setq emacspeak-we-xpath-junk
            (read-from-minibuffer  "Specify XPath: "
                                   emacspeak-we-recent-xpath-junk))
      (setq emacspeak-we-recent-xpath-junk
            emacspeak-we-xpath-junk))
    (emacspeak-we-xslt-junk
     emacspeak-we-xpath-junk
     (or redirect url)
     'speak)))

;;}}}
;;{{{ Property filter

;;;###autoload
(defun emacspeak-we-extract-by-property (url &optional speak)
  "Interactively prompt for an HTML property, e.g. id or class,
and provide a completion list of applicable  property values. Filter document by property that is specified."
  (interactive
   (list
    (emacspeak-webutils-read-url)
    current-prefix-arg))
  (let* ((completion-ignore-case t)
         (choices
          (mapcar 'symbol-name (intersection
                                '(id class style role)
                                (emacspeak-webutils-property-names-from-html-stack (emacspeak-w3-html-stack)))))
         (property
          (read
           (completing-read "Property: "
                            choices)))
         (values (emacspeak-webutils-get-property-from-html-stack
                  (emacspeak-w3-html-stack)
                  property))
         (v (completing-read "Having value: " values))
         (filter
          (if (eq property 'class)
              (format "//*[contains(@%s, \"%s\")]"
                      property v)
            (format "//*[@%s=\"%s\"]"
                    property v))))
    (emacspeak-we-xslt-filter filter url
                              (or (ems-interactive-p ) speak))))

;;}}}
;;{{{  xsl keymap

(declaim (special emacspeak-we-xsl-map))

(loop for binding in
      '(
        ("C" emacspeak-we-extract-by-class-list)
        ("D" emacspeak-we-junk-by-class-list)
        ("w" emacspeak-we-extract-by-property)
        ("M" emacspeak-we-extract-tables-by-match-list)
        ("P" emacspeak-we-extract-print-streams)
        ("R" emacspeak-we-extract-media-streams-under-point)
        ("T" emacspeak-we-extract-tables-by-position-list)
        ("X" emacspeak-we-extract-nested-table-list)
        ("\C-c" emacspeak-we-junk-by-class-list)
        ("\C-f" emacspeak-we-count-matches)
        ("\C-p" emacspeak-we-xpath-junk-and-follow)
        ("\C-t" emacspeak-we-count-tables)
        ("\C-x" emacspeak-we-count-nested-tables)
        ("a" emacspeak-we-xslt-apply)
        ("c" emacspeak-we-extract-by-class)
        ("d" emacspeak-we-junk-by-class)
        ("e" emacspeak-we-url-expand-and-execute)
        ("f" emacspeak-we-xslt-filter)
        ("i" emacspeak-we-extract-by-id)
        ("I" emacspeak-we-extract-by-id-list)
        ("j" emacspeak-we-xslt-junk)
        ("k" emacspeak-we-toggle-xsl-keep-result)
        ("m" emacspeak-we-extract-table-by-match)
        ("o" emacspeak-we-xsl-toggle)
        ("p" emacspeak-we-xpath-filter-and-follow)
        ("v" emacspeak-we-class-filter-and-follow-link)
        ("r" emacspeak-we-extract-media-streams)
        ("S" emacspeak-we-style-filter)
        ("s" emacspeak-we-xslt-select)
        ("t" emacspeak-we-extract-table-by-position)
        ("u" emacspeak-we-extract-matching-urls)
        ("x" emacspeak-we-extract-nested-table)
        ("b" emacspeak-we-follow-and-filter-by-id)
        ("y" emacspeak-we-class-filter-and-follow)
        )
      do
      (emacspeak-keymap-update emacspeak-we-xsl-map binding))

;;}}}
(provide 'emacspeak-we)
;;{{{ end of file

;;; local variables:
;;; folded-file: t
;;; byte-compile-dynamic: nil
;;; end:

;;}}}
