;;; emacspeak-mspools.el --- Speech enable MSpools -- Monitor multiple mail drops
;;; $Id: emacspeak-mspools.el 8146 2013-02-09 20:05:08Z tv.raman.tv $
;;; $Author: tv.raman.tv $ 
;;; Description: Auditory interface to mail spool tracker
;;; Keywords: Emacspeak, Speak, Spoken Output, mspools
;;{{{  LCD Archive entry: 

;;; LCD Archive Entry:
;;; emacspeak| T. V. Raman |raman@cs.cornell.edu 
;;; A speech interface to Emacs |
;;; $Date: 2008-06-21 10:50:41 -0700 (Sat, 21 Jun 2008) $ |
;;;  $Revision: 4532 $ | 
;;; Location undetermined
;;;

;;}}}
;;{{{  Copyright:

;;; Copyright (c) 1995 -- 2011, T. V. Raman
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

;;{{{  Required modules

(require 'emacspeak-preamble)
;;}}}
;;{{{  Introduction

;;; Speech mspools --a package that lets you monitor
;;; multiple maildrops

;;}}}
;;{{{ advice

(defadvice mspools-show (after emacspeak pre act comp)
  "Provide auditory feedback"
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'open-object)
    (emacspeak-speak-mode-line)))
(defadvice mspools-quit (after emacspeak pre act comp)
  "Provide auditory feedback"
  (when (ems-interactive-p )
    (emacspeak-auditory-icon 'close-object)
    (emacspeak-speak-mode-line)))

(defadvice mspools-revert-buffer (after emacspeak pre act comp)
  "Provide auditory feedback"
  (emacspeak-auditory-icon 'select-object)
  (emacspeak-speak-line))
;;}}}
;;{{{ keymaps
(declaim (special mspools-mode-map))
(eval-when (load)
  (require 'emacspeak-keymap)
  )

;;}}}
(provide 'emacspeak-mspools)

;;{{{ end of file 

;;; local variables:
;;; folded-file: t
;;; byte-compile-dynamic: nil
;;; end: 

;;}}}
