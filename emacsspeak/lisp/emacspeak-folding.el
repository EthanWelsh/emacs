;;; emacspeak-folding.el --- Speech enable Folding Mode -- enables structured editing
;;; $Id: emacspeak-folding.el 8260 2013-03-28 15:21:49Z tv.raman.tv $
;;; $Author: tv.raman.tv $ 
;;; DescriptionEmacspeak extensions for folding-mode
;;; Keywords:emacspeak, audio interface to emacs Folding editor
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
;;{{{ requires
(require 'emacspeak-preamble)

;;}}}
;;{{{  Introduction:

;;; Folding mode turns emacs into a folding editor.
;;; Folding mode is what I use: 
;;; emacs 19 comes with similar packages, e.g. allout.el
;;; This module defines some advice forms that make folding mode a pleasure to use.
;;; Think of a fold as a container. 
;;; 

;;}}}
;;{{{ Advice

(defadvice fold-goto-line (after emacspeak pre act)
  "Speak the line. "
  (when (ems-interactive-p )
    (emacspeak-speak-line )))

(defadvice folding-mode (after emacspeak pre act )
  "Provide spoken feedback"
  (when (ems-interactive-p )
    (message "turned %s folding mode"
             (if folding-mode " on " " off" ))))

(defadvice fold-enter (after emacspeak pre act)
  "Produce an auditory icon and then speak the line. "
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'open-object)
    (emacspeak-speak-line)))

(defadvice fold-exit (after emacspeak pre act)
  "Produce an auditory icon. 
Then speak the folded line."
  (when (ems-interactive-p ) 
    (emacspeak-auditory-icon'close-object)
    (emacspeak-speak-line)))

(defadvice fold-fold-region (after emacspeak pre act)
  "Produce an auditory icon. "
  (when (ems-interactive-p  )
    (emacspeak-auditory-icon 'open-object)
    (message "Specify a meaningful name for the new fold ")))

(defadvice fold-hide (after emacspeak pre act )
  "Provide auditory feedback"
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'close-object)
    (message "Hid current fold")))

;;}}}
(provide  'emacspeak-folding)
;;{{{  emacs local variables 

;;; local variables:
;;; folded-file: t
;;; byte-compile-dynamic: nil
;;; end: 

;;}}}
