;;; emacspeak-google.el --- Google Search Tools
;;; $Id: emacspeak-google.el 4797 2007-07-16 23:31:22Z tv.raman.tv $
;;; $Author: tv.raman.tv $
;;; Description:  Speech-enable GOOGLE An Emacs Interface to google
;;; Keywords: Emacspeak,  Audio Desktop google
;;{{{  LCD Archive entry:

;;; LCD Archive Entry:
;;; emacspeak| T. V. Raman |raman@cs.cornell.edu
;;; A speech interface to Emacs |
;;; $Date: 2007-05-03 18:13:44 -0700 (Thu, 03 May 2007) $ |
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
;;; MERCHANTABILITY or FITNGOOGLE FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Emacs; see the file COPYING.  If not, write to
;;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

;;}}}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;{{{  introduction

;;; Commentary:
;;; There are a number of search tools that can be implemented on
;;; the Google search page --- in a JS-powered browser, these
;;; show up as the Google tool-belt.
;;; This module implements a minor mode for use in Google result
;;; pages that enables these tools via single keyboard commands.
;;; Originally all options were available as tbs=p:v
;;; Now, some specialized searches, e.g. blog search are tbm=
;;; Code:

;;}}}
;;{{{  Required modules

(require 'cl)
(declaim  (optimize  (safety 0) (speed 3)))
(require 'emacspeak-preamble)
(require 'gweb)
(require 'gmaps)
(require 'derived)
(require 'html2text)
;;}}}
;;{{{ Data Structures 

;;; One tool on a tool-belt

(defstruct emacspeak-google-tool
  name ; human readable
  param ; url param bit
  range ; range of possible values
  default
  value ; current setting
  type ;tbs/tbm
  )

(defvar emacspeak-google-query nil
  "Current Google Query.
This variable is buffer-local.")
(make-variable-buffer-local 'emacspeak-google-query)

(defvar emacspeak-google-toolbelt nil
  "List of tools on the toolbelt.")

(make-variable-buffer-local 'emacspeak-google-toolbelt)

(defun emacspeak-google-toolbelt-to-tbm (belt)
  "Return value for use in tbm parameter in search queries."
  (let
      ((settings
        (delq nil
              (mapcar 
               #'(lambda (tool)
                   (when (eq 'tbm (emacspeak-google-tool-type tool))
                     (cond
                      ((equal (emacspeak-google-tool-value tool)
                              (emacspeak-google-tool-default tool))
                       nil)
                      (t (format "%s"
                                 (emacspeak-google-tool-param tool))))))
               belt))))
    (when settings 
      (concat "&tbm="
              (mapconcat #'identity settings ",")))))

(defun emacspeak-google-toolbelt-to-tbs (belt)
  "Return value for use in tbs parameter in search queries."
  (let
      ((settings
        (delq nil
              (mapcar 
               #'(lambda (tool)
                   (when (eq 'tbs (emacspeak-google-tool-type tool))
                     (cond
                      ((equal (emacspeak-google-tool-value tool)
                              (emacspeak-google-tool-default tool))
                       nil)
                      (t (format "%s:%s"
                                 (emacspeak-google-tool-param tool)
                                 (emacspeak-google-tool-value tool))))))
               belt))))
    (when settings 
      (concat "&tbs="
              (mapconcat #'identity settings ",")))))

(defun emacspeak-google-toolbelt ()
  "Returns buffer-local toolbelt or a a newly initialized toolbelt."
  (declare (special emacspeak-google-toolbelt))
  (or emacspeak-google-toolbelt
      (list
;;; video vid: 1/0
       (make-emacspeak-google-tool
        :name "video"
        :param "vid"
        :range '(0 1)
        :default 0
        :type 'tbm
        :value 0)
;;; Recent
       (make-emacspeak-google-tool
        :name "recent"
        :param "rcnt"
        :range '( 0 1)
        :default 0
        :value 0
        :type 'tbs)
;;; Duration restrict for video
       (make-emacspeak-google-tool
        :name "duration"
        :param "dur"
        :range '("m" "s" "l")
        :default "m"
        :value "m"
        :type 'tbs)
;;; Blog mode
       (make-emacspeak-google-tool
        :name "blog"
        :param "blg"
        :range '(0 1)
        :default 0
        :value 0
        :type 'tbm)
;;; Books mode
       (make-emacspeak-google-tool
        :name "books"
        :param "bks"
        :range '(0 1)
        :default 0
        :type 'tbm
        :value 0)
;;; epub 
       (make-emacspeak-google-tool
        :name "books-format"
        :param "bft"
        :range '("p" "e")
        :default "e"
        :type 'tbs
        :value "e")
;;; Books viewability
       (make-emacspeak-google-tool
        :name "books-viewability"
        :param "bkv"
        :range '("a" "f")
        :default "a"
        :value "a"
        :type 'tbs)
;;; Book Type
       (make-emacspeak-google-tool
        :name "books-type"
        :param "bkt"
        :range '("b" "p" "m")
        :default "b"
        :value "b"
        :type 'tbs)
;;; Forums Mode
       (make-emacspeak-google-tool
        :name "forums"
        :param "frm"
        :range '(0 1)
        :default 0
        :value 0
        :type 'tbs)
;;; News Mode
       (make-emacspeak-google-tool
        :name "news"
        :param "nws"
        :range '(0 1)
        :default 0
        :value 0
        :type 'tbm)
;;; Reviews
       (make-emacspeak-google-tool
        :name "reviews"
        :param "rvw"
        :range '(0 1)
        :default 0
        :value 0
        :type 'tbs)
;;; Web History Visited
       (make-emacspeak-google-tool
        :name "web-history-visited"
        :param "whv"
        :range '(0 1)
        :default 0
        :type 'tbs
        :value 0)
;;; Web History Not Visited
       (make-emacspeak-google-tool
        :name "web-history-not-visited"
        :param "whnv"
        :type 'tbs
        :range '(0 1)
        :default 0
        :value 0)
;;; Images
       (make-emacspeak-google-tool
        :name "images"
        :param "isch"
        :range '(0 1)
        :default 0
        :value 0
        :type 'tbm)
;;; Structured Snippets
       (make-emacspeak-google-tool
        :name "structured-snippets"
        :param "sts"
        :range '(0 1)
        :default 0
        :value 0
        :type 'tbs)
;;; sort by date
       (make-emacspeak-google-tool
        :name "sort-by-date"
        :param "std"
        :range '(0 1)
        :default 0
        :value 0
        :type 'tbs)
;;; Timeline
       (make-emacspeak-google-tool
        :name "timeline"
        :param "tl"
        :range '(0 1)
        :default 0
        :type 'tbs
        :value 0)
;;; Timeline Low
       (make-emacspeak-google-tool
        :name "timeline-low"
        :param "tll"
        :type 'tbs
        :range "YYYY/MM"
        :default ""
        :value "")
;;; Date Filter
       (make-emacspeak-google-tool
        :name "date-filter"
        :param "qdr"
        :range "tn"
        :default ""
        :type 'tbs
        :value "")
;;; Timeline High
       (make-emacspeak-google-tool
        :name "timeline-high"
        :param "tlh"
        :range "YYYY/MM"
        :default ""
        :type 'tbs
        :value "")
;;; more:commercial promotion with prices
       (make-emacspeak-google-tool
        :name "commercial"
        :param "cpk"
        :range '(0 1)
        :default 0
        :type 'tbs
        :value 0)
;;; verbatim/literal search
       (make-emacspeak-google-tool
        :name "literal"
        :param "li"
        :range '(0 1)
        :default 0
        :type 'tbs
        :value 0)
       ;;; shopping
       (make-emacspeak-google-tool
        :name "Shopping"
        :param "shop"
        :range '(0 1)
        :default 0
        :type 'tbm
        :value 0)
       (make-emacspeak-google-tool
        :name "commercial-prices"
        :param "cp"
        :range '(0 1)
        :default 0
        :type 'tbs
        :value 0)
;;; less:commercial (demotion)
       (make-emacspeak-google-tool
        :name "non-commercial" 
        :param "cdcpk"
        :range '(0 1)
        :default 0
        :type 'tbs
        :value 0)
       ;;; soc
       (make-emacspeak-google-tool
        :name "social" 
        :param "sa"
        :range '(0 1)
        :default 0
        :type 'tbs
        :value 0))))

;;}}}
;;{{{ Interactive Commands

(loop for this-tool in
      (emacspeak-google-toolbelt)
      do
      (eval
       `(defun
            ,(intern
              (format
               "emacspeak-google-toolbelt-change-%s"
               (emacspeak-google-tool-name this-tool)))
            ()
          ,(format
            "Change  %s in the currently active toolbelt."
            (emacspeak-google-tool-name this-tool))
          (interactive)
          (let*
              ((belt (emacspeak-google-toolbelt))
               (tool
                (find-if #'(lambda (tool) (string-equal (emacspeak-google-tool-name tool)
                                                        ,(emacspeak-google-tool-name this-tool)))
                         belt))
               (param (emacspeak-google-tool-param tool))
               (value (emacspeak-google-tool-value tool))
               (range (emacspeak-google-tool-range tool)))
            (cond
             ((and (listp range)
                   (= 2 (length range)))
;;; toggle value
              (setf (emacspeak-google-tool-value tool)
                    (if (equal value (first range))
                        (second range)
                      (first range))))
             ((listp range)
;;; Prompt using completion
              (setf  (emacspeak-google-tool-value tool)
                     (completing-read
                      "Set tool to: "
                      range)))
             ((stringp range)
              (setf (emacspeak-google-tool-value tool)
                    (read-from-minibuffer  range)))
             (t (error "Unexpected type!")))
            (let
                ((emacspeak-websearch-google-options
                  (concat
                   (emacspeak-google-toolbelt-to-tbs belt)
                   (emacspeak-google-toolbelt-to-tbm belt))))
              (emacspeak-websearch-google
               (or emacspeak-google-query
                   (gweb-google-autocomplete))))))))

(defun emacspeak-google-show-toolbelt()
  "Reload search page with toolbelt showing."
  (interactive)
  (declare (special emacspeak-google-query))
  (let ((emacspeak-websearch-google-options "&tbo=1"))
    (emacspeak-websearch-google emacspeak-google-query)))

;;}}}
;;{{{  keymap
;;;###autoload
(define-prefix-command  'emacspeak-google-command
  'emacspeak-google-keymap)

(loop for k in
      '(
        ("h"
         emacspeak-google-toolbelt-change-web-history-visited)
        ("H" emacspeak-google-toolbelt-change-web-history-not-visited)
        ("r" emacspeak-google-toolbelt-change-recent)
        ("b" emacspeak-google-toolbelt-change-blog)
        ("n" emacspeak-google-toolbelt-change-news)
        ("c" emacspeak-google-toolbelt-change-commercial)
        ("d" emacspeak-google-toolbelt-change-sort-by-date)
        ("p" emacspeak-google-toolbelt-change-commercial-prices)
        ("f" emacspeak-google-toolbelt-change-forums)
        ("v" emacspeak-google-toolbelt-change-video)
        ("i" emacspeak-google-toolbelt-change-images)
        ("B" emacspeak-google-toolbelt-change-books)
        ("t" emacspeak-google-toolbelt-change-books-type)
        ("L" emacspeak-google-toolbelt-change-literal)
        ("\C-t" emacspeak-google-show-toolbelt)
        ("T" emacspeak-google-toolbelt-change-timeline)
        ("\C-b" emacspeak-google-toolbelt-change-books-format)
        ("l" emacspeak-google-toolbelt-change-non-commercial)
        ("S" emacspeak-google-toolbelt-change-shopping)
        ("s" emacspeak-google-toolbelt-change-structured-snippets)
        ("S" emacspeak-google-toolbelt-change-social)
        ("a" emacspeak-websearch-google)
        ("A" emacspeak-websearch-accessible-google)
        )
      do
      (emacspeak-keymap-update emacspeak-google-keymap k))

;;}}}
;;{{{ Advice GMaps:

(defadvice gmaps (after emacspeak pre act comp)
  "Provide  auditory feedback."
  (when (ems-interactive-p)
    (emacspeak-auditory-icon 'open-object)
    (emacspeak-speak-mode-line)))
(loop for f in
      '(gmaps-driving-directions gmaps-bicycling-directions
                                 gmaps-walking-directions gmaps-transit-directions
                                 gmaps-places-nearby gmaps-places-search)
      do
      (eval
       `(defadvice ,f (after emacspeak pre act comp)
          "Provide auditory feedback."
          (when (ems-interactive-p)
            (emacspeak-auditory-icon 'task-done)
            (emacspeak-speak-rest-of-buffer)))))

(defadvice gmaps-set-current-location (after emacspeak pre act comp)
  "Provide auditory feedback."
  (when (ems-interactive-p)
    (emacspeak-speak-header-line)))

(defadvice gmaps-set-current-radius (after emacspeak pre act comp)
  "Provide auditory feedback."
  (when (ems-interactive-p)
    (message "Radius set to %s. " gmaps-current-radius)))

(defadvice gmaps-place-details (around emacspeak pre act comp)
  "Provide auditory feedback."
  (cond
   ((ems-interactive-p)
    ad-do-it
    (emacspeak-speak-region  (point)
                             (or 
                              (next-single-property-change (point) 'place-details )
                              (point-max))))
   (t ad-do-it))
  ad-return-value)

;;}}}
(provide 'emacspeak-google)
;;{{{ end of file

;;; local variables:
;;; folded-file: t
;;; byte-compile-dynamic: nil
;;; end:

;;}}}
