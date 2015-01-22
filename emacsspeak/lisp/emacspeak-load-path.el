;;; emacspeak-load-path.el -- Setup Emacs load-path for compiling Emacspeak
;;; $Id: emacspeak-load-path.el 8055 2012-12-21 19:37:09Z tv.raman.tv $
;;; $Author: tv.raman.tv $ 
;;; Description:  Sets up load-path for emacspeak compilation and installation
;;; Keywords: Emacspeak, Speech extension for Emacs
;;{{{  LCD Archive entry: 
;;; LCD Archive Entry:
;;; emacspeak| T. V. Raman |raman@cs.cornell.edu 
;;; A speech interface to Emacs |
;;; $Date: 2007-08-25 18:28:19 -0700 (Sat, 25 Aug 2007) $ |
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
(defvar emacspeak-directory
  (expand-file-name "../" (file-name-directory load-file-name))
  "Directory where emacspeak is installed. ")

(defvar emacspeak-lisp-directory
  (expand-file-name "lisp/" emacspeak-directory)
  "Directory containing lisp files for  Emacspeak.")  

(unless (member emacspeak-lisp-directory load-path )
  (setq load-path
        (cons emacspeak-lisp-directory load-path )))

(defvar emacspeak-resource-directory (expand-file-name "~/.emacspeak")
  "Directory where Emacspeak resource files such as pronunciation dictionaries are stored. ")

(setq byte-compile-warnings t)
                                        ;'(redefine callargs free-vars unresolved obsolete))

(cond
 ((string-match "24" emacs-version)
  (defsubst ems-interactive-p  ()
    "called-interactively-p 'interactive"
    (called-interactively-p 'interactive)))
 (t (defalias 'ems-interactive-p  'interactive-p )))

(provide 'emacspeak-load-path)
